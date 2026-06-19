import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/providers/auth_provider.dart';
import 'package:to_do_app/screens/auth.dart';
import 'package:to_do_app/theme/app_theme.dart';
import 'package:to_do_app/screens/dashboard.dart';
import 'package:to_do_app/widgets/onboarding_screen.dart';

/// Routes between sign-in and the main app based on Firebase Auth session.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final done = await hasOnboardingBeenCompleted();
    if (mounted) setState(() => _onboardingDone = done);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    ref.listen(authStateProvider, (prev, next) {
      if (prev?.hasValue == true && next.hasValue) {
        final prevUser = prev!.value;
        final nextUser = next.value;
        if (prevUser == null && nextUser != null) {
          setState(() => _onboardingDone = null);
          _checkOnboarding();
        }
      }
    });

    return authState.when(
      loading: () => const _AuthSplash(),
      error: (error, _) => _AuthError(message: error.toString()),
      data: (user) {
        if (user == null) {
          return const Auth();
        }
        if (_onboardingDone == null) {
          return const _AuthSplash();
        }
        if (_onboardingDone == false) {
          return OnboardingScreen(next: Dashboard(user: user));
        }
        return Dashboard(user: user);
      },
    );
  }
}

class _AuthSplash extends StatelessWidget {
  const _AuthSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.gradientColors(context).primary,
              AppTheme.gradientColors(context).secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}

class _AuthError extends ConsumerWidget {
  const _AuthError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not restore your session.\n$message',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CupertinoButton(
                onPressed: () => ref.invalidate(authStateProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
