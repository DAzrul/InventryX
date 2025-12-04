// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart'; // [BARU] Import SharedPreferences

import 'pages/launch_page.dart';
import 'firebase_options.dart';

// [BARU] Notifier untuk memberitahu MyApp apabila tema berubah
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Cuba muatkan preferensi tema awal
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('darkMode') ?? false;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Gunakan ValueListenableBuilder untuk mendengar perubahan tema
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentThemeMode, __) {
        return MaterialApp(
          title: 'InventoryX',

          // --- TEMA APLIKASI ---
          // 1. Tema Terang (Light Theme)
          theme: ThemeData(
            primarySwatch: Colors.blue,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.blue,
              brightness: Brightness.light,
            ).copyWith(
              // Warna utama untuk Light Mode
              primary: const Color(0xFF233E99),
              secondary: Colors.amber,
              surface: Colors.white,
            ),
            scaffoldBackgroundColor: Colors.grey[50],
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
          ),

          // 2. Tema Gelap (Dark Theme)
          darkTheme: ThemeData(
            primarySwatch: Colors.indigo,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.indigo,
              brightness: Brightness.dark,
            ).copyWith(
              // Warna utama untuk Dark Mode
              primary: const Color(0xFF6783D1), // Warna yang lebih lembut untuk Dark Mode
              secondary: Colors.orangeAccent,
              surface: Colors.grey[850],
            ),
            scaffoldBackgroundColor: Colors.grey[900],
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
            ),
          ),

          // 3. Mod Tema Dinamik (Menggunakan nilai dari ThemeNotifier)
          themeMode: currentThemeMode,

          // Atur LaunchPage sebagai halaman awal
          home: const LaunchPage(),
        );
      },
    );
  }
}