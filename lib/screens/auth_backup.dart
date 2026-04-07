import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:to_do_app/services/auth_service.dart';
import 'package:to_do_app/screens/dashboard.dart';

class Auth extends StatefulWidget {
  const Auth({super.key});

  @override
  State<Auth> createState() => _AuthState();
}

class _AuthState extends State<Auth> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final authService = AuthService();
  bool Loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: CupertinoColors.white.withOpacity(0.25),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Welcome to ToDo!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 3.0,
                              color: Color.fromARGB(144, 0, 0, 0),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Log in to continue",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 3.0,
                              color: Color.fromARGB(144, 0, 0, 0),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      CupertinoTextField(
                        controller: emailController,
                        placeholder: 'E-mail / Username',
                        style: const TextStyle(color: Colors.white),
                        placeholderStyle: const TextStyle(color: Colors.white),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: CupertinoColors.white,
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 40),
                      CupertinoTextField(
                        controller: passwordController,
                        placeholder: 'Password',
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        placeholderStyle: const TextStyle(color: Colors.white),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: CupertinoColors.white,
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 40),
                      FilledButton(
                        onPressed: () async {
                          setState(() => Loading = true);
                          final authService = AuthService();
                          final user = await authService.signIn(
                            emailController.text,
                            passwordController.text,
                          );
                          if (user != null) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => Dashboard(user: user),
                              ),
                            );
                          } else {
                            setState(() => Loading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Colors.red,
                                content: Text('Email o password is incorrect'),
                              ),
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: CupertinoColors.white.withOpacity(
                            0.25,
                          ), // opcional: fondo semitransparente
                        ),
                        child: Text(Loading ? 'Logging in...' : 'Log In'),
                      ),
                      SizedBox(height: 20),
                      const Text(
                        "Or",
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          _showRegistrationForm(context);
                        },
                        child: Text(
                          "Sign Up!",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            decoration: TextDecoration.underline,
                          ),
                          textAlign: TextAlign.center,
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
    );
  }

  void _showRegistrationForm(BuildContext context) {
    final TextEditingController email = TextEditingController();
    final TextEditingController password = TextEditingController();
    final TextEditingController username = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Input your registration details'),
          content: Column(
            children: [
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: email,
                placeholder: 'E-mail',
                style: const TextStyle(color: Colors.white),
                placeholderStyle: const TextStyle(color: Colors.white),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.white,
                      width: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: password,
                placeholder: 'Password',
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                placeholderStyle: const TextStyle(color: Colors.white),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.white,
                      width: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: username,
                placeholder: 'Username',
                style: const TextStyle(color: Colors.white),
                placeholderStyle: const TextStyle(color: Colors.white),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.white,
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              textStyle: TextStyle(color: Colors.red),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              textStyle: TextStyle(color: Colors.green),
              onPressed: () async {
                final user = await authService.register(
                  context,
                  email.text,
                  password.text,
                  username.text,
                );
                if (user != null) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Register'),
            ),
          ],
        );
      },
    );
  }
}
