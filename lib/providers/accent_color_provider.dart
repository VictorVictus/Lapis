import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accentKey = 'accent_color';

const presetAccentColors = [
  Color(0xFF15578D),
  Color(0xFF00897B),
  Color(0xFF388E3C),
  Color(0xFF7B1FA2),
  Color(0xFFD81B60),
  Color(0xFFEF6C00),
  Color(0xFFD32F2F),
];

const accentColorNames = [
  'Blue',
  'Teal',
  'Green',
  'Purple',
  'Pink',
  'Orange',
  'Red',
];

class AccentColorNotifier extends Notifier<Color> {
  @override
  Color build() {
    return presetAccentColors[0];
  }

  Future<void> persistAccent(Color color) async {
    state = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, color.toARGB32());
  }

  Future<void> loadSavedAccent() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_accentKey);
    if (saved != null) {
      state = Color(saved);
    }
  }
}

final accentColorProvider = NotifierProvider<AccentColorNotifier, Color>(AccentColorNotifier.new);
