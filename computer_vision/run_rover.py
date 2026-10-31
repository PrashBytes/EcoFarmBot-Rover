import cv2
import numpy as np
import tensorflow as tf
import time

# 1. Load Your Trained Kaggle Model
print("Loading Machine Learning Model...")
try:
    model = tf.keras.models.load_model('plant_model.h5')
    print("Model loaded successfully!")
except Exception as e:
    print(f"Error loading model: {e}")
    model = None

# 2. Define the exact 38 classes your model was trained on
class_labels = [
    'Apple___Apple_scab', 'Apple___Black_rot', 'Apple___Cedar_apple_rust', 'Apple___healthy',
    'Blueberry___healthy', 'Cherry___Powdery_mildew', 'Cherry___healthy',
    'Corn___Cercospora_leaf_spot Gray_leaf_spot', 'Corn___Common_rust', 'Corn___Northern_Leaf_Blight', 'Corn___healthy',
    'Grape___Black_rot', 'Grape___Esca_(Black_Measles)', 'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)', 'Grape___healthy',
    'Orange___Haunglongbing_(Citrus_greening)', 'Peach___Bacterial_spot', 'Peach___healthy',
    'Pepper,_bell___Bacterial_spot', 'Pepper,_bell___healthy', 'Potato___Early_blight', 'Potato___Late_blight', 'Potato___healthy',
    'Raspberry___healthy', 'Soybean___healthy', 'Squash___Powdery_mildew', 'Strawberry___Leaf_scorch', 'Strawberry___healthy',
    'Tomato___Bacterial_spot', 'Tomato___Early_blight', 'Tomato___Late_blight', 'Tomato___Leaf_Mold',
    'Tomato___Septoria_leaf_spot', 'Tomato___Spider_mites Two-spotted_spider_mite', 'Tomato___Target_Spot',
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus', 'Tomato___Tomato_mosaic_virus', 'Tomato___healthy'
]

# 3. Fast OpenCV Plant Detector (Looks for Green, Yellow, and Brown)
def is_plant_present(frame, threshold=0.02):
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    # Expand bounds: Hue 10-25 covers brown/yellow, 25-90 covers green
    lower_color = np.array([10, 40, 40])
    upper_color = np.array([90, 255, 255])
    
    mask = cv2.inRange(hsv, lower_color, upper_color)
    color_ratio = cv2.countNonZero(mask) / (frame.shape[0] * frame.shape[1])
    return color_ratio > threshold

# 4. Connect to the ESP32-CAM Stream
camera_url = 'http://192.168.4.2:81/stream'
print(f"Connecting to ESP32-CAM at {camera_url}...")
cap = cv2.VideoCapture(camera_url)

if not cap.isOpened():
    print("Error: Could not open the camera stream. Check connection.")
    exit()

print("Stream connected! Press 'q' in the video window to stop.")

mission_start_time = time.time() # Starts the time-based location tracker
last_prediction_time = time.time()

while True:
    ret, frame = cap.read()
    
    # Ignore corrupted Wi-Fi frames instead of crashing
    if not ret:
        time.sleep(0.1)
        continue

    # Show the live video feed
    cv2.imshow('EcoFarmBot Live Camera', frame)

    # Run prediction every 2 seconds
    if time.time() - last_prediction_time > 2.0:
        last_prediction_time = time.time()

        if is_plant_present(frame):
            if model is not None:
                # DIGITAL ZOOM: Crop the center 60% of the frame to mimic Kaggle close-ups
                height, width, _ = frame.shape
                crop_size = int(min(height, width) * 0.6) 
                start_y = (height - crop_size) // 2
                start_x = (width - crop_size) // 2
                zoomed_frame = frame[start_y:start_y+crop_size, start_x:start_x+crop_size]

                # Convert cropped area from OpenCV BGR to TensorFlow RGB
                rgb_frame = cv2.cvtColor(zoomed_frame, cv2.COLOR_BGR2RGB)
                
                # Resize and format without double-dividing by 255
                img = cv2.resize(rgb_frame, (224, 224))
                img = img.astype("float32")
                img = np.expand_dims(img, axis=0)

                # Get Prediction
                predictions = model.predict(img, verbose=0)
                class_index = np.argmax(predictions[0])
                confidence = predictions[0][class_index] * 100
                
                if class_index < len(class_labels):
                    original_label = class_labels[class_index]
                    
                    # Translate the 38 Kaggle classes
                    if "healthy" in original_label.lower():
                        result_text = "Healthy"
                    elif "target_spot" in original_label.lower():
                        # Hijack 'Target Spot' to act as our weed for the demo
                        result_text = "Weed Detected"
                    elif "blight" in original_label.lower() or "rust" in original_label.lower() or "scorch" in original_label.lower():
                        result_text = "Needs Water"
                    else:
                        result_text = "Needs Fertilizer"
                else:
                    result_text = "Unknown Category"

                if confidence > 80.0:
                    if result_text == "Weed Detected":
                        # Calculate how many seconds have passed since the rover started
                        elapsed_seconds = int(time.time() - mission_start_time)
                        print(f"⚠️ {result_text} | Location: {elapsed_seconds} seconds forward from Start Point.")
                    else:
                        print(f"Plant Status: {result_text} | Confidence: {confidence:.1f}%")
                else:
                    print("Analyzing plant...")
        else:
            print("No plant detected in view.")

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()