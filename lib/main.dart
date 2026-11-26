import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'controllers/auth_controller.dart';
import 'firebase_options.dart';
import 'views/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthController().initializeGoogle();
  runApp(const ExploreTeresinaApp());
}

class ExploreTeresinaApp extends StatelessWidget {
  const ExploreTeresinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF176B5B);
    return MaterialApp(
      title: 'Explore Teresina',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: verde),
        scaffoldBackgroundColor: const Color(0xFFF7F8F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F8F6),
          foregroundColor: Color(0xFF18302B),
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
