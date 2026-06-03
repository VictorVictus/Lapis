import 'package:flutter/services.dart';

class FocusModeService {
  static const _channel = MethodChannel('app.lapis.todo/focus_mode');

  Future<bool> startLockTask() async {
    try {
      await _channel.invokeMethod('startLockTask');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopLockTask() async {
    try {
      await _channel.invokeMethod('stopLockTask');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openSecuritySettings() async {
    try {
      await _channel.invokeMethod('openSecuritySettings');
      return true;
    } catch (_) {
      return false;
    }
  }
}
