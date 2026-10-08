# Shine Attendance - Cross-Platform (Android & iOS)

This Flutter app wraps the Shine Attendance platform (`https://attendance.shineinfosolutions.in`) with native support for:
- 📷 Camera (Selfie verification for check-in)
- 📍 GPS Geolocation (In-office validation & background tracking)
- 🔔 Notifications
- 🔄 Pull-to-refresh & offline error recovery
- 📱 Native JS Bridge (`window.ShineNative`)

---

## 🚀 How to Build Android APK

1. Make sure Flutter is added to your PATH.
2. Open terminal in this folder:
   ```bash
   cd flutter_attendance_app
   flutter pub get
   flutter build apk --release
   ```
3. Your APK will be generated at:
   `build/app/outputs/flutter-apk/app-release.apk`

---

## 🍏 How to Build iOS App

1. Open this project in Xcode on a Mac, or use GitHub Actions:
   ```bash
   flutter build ipa --release
   ```
2. Open `ios/Runner.xcworkspace` in Xcode to configure your Apple Developer Team and sign the app.
