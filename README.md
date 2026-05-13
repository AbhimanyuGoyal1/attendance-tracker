# Attendance Tracker

Attendance Tracker is a Flutter app for managing class attendance across semesters, tracking subject-level performance, and keeping data synced between local storage and Firebase.

It combines fast local-first usage with optional cloud sync, lecture reminders, attendance forecasting, timetable management, and a guided onboarding flow.

## Features

- Track attendance by subject, semester, and lecture slot
- Support both slot-based subjects and hour-wise subjects
- Mark lectures as `Present`, `Absent`, or `Cancelled`
- Set per-subject attendance goals and see how many classes you can safely miss
- Forecast future attendance if you attend or miss upcoming classes
- Configure lecture reminders with Android local notifications
- Mark attendance directly from notification actions
- View analytics and timetable screens for planning and review
- Sync subjects and settings with Firebase Authentication + Cloud Firestore
- Store data locally with Hive for offline-first behavior
- Personalize theme colors, gradients, dark mode, compact cards, and other settings
- Built-in onboarding, tutorial flow, and interactive guide

## Tech Stack

- Flutter
- Dart
- Hive
- Firebase Auth
- Cloud Firestore
- GetX
- `flutter_local_notifications`
- `fl_chart`

## Project Structure

```text
lib/
  main.dart                     # App entry, auth gate, theme setup
  home_screen.dart              # Main dashboard and attendance actions
  controllers/                  # Session and home state management
  data/                         # Local subject persistence helpers
  models/                       # Subject and app settings models
  screens/                      # Login, onboarding, timetable, analytics, settings
  services/                     # Notifications, Firestore sync, settings, utilities
  theme/                        # App theme configuration
  widgets/                      # Reusable UI components
```

## How It Works

- Local data is stored in Hive so the app remains usable offline.
- User authentication is handled with Firebase Auth using email/password and Google Sign-In.
- Subject data and settings can sync to Firestore per user and per semester.
- Attendance is tracked either per lecture slot or as total hours for hour-wise subjects.
- Notification reminders are scheduled from the saved timetable and can trigger quick attendance updates on Android.

## Getting Started

### Prerequisites

- Flutter SDK `3.10.x` or newer compatible with Dart `^3.10.7`
- Android Studio or VS Code with Flutter tooling
- A Firebase project if you want authentication and cloud sync

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
flutter run
```

## Firebase Setup

This project already includes `android/app/google-services.json` for Android. If you want to use your own Firebase project, replace it with your own config.

### Android

The Android app is already wired for Firebase through:

- `android/app/google-services.json`
- `android/app/build.gradle.kts`

### iOS

iOS Firebase configuration is not present in the repository. To enable it:

1. Add `GoogleService-Info.plist` to `ios/Runner/`
2. Register the iOS app in Firebase
3. Run `flutterfire configure` if you want a cleaner multi-platform setup

## Notifications

Android notification permissions are declared in `android/app/src/main/AndroidManifest.xml`.

The app uses:

- `POST_NOTIFICATIONS`
- `SCHEDULE_EXACT_ALARM`

Reminder behavior:

- Reminders are scheduled from each subject's timetable
- Users can choose reminder lead time
- Notification actions can mark a lecture `Present` or `Absent`
- On some Android devices, battery optimization settings may need to be adjusted for reliable delivery

## Main Screens

- `Login`: email/password sign-in, account creation, password reset, Google sign-in
- `Home`: subject cards, quick attendance actions, reminder controls, forecasts, goals
- `Timetable`: lecture schedule overview and planning
- `Analytics`: attendance trends and summary charts
- `Settings`: semester management, personalization, sync-related preferences
- `Onboarding` and `Tutorial`: first-run setup and guided walkthrough

## Data Model

The core `Subject` model supports:

- Subject name, code, and instructor
- Weekly schedule by weekday
- Hour-wise tracking mode
- Attendance history by date
- Rescheduled lectures
- Carry-over attendance
- Reminder settings
- Attendance goal percentage

## Build Notes

- Android application ID is currently `com.example.attendance_tracker`
- Release signing reads from `android/key.properties` if present
- If `key.properties` is missing, release builds fall back to debug signing

## Testing

Run tests with:

```bash
flutter test
```

Note: the current `test/widget_test.dart` is still the default Flutter counter smoke test and does not reflect the actual app behavior yet.

## Known Gaps

- iOS Firebase configuration is not included
- The Android package name is still the default example identifier
- Automated tests have not been updated to cover the current app

## Suggested Next Improvements

- Replace the default package/application identifiers
- Add proper widget and service tests
- Move Firebase setup to `flutterfire configure` for cleaner multi-platform support
- Add export/import for attendance data
- Add CI for `flutter analyze` and `flutter test`

## License

No license file is currently included in this repository.
