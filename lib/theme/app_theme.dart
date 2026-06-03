import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AppTheme {
  AppTheme._();

  /// Computes gradient colors from the scheme's primary (which is stable
  /// across Flutter SDK versions), avoiding reliance on [ColorScheme.fromSeed]'s
  /// algorithm which changes between releases and produces inconsistent
  /// secondary/tertiary tones.
  ///
  /// Returns a record with [primary], [secondary], and [tertiary] suitable
  /// for [LinearGradient].
  static ({Color primary, Color secondary, Color tertiary}) gradientColors(
    BuildContext context,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    final hsl = HSLColor.fromColor(primary);
    final secondary = hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor();
    final tertiary = hsl.withLightness((hsl.lightness + 0.35).clamp(0.0, 1.0)).toColor();
    return (primary: primary, secondary: secondary, tertiary: tertiary);
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
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: seed,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF121212),
      cupertinoOverrideTheme: CupertinoThemeData(brightness: Brightness.dark, primaryColor: seed),
    );
  }
}
