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
import 'pages/notifications/low_stock_alert_detail_page.dart';
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

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null) {
        try {
          final Map<String, dynamic> data = Map<String, dynamic>.from(
              Uri.splitQueryString(response.payload!)
          );
          MyApp.handleLocalNotificationClick(data);
        } catch (e) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
          );
        }
      }
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
  themeNotifier.value = settingsBox.get('darkMode', defaultValue: false)
      ? ThemeMode.dark : ThemeMode.light;

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void handleLocalNotificationClick(Map<String, dynamic> data) {
    _MyAppState.instance?._handleNotificationClick(RemoteMessage(data: data));
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static _MyAppState? instance;

  @override
  void initState() {
    super.initState();
    instance = this;
    _setupFirebaseMessaging();
  }

  @override
  void dispose() {
    instance = null;
    super.dispose();
  }

  // 🔹 Robust Handler: Navigates only if the user is verified as logged in
  Future<void> _handleNotificationClick(RemoteMessage message) async {
    final data = message.data;
    final user = FirebaseAuth.instance.currentUser;

    // 1. Strict Security: If no user, immediately force Login and stop
    if (user == null) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
      );
      return;
    }

    try {
      // 2. Fetch role for detail pages
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return; // Guard against deleted users

      final String role = userDoc.data()?['role'] ?? 'staff';
      final String type = data['alertType'] ?? '';

      // 3. Direct Navigation Logic
      if (type == 'risk') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => RiskAlertDetailPage(
              riskAnalysisId: data['riskAnalysisId'] ?? data['riskId'] ?? "",
              alertId: "",
              userRole: role,
            ),
          ),
        );
      } else if (type == 'expiry') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ExpiryAlertDetailPage(
              batchId: data['batchId'] ?? "",
              productId: data['productId'] ?? "",
              stage: data['stage'] ?? "5",
              userRole: role,
            ),
          ),
        );
      } else if (type == 'lowStock') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => LowStockAlertDetailPage(
              productId: data['productId'] ?? "",
              // 🔹 FIXED: Now correctly extracts the alertId passed from index.js
              alertId: data['alertId'] ?? "",
              userRole: role,
            ),
          ),
        );
      } else {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => NotificationPage(userRole: role)),
        );
      }
    } catch (e) {
      debugPrint("Routing Error: $e");
    }
  }

  void _setupFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.subscribeToTopic("inventory_alerts");

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message);
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationClick(message);
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      String title = message.notification?.title ?? "Inventory Alert";
      String body = message.notification?.body ?? "";
      String payload = Uri(
          queryParameters: message.data.map((key, value) => MapEntry(key, value.toString()))
      ).query;

      flutterLocalNotificationsPlugin.show(
        message.hashCode, title, body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'expiry_alerts_channel', 'Expiry Alerts',
            importance: Importance.max, priority: Priority.high,
          ),
        ),
        payload: payload,
      );
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
          // 🔹 Use StreamBuilder to handle initial landing page
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              // While waiting for Firebase to verify session, show loading
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              // If user exists, we stay on the default entry point (handled by notifications later)
              // If user is null, we strictly show the LoginPage
              return const LoginPage();
            },
          ),
        );
      },
    );
  }
}