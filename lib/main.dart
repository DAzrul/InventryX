import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Import Login Page sahaja
import 'pages/login_page.dart';
import 'firebase_options.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. INISIALISASI FIREBASE
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. INISIALISASI HIVE
  await Hive.initFlutter();
  await Hive.openBox('settingsBox');

  // 3. MUATKAN PREFERENSI TEMA
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
          debugShowCheckedModeBanner: false, // Hilangkan banner debug
          theme: ThemeData(
            primarySwatch: Colors.blue,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF233E99),
              primary: const Color(0xFF233E99),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF9FAFC),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white, // Elak warna tukar bila scroll
              centerTitle: true,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            // Setup tema gelap anda di sini jika perlu
          ),
          themeMode: currentThemeMode,

          // [PENTING] Tetapkan home kepada LoginPage.
          // LoginPage akan automatik check jika user dah login (Auto-Login)
          // dan redirect ke Manager/Staff/Admin yang betul.
          home: const LoginPage(),
        );
      },
    );
  }
}