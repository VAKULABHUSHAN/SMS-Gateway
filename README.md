# SMS & WhatsApp Local Gateway

A powerful Flutter-based local gateway application that turns your Android device into a programmable hub for sending SMS and WhatsApp messages. 

## 🚀 Overview

This application runs a local HTTP server directly on your mobile device. Devices on the same network can make standard REST API calls to this server, which then utilizes the native Android APIs to dispatch text messages through your phone's SIM card.

Additionally, the app features a built-in Testing Console with an intelligent Smart Queue system for automating WhatsApp message delivery!

## ✨ Key Features

### 📡 Local HTTP REST Server
- **Always-on Server**: Runs an HTTP server (`dart:io`) binding to your local WiFi IP.
- **RESTful Endpoints**: Provides `/send` and `/send_bulk` endpoints to receive JSON payloads containing phone numbers and messages.
- **Live Activity Console**: Logs all incoming network requests and their success/failure status directly on the app's dashboard.

### ✉️ Native SMS Dispatch
- **Method Channels**: Communicates seamlessly with Android's native `SmsManager` via Kotlin/Java `MethodChannel` to send SMS messages invisibly in the background.
- **Bulk SMS**: Send identical messages to arrays of phone numbers in a single API call.

### 💬 WhatsApp Integration & Smart Queue
- **WhatsApp Launching**: Deep links into WhatsApp natively using Android Intents (`url_launcher`).
- **Bulk WhatsApp Smart Queue**: Because WhatsApp blocks background sending, this app features a clever "Smart Queue". It tracks `AppLifecycleState` to automatically pop up the next WhatsApp chat the moment you switch back from sending the previous one!

### 📱 Developer Tools & UI
- **Native Contact Picker**: Select numbers directly from your phone's address book without requiring invasive, blanket "Read Contacts" permissions.
- **cURL Snippet Generator**: Automatically generates copy-pasteable `cURL` commands for the API based on your current IP address.
- **Testing Console**: A sleek UI to test SMS and WhatsApp dispatches manually before hooking them up to your backend.

## 🛠️ How it works

1. **Start the Server**: Open the app and tap "START SERVER". Note the IP address shown on the screen (e.g., `192.168.1.10:8080`).
2. **Send an API Request**: From any computer on the same WiFi network, make a POST request:
   ```bash
   curl -X POST http://192.168.1.10:8080/send \
   -H "Content-Type: application/json" \
   -d '{"number": "+1234567890", "message": "Hello from the Gateway!"}'
   ```
3. **Bulk API Request**:
   ```bash
   curl -X POST http://192.168.1.10:8080/send_bulk \
   -H "Content-Type: application/json" \
   -d '{"numbers": ["+1234567890", "+0987654321"], "message": "Bulk Alert!"}'
   ```
4. **WhatsApp Smart Queue**: Enter a list of comma-separated numbers in the app UI, hit "WHATSAPP BULK QUEUE", and the app will guide you through sending them all rapidly via the official WhatsApp app.

## ⚙️ Architecture & Tech Stack

- **Framework**: Flutter / Dart
- **State Management**: Ephemeral `setState` coupled with `WidgetsBindingObserver` for lifecycle tracking.
- **Native Bridges**: `MethodChannel` for accessing Android `SmsManager`.
- **Dependencies**: 
  - `flutter_native_contact_picker`: Secure native contact selection.
  - `url_launcher`: Android intents for WhatsApp dispatch.
  - `network_info_plus`: For discovering local WLAN IP addresses.
