// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// [TAMBAH INI] Import Firebase Auth
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'pages/login_page.dart';
import 'pages/staff/staff_page.dart';

import 'firebase_options.dart';

// Notifier untuk memberitahu MyApp apabila tema berubah
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. INISIALISASI FIREBASE
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. INISIALISASI HIVE 🚀
  await Hive.initFlutter();
  // [TAMBAH] Daftar TypeAdapters di sini
  await Hive.openBox('settingsBox');

  // 3. MUATKAN PREFERENSI TEMA DARI HIVE
  final settingsBox = Hive.box('settingsBox');
  final isDarkMode = settingsBox.get('darkMode', defaultValue: false);
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentThemeMode, __) {
        return MaterialApp(
          title: 'InventoryX',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.blue,
              brightness: Brightness.light,
            ).copyWith(
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
          darkTheme: ThemeData(
            primarySwatch: Colors.indigo,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.indigo,
              brightness: Brightness.dark,
            ).copyWith(
              primary: const Color(0xFF6783D1),
              secondary: Colors.orangeAccent,
              surface: Colors.grey[900], // Menukar kepada nilai yang lebih gelap
            ),
            scaffoldBackgroundColor: Colors.grey[900],
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
            ),
          ),
          themeMode: currentThemeMode,
          // [PERUBAHAN UTAMA DI SINI] Guna AuthWrapper
          home: const AuthWrapper(),
        );
      },
    );
  }
}

// [TAMBAH KELAS INI] Auth Wrapper untuk menguruskan status log masuk
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder untuk mendengar perubahan status Firebase Auth
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Paparkan loading screen/splash screen (boleh guna LaunchPage di sini jika LaunchPage anda adalah splash screen)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasData && snapshot.data != null) {
          // Jika pengguna sudah log masuk
          return const StaffPage();
        } else {
          // Jika pengguna belum log masuk
          return const LoginPage();
        }
      },
    );
  }
}