import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pages/manager/notifications/manager_notification_page.dart';
// 🔹 ADD THIS IMPORT
import 'pages/manager/notifications/expiry_alert_detail_page.dart';

import 'pages/login_page.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Tapping foreground local notification goes to the general list
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ManagerNotificationPage()),
      );
    },
  );

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'expiry_alerts_channel',
    'Expiry Alerts',
    description: 'This channel is used for expiry alerts',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await Hive.initFlutter();
  await Hive.openBox('settingsBox');
  final settingsBox = Hive.box('settingsBox');
  themeNotifier.value = settingsBox.get('darkMode', defaultValue: false) ? ThemeMode.dark : ThemeMode.light;

  runApp(const MyApp());
}

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

  // 🔹 ADDED THIS HELPER METHOD FOR NAVIGATION
  void _handleNotificationClick(RemoteMessage message) {
    final data = message.data;
    if (data.containsKey('batchId') && data.containsKey('productId')) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ExpiryAlertDetailPage(
            batchId: data['batchId'],
            productId: data['productId'],
            stage: data['stage'] ?? "5",
          ),
        ),
      );
    } else {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ManagerNotificationPage()),
      );
    }
  }

  void _setupFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.subscribeToTopic("manager_alerts");

    String? token = await messaging.getToken();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (token != null && uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'fcmToken': token});
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      String title = message.notification?.title ?? "No Title";
      String body = message.notification?.body ?? "No Body";

      flutterLocalNotificationsPlugin.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'expiry_alerts_channel',
            'Expiry Alerts',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    });

    // 🔹 UPDATED: Handle Tap when app is in Background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message);
    });

    // 🔹 UPDATED: Check if app was opened from Terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationClick(message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentThemeMode, __) {
        return MaterialApp(
          navigatorKey: navigatorKey, // 🔹 REQUIRED FOR NAVIGATION
          title: 'InventoryX',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF233E99)),
          ),
          themeMode: currentThemeMode,
          home: const LoginPage(),
        );
      },
    );
  }
}