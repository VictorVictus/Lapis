# Todoist+ Flutter App

A modern, collaborative To-Do application built with Flutter and Firebase. This app provides a sleek user interface for managing tasks, tracking deadlines, and collaborating with others in real-time.

## 🚀 Features

- **Secure Authentication**: User sign-up and login powered by Firebase Authentication.
- **Dynamic Dashboard**: 
  - Filter tasks by status: *Undone*, *In Progress*, and *Fulfilled*.
  - Real-time search functionality.
  - Interactive calendar view for scheduling.
- **Advanced Task Management**:
  - Create tasks with titles, descriptions, and categories.
  - Set specific deadlines with visual countdowns.
  - Swipe-to-complete and swipe-to-delete gestures for a fluid UX.
- **Collaborative Experience**:
  - View task ownership with creator profile pictures.
  - Real-time updates across devices using Cloud Firestore.
- **Personalization**:
  - Customizable categories with a built-in color picker.
  - Profile picture uploads integrated with Firebase Storage.
- **Cross-Platform**: Designed to work seamlessly on Mobile (Android/iOS) and Web.

## 🛠️ Tech Stack

- **Frontend**: [Flutter](https://flutter.dev/) (Dart)
- **Backend**: [Firebase](https://firebase.google.com/)
  - **Firestore**: Real-time NoSQL database.
  - **Auth**: Secure user management.
  - **Storage**: Cloud storage for profile images.
- **Styling**: Standard Material & Cupertino widgets for a native feel.

## 📦 Key Dependencies

- `firebase_core` & `firebase_auth`: Fundamental Firebase integration.
- `cloud_firestore`: For real-time task syncing.
- `flutter_colorpicker`: Customizing task category colors.
- `image_picker` & `firebase_storage`: Handling profile picture uploads.
- `intl`: Precise date and time formatting.

## ⚙️ Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed on your machine.
- A Firebase project configured.

### Installation

1. **Clone the Repo**:
   ```bash
   git clone <repository-url>
   cd to_do_app
   ```

2. **Install Packages**:
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**:
   - Run `flutterfire configure` to set up your Firebase environment locally.
   - Ensure Firestore and Storage rules are configured to allow authenticated access.

4. **Run the App**:
   ```bash
   flutter run
   ```

## 🤝 Contributing

This project is a work in progress. Feel free to open issues or submit pull requests to improve the app!
