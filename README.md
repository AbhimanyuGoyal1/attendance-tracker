# Attendance Tracker

Attendance Tracker is a Flutter app for managing class attendance across semesters, tracking subject-level performance, and keeping data synced between local storage and Firebase.

It combines fast local-first usage with optional cloud sync, lecture reminders, attendance forecasting, timetable management, and a guided onboarding flow.

---

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

---

## Tech Stack

- Flutter
- Dart
- Hive
- Firebase Authentication
- Cloud Firestore
- GetX
- flutter_local_notifications
- fl_chart

---

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