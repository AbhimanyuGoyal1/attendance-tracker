# Attendance Tracker

Attendance Tracker is a Flutter application designed to help students manage and monitor their attendance efficiently across semesters and subjects.

The app supports attendance forecasting, timetable-based reminders, analytics, offline-first storage, and optional Firebase cloud sync for a smooth and modern attendance management experience.

---

## Features

* Track attendance by subject and semester
* Support for slot-based and hour-wise subjects
* Mark lectures as Present, Absent, or Cancelled
* Attendance percentage calculation and forecasting
* Attendance goal tracking
* Timetable and lecture scheduling
* Android notification reminders
* Quick attendance marking from notifications
* Offline-first local storage using Hive
* Firebase Authentication and Firestore sync
* Analytics and attendance insights
* Dark mode and UI personalization
* Guided onboarding and tutorial flow

---

## Tech Stack

* Flutter
* Dart
* Hive
* Firebase Authentication
* Cloud Firestore
* GetX
* flutter_local_notifications
* fl_chart

---

## Project Structure

```text
lib/
  controllers/      # State management and controllers
  data/             # Local storage helpers
  models/           # Data models
  screens/          # UI screens
  services/         # Firebase, notifications, utilities
  theme/            # Theme configuration
  widgets/          # Reusable widgets
  main.dart         # App entry point
```

---

## Getting Started

### Prerequisites

* Flutter SDK
* Android Studio or VS Code
* Firebase project (optional for cloud sync)

### Install Dependencies

```bash
flutter pub get
```

### Run the App

```bash
flutter run
```

---

## Firebase Setup

### Android

1. Create a Firebase project
2. Register your Android app
3. Download `google-services.json`
4. Place it inside:

```text
android/app/
```

### iOS

1. Register the iOS app in Firebase
2. Add `GoogleService-Info.plist` to:

```text
ios/Runner/
```

---

## Notifications

The app supports Android local notifications for lecture reminders and quick attendance actions.

Permissions used:

* POST_NOTIFICATIONS
* SCHEDULE_EXACT_ALARM

---

## Main Modules

* Authentication
* Attendance Dashboard
* Timetable Management
* Analytics & Insights
* Settings & Personalization
* Onboarding & Tutorial

---

## Future Improvements

* Export/import attendance data
* Better analytics and predictions
* Cross-device sync improvements
* Automated testing
* CI/CD integration

---

## License

This project currently does not include a license.
