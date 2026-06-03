import 'dart:async';
import 'package:flutter/services.dart';

class ShareService {
  static const _channel = MethodChannel('app.lapis.todo/share');

  static final onShared = StreamController<String>.broadcast();

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShared') {
        final text = call.arguments as String?;
        if (text != null) {
          onShared.add(text);
        }
      }
    });
  }

  static Future<String?> checkForPendingText() async {
    try {
      return await _channel.invokeMethod<String>('getPendingText');
    } catch (_) {
      return null;
    }
  }
}
