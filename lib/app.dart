import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:to_do_app/screens/auth.dart';

class App extends StatelessWidget {
  // No fa falta stateful pq no canviara res aqui
  const App({Key? key})
    : super(
        key: key,
      ); // Constructor que assigna el valor de 'key' com a key d'aquest widget i aixi flutter l'identifica

  @override // Sobrescrivim el metode build del Flutter amb el nostre
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do App',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color.fromARGB(255, 21, 87, 141),
        scaffoldBackgroundColor: Colors.white,
        cupertinoOverrideTheme: CupertinoThemeData(brightness: Brightness.light),
        colorScheme: const ColorScheme.light(
          primary: Color.fromARGB(255, 21, 87, 141),
          secondary: Color.fromARGB(255, 25, 135, 226),
          surface: Colors.white,
          onSurface: Colors.black,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0C2B4B),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cupertinoOverrideTheme: CupertinoThemeData(brightness: Brightness.dark),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0C2B4B), 
          secondary: Color(0xFF13508A),
          surface: Color(0xFF222831), // Deep slate grey instead of pure black for components
          onSurface: Colors.white,
        ),
      ),
      home: const Auth(),
    );
  }
}
