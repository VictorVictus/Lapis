import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AppTheme {
  AppTheme._();

  static ({Color primary, Color secondary, Color tertiary}) gradientColors(
    BuildContext context,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final hsl = HSLColor.fromColor(primary);
    if (isDark) {
      final base = hsl.withLightness(0.10).toColor();
      final secondary = hsl.withLightness(0.06).toColor();
      final tertiary = hsl.withLightness(0.03).toColor();
      return (primary: base, secondary: secondary, tertiary: tertiary);
    } else {
      final secondary = hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor();
      final tertiary = hsl.withLightness((hsl.lightness + 0.35).clamp(0.0, 1.0)).toColor();
      return (primary: primary, secondary: secondary, tertiary: tertiary);
    }
  }

  static ThemeData lightTheme({Color seed = const Color(0xFF15578D)}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: seed,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.white,
      cupertinoOverrideTheme: CupertinoThemeData(brightness: Brightness.light, primaryColor: seed),
    );
  }

  static ThemeData darkTheme({Color seed = const Color(0xFF15578D)}) {
    final hsl = HSLColor.fromColor(seed);
    final vibrantPrimary = hsl.withLightness((hsl.lightness + 0.4).clamp(0.0, 1.0)).toColor();
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      primary: vibrantPrimary,
    );
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: vibrantPrimary,
      colorScheme: scheme.copyWith(
        surface: const Color(0xFF141414),
        surfaceContainerHighest: const Color(0xFF1E1E1E),
        onSurface: const Color(0xFFE0E0E0),
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      cupertinoOverrideTheme: CupertinoThemeData(brightness: Brightness.dark, primaryColor: vibrantPrimary),
    );
  }
}
