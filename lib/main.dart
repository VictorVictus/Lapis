import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/core/firebase_bootstrap.dart';
import 'package:to_do_app/widgets/error_boundary_widget.dart';
import 'dart:developer';
import 'app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:to_do_app/services/fcm_service.dart';
import 'package:to_do_app/services/notification_service.dart';
import 'package:to_do_app/services/share_service.dart';
import 'package:to_do_app/services/voice_service.dart';
import 'package:to_do_app/services/widget_data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: ErrorBoundaryWidget(errorDetails: errorDetails),
      ),
    );
  };

  if (kIsWeb) {
    FlutterError.onError = (FlutterErrorDetails details) {
      log('Framework error caught: ${details.exceptionAsString()}');
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      log('Async error caught: $error', error: error, stackTrace: stack);
      return true;
    };
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await configureFirebaseProductionServices();

  final notificationService = NotificationService();
  await notificationService.initialize();

  final fcmService = FcmService();
  await fcmService.initialize();

  ShareService.init();
  VoiceService.init();

  await WidgetDataService.initialize();

  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  } else {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }

  runApp(const ProviderScope(child: App()));
}

