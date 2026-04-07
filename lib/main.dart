import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/widgets/error_boundary_widget.dart';
import 'dart:developer';
import 'app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:to_do_app/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Visually polite crash UI
  ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: ErrorBoundaryWidget(errorDetails: errorDetails),
      ),
    );
  };

  // 2. Catch framework errors (prevents catastrophic crashes)
  FlutterError.onError = (FlutterErrorDetails details) {
    log('Framework error caught: ${details.exceptionAsString()}');
    FlutterError.presentError(details); // Routes correctly to our custom UI component above
  };

  // 3. Catch async asynchronous errors (futures, etc.)
  PlatformDispatcher.instance.onError = (error, stack) {
    log('Async error caught: $error');
    return true; // Prevents the app from fatally exiting
  };
  

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize Notifications and Timezones
  final notificationService = NotificationService();
  await notificationService.initialize();
  if (!kIsWeb) {
    await notificationService.requestPermissions();
  }

  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  }
  else{
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }

  runApp(const ProviderScope(child: App()));
}
