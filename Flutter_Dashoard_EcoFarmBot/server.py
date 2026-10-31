from flask import Flask, Response
import cv2

app = Flask(__name__)

# Initialize the camera (0 is usually your laptop's default webcam or connected USB cam)
# If you are pulling a stream directly from the ESP32-CAM, replace 0 with its IP address string (e.g., 'http://192.168.4.X:81/stream')
camera = cv2.VideoCapture(0)

def generate_frames():
    while True:
        success, frame = camera.read()
        if not success:
            break
        else:
            # Encode the frame in JPEG format
            ret, buffer = cv2.imencode('.jpg', frame)
            frame = buffer.tobytes()
            # Yield the frame in byte format for the web stream
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')

@app.route('/video_feed')
def video_feed():
    # Return the multipart response containing the video stream
    return Response(generate_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

if __name__ == '__main__':
    # host='0.0.0.0' allows devices on the same Wi-Fi (like your phone) to access the stream
    app.run(host='0.0.0.0', port=5000, debug=True)