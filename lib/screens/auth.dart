import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:to_do_app/services/auth_service.dart';
import 'package:to_do_app/screens/dashboard.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


class Auth extends StatefulWidget {
  const Auth({super.key});

  @override
  State<Auth> createState() => _AuthState();
}

class _AuthState extends State<Auth> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  final _authService = AuthService();
  bool _isLoading = false;
  bool _isLogin = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
    _animationController.reset();
    _animationController.forward();
  }

  Future<void> _handleAuth() async {
    setState(() => _isLoading = true);
    dynamic user;
    
    if (_isLogin) {
      user = await _authService.signIn(
        _emailController.text,
        _passwordController.text,
      );
    } else {
      user = await _authService.register(
        context,
        _emailController.text,
        _passwordController.text,
        _usernameController.text,
      );
    }

    if (user != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => Dashboard(user: user)),
      );
    } else if (mounted) {
      setState(() => _isLoading = false);
      if (_isLogin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Invalid email or password.'),
          ),
        );
      }
    }
  }

  Future<void> _handleSocialAuth(Future<dynamic> Function() socialMethod) async {
    setState(() => _isLoading = true);
    try {
      final user = await socialMethod();
      if (user != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => Dashboard(user: user)),
        );
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Social login failed: ${e.toString()}'),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
              Theme.of(context).colorScheme.tertiary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Smooth background decorative elements
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isLogin ? "Welcome Back" : "Create Account",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isLogin ? "Sign in to keep going" : "Start your journey with us",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 35),
                            
                            // Fields
                            if (!_isLogin) ...[
                              _buildTextField(
                                controller: _usernameController,
                                placeholder: "Username",
                                icon: CupertinoIcons.person,
                              ),
                              const SizedBox(height: 20),
                            ],
                            _buildTextField(
                              controller: _emailController,
                              placeholder: "Email Address",
                              icon: CupertinoIcons.mail,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _passwordController,
                              placeholder: "Password",
                              icon: CupertinoIcons.lock,
                              obscureText: true,
                            ),
                            
                            const SizedBox(height: 35),
                            
                            // Main Action Button
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _handleAuth,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 5,
                                ),
                                child: _isLoading 
                                  ? const CupertinoActivityIndicator() 
                                  : Text(
                                      _isLogin ? "Sign In" : "Sign Up",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                              ),
                            ),
                            
                            const SizedBox(height: 25),
                            // Divider
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 15),
                                child: Text(
                                  "or continue with",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                            ],
                          ),

                          const SizedBox(height: 25),

                          // Social Row - Platform specific
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Google - works on all platforms (needs config for web)
                              _buildSocialButton(
                                icon: FontAwesomeIcons.google,
                                onTap: () => _handleSocialAuth(_authService.signInWithGoogle),
                              ),
                              
                              // Apple - only show on iOS/macOS (not on web)
                              if (!kIsWeb)
                                _buildSocialButton(
                                  icon: FontAwesomeIcons.apple,
                                  onTap: () => _handleSocialAuth(_authService.signInWithApple),
                                ),
                              
                              // GitHub - works on all platforms (needs config)
                              _buildSocialButton(
                                icon: FontAwesomeIcons.github,
                                onTap: () => _handleSocialAuth(_authService.signInWithGitHub),
                              ),
                            ],
                          ),
                            
                            const SizedBox(height: 35),
                            
                            // Toggle Mode
                            GestureDetector(
                              onTap: _toggleAuthMode,
                              child: RichText(
                                text: TextSpan(
                                  text: _isLogin ? "Don't have an account? " : "Already have an account? ",
                                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                                  children: [
                                    TextSpan(
                                      text: _isLogin ? "Sign Up" : "Log In",
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            obscureText: obscureText,
            keyboardType: keyboardType,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            style: const TextStyle(color: Colors.white),
            placeholderStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Icon(icon, color: Colors.white.withOpacity(0.5), size: 20),
            ),
            decoration: null,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({required FaIconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Center(
          child: FaIcon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}