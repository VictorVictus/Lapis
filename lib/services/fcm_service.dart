import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fcmServiceProvider = Provider<FcmService>((ref) => FcmService());

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription? _messageSub;
  StreamSubscription? _tokenSub;

  /// Initializes FCM: requests permission, gets token, sets up handlers.
  Future<void> initialize() async {
    _messageSub?.cancel();
    _tokenSub?.cancel();
    if (kIsWeb) return;

    final notifSettings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (notifSettings.authorizationStatus == AuthorizationStatus.authorized ||
        notifSettings.authorizationStatus == AuthorizationStatus.provisional) {
      _setupForegroundHandler();
      _setupBackgroundHandler();
      _setupTokenRefreshHandler();
    }
  }

  /// Gets the current FCM token and stores it in the user's Firestore doc.
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('FCM getToken error: $e');
      return null;
    }
  }

  /// Stores the FCM token in the user's Firestore document under `fcmTokens`.
  Future<void> storeToken(String userId, String token) async {
    if (kIsWeb || userId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'fcmTokens': FieldValue.arrayUnion([token])}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FCM storeToken error: $e');
    }
  }

  /// Removes a token from the user's Firestore doc (called on sign-out).
  Future<void> removeToken(String userId, String token) async {
    if (kIsWeb || userId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'fcmTokens': FieldValue.arrayRemove([token])}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FCM removeToken error: $e');
    }
  }

  void _setupForegroundHandler() {
    _messageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM foreground message: ${message.notification?.title}');
    });
  }

  void _setupBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  void _setupTokenRefreshHandler() {
    _tokenSub = _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM token refreshed: $newToken');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await storeToken(user.uid, newToken);
      }
    });
  }
}

/// Top-level background message handler (required by FCM).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}
