#include <WiFi.h>
#include <WebServer.h>
#include <ESP32Servo.h>
#include <ArduinoJson.h>
#include <DHT.h>

// Wi-Fi Credentials
const char* ssid = "EcoFarmBot";
const char* password = "password123";

WebServer server(80);

// Motor Pins
const int ENA = 2, IN1 = 18, IN2 = 19, IN3 = 21, IN4 = 22, ENB = 15;
// 5-Channel IR Pins
const int S1 = 23, S2 = 35, S3 = 32, S4 = 33, S5 = 26;
// Ultrasonic Pins
const int TRIG_PIN = 25, ECHO_PIN = 27;
// Environment Pins
const int SOIL_PIN = 34;
const int DHT_PIN = 4;
// Servo Pins
const int SOIL_SERVO_PIN = 14;
const int CAM_SERVO_PIN = 12;

DHT dht(DHT_PIN, DHT22);
Servo soilServo;
Servo camServo;

// Camera Sweep Variables
bool sweepCam = false;
int camAngle = 90;
int camStep = 1;
unsigned long lastCamMove = 0;

// Obstacle Avoidance Variables
long currentDistance = 999;
unsigned long lastSonarRead = 0;

void setup() {
  Serial.begin(115200);
  
  // Motor Setup
  pinMode(ENA, OUTPUT); pinMode(ENB, OUTPUT);
  pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT); pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT);
  digitalWrite(ENA, HIGH); digitalWrite(ENB, HIGH);
  
  // Sensor Setup
  pinMode(S1, INPUT); pinMode(S2, INPUT); pinMode(S3, INPUT); pinMode(S4, INPUT); pinMode(S5, INPUT);
  pinMode(TRIG_PIN, OUTPUT); pinMode(ECHO_PIN, INPUT);
  dht.begin();

  // 1. Network Setup First
  WiFi.softAP(ssid, password);
  delay(1000); 
  
  // Servo Timer Setup
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  soilServo.setPeriodHertz(50);
  camServo.setPeriodHertz(50);

  // 2. Boot Soil Servo and Wait
  soilServo.attach(SOIL_SERVO_PIN, 500, 2400);
  soilServo.write(0); 
  delay(1000); 

  // 3. Boot Camera Servo and Wait
  camServo.attach(CAM_SERVO_PIN, 500, 2400);
  camServo.write(90); 
  delay(1000); 

  // 4. Unified Sensor Data Route
  server.on("/data", []() {
    StaticJsonDocument<256> doc;
    doc["temp"] = dht.readTemperature();
    doc["humidity"] = dht.readHumidity();
    
    // Soil Moisture
    int rawSoil = analogRead(SOIL_PIN);
    doc["soil"] = map(rawSoil, 4095, 0, 0, 100);
    
    // Use the distance constantly updated by the loop
    doc["distance"] = currentDistance;
    
    String response;
    serializeJson(doc, response);
    server.send(200, "application/json", response);
  });

  // 5. Soil Sensor Deployment
  server.on("/deploy_soil", []() {
    soilServo.write(90);  
    delay(2000);          
    soilServo.write(0);   
    server.send(200, "text/plain", "Soil read complete");
  });

  // 6. Camera Slow Sweep Toggle
  server.on("/toggle_cam", []() {
    sweepCam = !sweepCam;
    server.send(200, "text/plain", sweepCam ? "Sweeping" : "Stopped");
  });

  // 7. Rover Motor Controls (With Obstacle Safety)
  server.on("/F", []() { 
    if (currentDistance > 10) { 
      digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW); digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW); 
    }
    server.send(200); 
  });
  
  server.on("/B", []() { digitalWrite(IN1, LOW); digitalWrite(IN2, HIGH); digitalWrite(IN3, LOW); digitalWrite(IN4, HIGH); server.send(200); });
  server.on("/L", []() { digitalWrite(IN1, LOW); digitalWrite(IN2, HIGH); digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW); server.send(200); });
  server.on("/R", []() { digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW); digitalWrite(IN3, LOW); digitalWrite(IN4, HIGH); server.send(200); });
  server.on("/S", []() { digitalWrite(IN1, LOW); digitalWrite(IN2, LOW); digitalWrite(IN3, LOW); digitalWrite(IN4, LOW); server.send(200); });

  server.begin();
}

void loop() {
  server.handleClient();
  
  // 1. Non-blocking Distance Check (Runs every 100 milliseconds)
  if (millis() - lastSonarRead > 100) {
    lastSonarRead = millis();
    digitalWrite(TRIG_PIN, LOW); delayMicroseconds(2);
    digitalWrite(TRIG_PIN, HIGH); delayMicroseconds(10); digitalWrite(TRIG_PIN, LOW);
    
    // 30000 microsecond timeout prevents the sensor from freezing the web server
    long duration = pulseIn(ECHO_PIN, HIGH, 30000); 
    currentDistance = (duration == 0) ? 999 : (duration * 0.034 / 2);
    
    // Emergency Auto-Stop
    if (currentDistance <= 10) {
      digitalWrite(IN1, LOW); digitalWrite(IN2, LOW); 
      digitalWrite(IN3, LOW); digitalWrite(IN4, LOW);
    }
  }

  // 2. Non-blocking slow camera sweep logic
  if (sweepCam && millis() - lastCamMove > 30) { 
    lastCamMove = millis();
    camAngle += camStep;
    if (camAngle >= 180 || camAngle <= 0) {
      camStep = -camStep; 
    }
    camServo.write(camAngle);
  }
}
