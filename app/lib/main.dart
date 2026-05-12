import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const UnderSoundMobileApp());
}

class UnderSoundMobileApp extends StatelessWidget {
  const UnderSoundMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UnderSound Mobile',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      home: const HomeScreen(),
    );
  }
}
