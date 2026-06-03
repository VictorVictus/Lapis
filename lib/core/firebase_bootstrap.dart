import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _crashConsentKey = 'crashlytics_consent_given';

/// Checks user consent before enabling Crashlytics.
Future<bool> _hasUserConsentedToCrashReporting() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_crashConsentKey) ?? false;
}

/// Persists the user's crash reporting consent choice.
Future<void> setCrashReportingConsent(bool consented) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_crashConsentKey, consented);
}

/// Activates App Check and Crashlytics on Android/iOS after Firebase init.
Future<void> configureFirebaseProductionServices() async {
  if (kIsWeb) return;

  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? AndroidDebugProvider()
        : AndroidPlayIntegrityProvider(),
    providerApple:
        kDebugMode ? AppleDebugProvider() : AppleAppAttestProvider(),
  );

  final userHasConsented = await _hasUserConsentedToCrashReporting();
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(userHasConsented);

  if (userHasConsented) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
}
