import 'dart:async';
import 'package:flutter/services.dart';

class VoiceService {
  static const _channel = MethodChannel('app.lapis.todo/voice');

  static final onVoiceCommand = StreamController<String>.broadcast();

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onVoiceCommand') {
        final text = call.arguments as String?;
        if (text != null) {
          onVoiceCommand.add(text);
        }
      }
    });
  }

  static Future<String?> checkForPendingCommand() async {
    try {
      return await _channel.invokeMethod<String>('getPendingCommand');
    } catch (_) {
      return null;
    }
  }

  static Future<void> showToast(String message) async {
    try {
      await _channel.invokeMethod('showToast', {'message': message});
    } catch (_) {}
  }

  static Future<void> finishActivity() async {
    try {
      await _channel.invokeMethod('finishActivity');
    } catch (_) {}
  }
}
