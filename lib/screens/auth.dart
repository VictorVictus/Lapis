import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/auth_result.dart';
import 'package:to_do_app/services/auth_service.dart';
import 'package:to_do_app/widgets/legal_consent_section.dart';
import 'package:to_do_app/theme/app_theme.dart';

class Auth extends ConsumerStatefulWidget {
  const Auth({super.key});

  @override
  ConsumerState<Auth> createState() => _AuthState();
}

class _AuthState extends ConsumerState<Auth> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _isLoading = false;
  bool _isLogin = true;
  bool _termsAccepted = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _termsAccepted = false;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent,
        content: Text(message),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleEmailAuth() async {
    if (_isLoading) return;

    if (!_isLogin && !_termsAccepted) {
      _showError('Accept the Terms of Service and Privacy Policy to continue.');
      return;
    }

    setState(() => _isLoading = true);
    final authService = ref.read(authServiceProvider);

    final AuthResult result;
    if (_isLogin) {
      result = await authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } else {
      result = await authService.register(
        email: _emailController.text,
        password: _passwordController.text,
        username: _usernameController.text,
        termsAccepted: _termsAccepted,
      );
    }

    if (!mounted) return;

    if (result.isSuccess) {
      // AuthGate navigates via authStateChanges.
      return;
    }

    setState(() => _isLoading = false);
    if (result.failureCode != AuthFailureCode.cancelled) {
      _showError(result.message ?? 'Authentication failed.');
    }
  }

  Future<void> _handleSocialAuth(
    Future<AuthResult> Function({bool recordTermsAcceptance}) socialMethod,
  ) async {
    if (_isLoading) return;

    if (!_isLogin && !_termsAccepted) {
      _showError('Accept the Terms of Service and Privacy Policy to continue.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await socialMethod(
        recordTermsAcceptance: !_isLogin && _termsAccepted,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        return;
      }

      setState(() => _isLoading = false);
      if (result.failureCode != AuthFailureCode.cancelled) {
        _showError(result.message ?? 'Sign-in failed.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Sign-in failed. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = AppTheme.gradientColors(context);

    return Scaffold(
      body: Stack(
        children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    gradientColors.primary,
                    gradientColors.secondary,
                    gradientColors.tertiary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -100,
                  right: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 24,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _isLogin ? 'Welcome Back' : 'Create Account',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isLogin
                                      ? 'Sign in to keep going'
                                      : 'Start your journey with Lapis',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 28),

                                if (!_isLogin) ...[
                                  _buildTextField(
                                    controller: _usernameController,
                                    placeholder: 'Username',
                                    icon: CupertinoIcons.person,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                _buildTextField(
                                  controller: _emailController,
                                  placeholder: 'Email Address',
                                  icon: CupertinoIcons.mail,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                ),
                                const SizedBox(height: 16),

                                _buildTextField(
                                  controller: _passwordController,
                                  placeholder: 'Password',
                                  icon: CupertinoIcons.lock,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: _isLogin
                                      ? const [AutofillHints.password]
                                      : const [AutofillHints.newPassword],
                                  onChanged: !_isLogin
                                      ? (_) => setState(() {})
                                      : null,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? CupertinoIcons.eye_slash
                                          : CupertinoIcons.eye,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),


                                if (!_isLogin) ...[
                                  const SizedBox(height: 16),
                                  LegalConsentSection(
                                    accepted: _termsAccepted,
                                    onAcceptedChanged: (value) {
                                      setState(() => _termsAccepted = value ?? false);
                                    },
                                  ),
                                ],

                                const SizedBox(height: 8),
                                Text(
                                  'We store your email, username, and tasks to provide the service. '
                                  'Data is processed via Firebase (Google).',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 11,
                                    height: 1.35,
                                  ),
                                ),

                                const SizedBox(height: 24),

                                SizedBox(
                                  height: 52,
                                  child: FilledButton(
                                    onPressed: _isLoading ? null : _handleEmailAuth,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor:
                                          Theme.of(context).colorScheme.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            _isLogin ? 'Sign In' : 'Create Account',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Colors.white.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        'or continue with',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Colors.white.withValues(alpha: 0.2),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildSocialButton(
                                    label: 'Google',
                                      onTap: () => _handleSocialAuth(
                                        ref.read(authServiceProvider).signInWithGoogle,
                                      ),
                                    ),
                                    if (!kIsWeb) ...[
                                      const SizedBox(width: 12),
                                      _buildSocialButton(
                                        label: 'Apple',
                                        onTap: () => _handleSocialAuth(
                                          ref.read(authServiceProvider).signInWithApple,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 12),
                                    _buildSocialButton(
                                      label: 'GitHub',
                                      onTap: () => _handleSocialAuth(
                                        ref.read(authServiceProvider).signInWithGitHub,
                                      ),
                                    ),
                                  ],
                                ),

                                if (_isLogin) ...[
                                  const SizedBox(height: 16),
                                  LegalConsentSection(
                                    accepted: false,
                                    onAcceptedChanged: _noop,
                                    showCheckbox: false,
                                    compact: true,
                                  ),
                                ],

                                const SizedBox(height: 20),

                                GestureDetector(
                                  onTap: _isLoading ? null : _toggleAuthMode,
                                  child: RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      text: _isLogin
                                          ? "Don't have an account? "
                                          : 'Already have an account? ',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                      children: [
                                        TextSpan(
                                          text: _isLogin ? 'Sign Up' : 'Sign In',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  static void _noop(bool? _) {}

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    TextInputAction? textInputAction,
    List<String>? autofillHints,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            onChanged: onChanged,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(icon, color: Colors.white54, size: 20),
            ),
            suffix: suffix,
            style: const TextStyle(color: Colors.white),
            placeholderStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
            ),
            decoration: null,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: 'Continue with $label',
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Center(
              child: Text(label[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
        ),
      ),
    );
  }
}
