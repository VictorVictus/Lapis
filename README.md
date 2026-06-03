# Lapis

<p align="center">
  <img src="assets/icon/lapis.png" alt="Lapis" width="128">
</p>

A modern, cross-platform task management app built with Flutter and Firebase. Lapis combines a clean UI with real-time sync, focus tools, and deep customization — no subscriptions, no ads.

## Features

- **Authentication** — Email/password, Google Sign-In, Apple Sign-In, and GitHub OAuth
- **Dashboard** — Filter by status (Undone / In Progress / Fulfilled), search, Kanban view, smart filters, group/sort options
- **Task Management** — Titles, notes, deadlines, priorities, categories, subtasks, recurring tasks, pinning, archiving
- **Calendar view** — Interactive date grid with colored task dots and per-day task lists
- **Focus Mode** — Built-in Pomodoro timer with Android screen pinning support
- **Statistics** — Completion streaks, bar charts (last 7 days), breakdowns by category/priority, focus session stats
- **Notifications** — Deadline reminders via FCM push notifications and local scheduled alerts
- **Weekly Review** — Automatic Sunday recap dialog with weekly completion count
- **Realtime Sync** — Cloud Firestore with offline persistence
- **Theming** — Light/dark/system mode, customizable accent colors
- **Cross-platform** — Android, iOS, Web, macOS, Windows, Linux

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart 3.x) |
| State | Riverpod |
| Backend | Firebase (Auth, Firestore, Cloud Functions, FCM, App Check, Crashlytics) |
| Storage | Firebase Storage (profile pictures) |

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (stable channel, Dart 3.x)
- A Firebase project with Authentication, Firestore, and Storage enabled

### Setup

```bash
# Clone the repo
git clone https://github.com/<your-org>/lapis.git
cd lapis

# Install dependencies
flutter pub get

# Configure Firebase
flutterfire configure --project=todoa-e26b3

# Run on a device or emulator
flutter run
```

> **Note:** Firestore security rules and indexes are tracked in `firestore.rules` and `firestore.indexes.json`. Deploy them with:
> ```bash
> firebase deploy --only firestore:rules,firestore:indexes
> ```

### Cloud Functions

Deadline reminder push notifications run as a scheduled Cloud Function:

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

## Project Structure

```
lib/
├── core/              # Bootstrap, assets, legal, shared utilities
├── models/            # Data models (Task, User, FocusSession, etc.)
├── providers/         # Riverpod state providers
├── screens/           # Auth, Dashboard, Schedule, Focus, Stats, Archive
├── services/          # Firebase interop (Auth, Tasks, Notifications, etc.)
├── theme/             # Light & dark theme definitions
└── widgets/           # Reusable UI components
```

## License

This project is a work in progress.
