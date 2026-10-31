# EcoFarmBot: Edge-Vision Agricultural Rover 🚜

![Demo Video](https://img.shields.io/badge/Demo_Video-Coming_Soon...-FFD700?style=for-the-badge&logo=youtube)[![Watch the Demo Video](https://img.shields.io/badge/Watch-Demo_Video-red?style=for-the-badge&logo=youtube)](YOUR_YOUTUBE_LINK_HERE)

## Overview
EcoFarmBot is a hardware-software integrated robotics project designed to provide offline, real-time agricultural monitoring and crop health analysis. Operating entirely on a private local edge network, the rover navigates crop rows, aggregates environmental data, and utilizes a custom computer vision pipeline to diagnose plant health and detect weeds without requiring cloud computing.

## Key Features
* **Edge-Processed Computer Vision:** Utilizes OpenCV for digital cropping and HSV color filtering to isolate plant matter, ignoring soil and background noise.
* **On-Device Machine Learning:** Implements a MobileNetV2 TensorFlow model trained on the 38-class PlantVillage dataset. The Python pipeline dynamically translates complex disease classifications into actionable states: *Healthy*, *Needs Water*, *Needs Fertilizer*, and *Weed Detected*.
* **Autonomous Hardware Integration:** An ESP32 microcontroller manages navigation and environment sensing, featuring an ultrasonic (HC-SR04) hardware-level safety override that halts motors within 15cm of obstacles.
* **Offline Telemetry Network:** The ESP32 hosts a localized Wi-Fi hotspot and REST API, enabling deployment in remote agricultural fields lacking internet infrastructure.
* **Cross-Platform Farmer Dashboard:** A custom Flutter application provides a real-time UI mapping the AI's health verdicts alongside live DHT22 temperature and humidity data.

## System Architecture
* **Hardware Layer:** ESP32 Dev Module, ESP32-CAM (MJPEG Stream), L298N Motor Driver, HC-SR04 Ultrasonic Sensor, DHT22 Climate Sensor.
* **Software Layer:** C++ (Arduino Firmware), Python (Inference & OpenCV), Dart (Flutter UI).
* **AI/ML Layer:** MobileNetV2 (Keras `.h5` model), TensorFlow.

## Repository Structure
```text
EcoFarmBot/
├── arduino_firmware/               # ESP32 C++ code for motor control, sensors, and web server
├── computer_vision/                # Python inference pipeline (run_rover.py) and ML model (.h5)
├── Flutter_Dashoard_EcoFarmBot/    # Source code for the Flutter mobile dashboard
├── docs/                           # IEEE research paper and circuit schematics
└── README.md
