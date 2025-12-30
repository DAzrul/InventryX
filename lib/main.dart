import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For getting current user
import 'pages/manager/notifications/manager_notification_page.dart';
// Import Login Page sahaja
import 'pages/login_page.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// 2. BACKGROUND HANDLER
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. INISIALISASI FIREBASE
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Handle tap when app is in foreground
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ManagerNotificationPage()),
      );
    },
  );

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'expiry_alerts_channel', // ID
    'Expiry Alerts',         // Name
    description: 'This channel is used for expiry alerts',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 2. INISIALISASI HIVE
  await Hive.initFlutter();
  await Hive.openBox('settingsBox');

  // 3. MUATKAN PREFERENSI TEMA
  final settingsBox = Hive.box('settingsBox');
  final isDarkMode = settingsBox.get('darkMode', defaultValue: false);
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  runApp(const MyApp());
}

// Convert MyApp to StatefulWidget to handle Firebase Messaging
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupFirebaseMessaging();
  }

  void _setupFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permissions
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await messaging.subscribeToTopic("manager_alerts");

    // Get FCM token for this device
    String? token = await messaging.getToken();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (token != null && uid != null) {
      print("FCM Token: $token");

      // Save token to Firestore for the current user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': token});
    }

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      String title = message.notification?.title ?? message.data['title'] ?? "No Title";
      String body = message.notification?.body ?? message.data['body'] ?? "No Body";

      // Show system notification
      flutterLocalNotificationsPlugin.show(
        0,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'expiry_alerts_channel', // ID
            'Expiry Alerts',         // Name
            channelDescription: 'Channel for expiry alerts',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    });


    // Handle message when user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ManagerNotificationPage()),
      );
    });

    // Check if app was opened from a terminated state via notification
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ManagerNotificationPage()),
      );
    }
  }


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