import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import the shared pages
import 'pages/notifications/notification_page.dart';
import 'pages/notifications/expiry_alert_detail_page.dart';
import 'pages/notifications/risk_alert_detail_page.dart';

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
      // For local notifications, we navigate to the general list.
      // Note: role fetching for local notifications usually requires a wrapper or state management.
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const LoginPage()), // Re-routing through login handles role check
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

  // 🔹 UPDATED: Fetch user role before deep-linking to detail pages
  Future<void> _handleNotificationClick(RemoteMessage message) async {
    final data = message.data;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return;

    // Fetch the role from Firestore to pass to the shared pages
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final String role = userDoc.data()?['role'] ?? 'staff';

    // 1. Handle Risk Alerts
    if (data['alertType'] == 'risk' || data.containsKey('riskId')) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => RiskAlertDetailPage(
            riskAnalysisId: data['riskId'] ?? "",
            alertId: "",
            userRole: role,
          ),
        ),
      );
    }
    // 2. Handle Expiry Alerts
    else if (data.containsKey('batchId') && data.containsKey('productId')) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ExpiryAlertDetailPage(
            batchId: data['batchId'],
            productId: data['productId'],
            stage: data['stage'] ?? "5",
            userRole: role,
          ),
        ),
      );
    }
    // 3. Fallback to general list
    else {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => NotificationPage(userRole: role)),
      );
    }
  }

  void _setupFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // 🔹 Ensure topic matches index.js
    await messaging.subscribeToTopic("inventory_alerts");

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

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message);
    });

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
          navigatorKey: navigatorKey,
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