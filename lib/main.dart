import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CookingApp()));
}

class CookingApp extends StatelessWidget {
  const CookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Cookbook',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD85A2B), // Warm terracotta kitchen theme
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD85A2B),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}
