import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/accent_color_provider.dart';
import 'package:to_do_app/providers/theme_provider.dart';
import 'package:to_do_app/providers/smart_filters_provider.dart';
import 'package:to_do_app/screens/auth_gate.dart';
import 'package:to_do_app/theme/app_theme.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      ref.read(themeModeProvider.notifier).loadSavedTheme();
      ref.read(accentColorProvider.notifier).loadSavedAccent();
      ref.read(smartFiltersProvider.notifier).loadSaved();
      _loaded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final accentColor = ref.watch(accentColorProvider);
    return MaterialApp(
      title: 'To-Do App',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme(seed: accentColor),
      darkTheme: AppTheme.darkTheme(seed: accentColor),
      home: const AuthGate(),
    );
  }
}
