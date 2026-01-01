import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Package Biometric
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

// Destination Imports
// (Pastikan path folder ni betul ikut projek kau)
import 'admin/admin_page.dart';
import 'manager/manager_page.dart';
import 'staff/staff_page.dart';
import 'forgot_password_page.dart';
import 'verify_2fa_page.dart';

class LoginPage extends StatefulWidget {
  final String? autoLoginUsername;
  const LoginPage({super.key, this.autoLoginUsername});

  static Future<void> clearLoginState(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('savedUserId');

    if (userId != null) {
      await _recordActivity(userId, "Sign Out", "User signed out of the account.");
    }

    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('savedRole');
    await prefs.remove('savedUserId');
    await prefs.remove('savedUsername');
    await FirebaseAuth.instance.signOut();
  }

  static Future<void> _recordActivity(String userId, String action, String details) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('activities')
          .add({
        'action': action,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': Platform.isAndroid ? 'Android' : 'iOS',
      });
    } catch (e) {
      debugPrint("Failed to record activity: $e");
    }
  }

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State Variables
  bool rememberMe = false;
  bool showPassword = false;
  bool loading = false;

  // Biometric Variables
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false; // Phone support tak?
  bool _hasSavedUser = false; // Ada user pernah login tak?

  final Color primaryBlue = const Color(0xFF233E99);

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); // Cek Auto Login
    _checkBiometricsSupport(); // Cek Support Jari/FaceID
  }

  // --- 1. LOGIC BIOMETRIC SETUP ---
  Future<void> _checkBiometricsSupport() async {
    late bool canCheckBiometrics;
    try {
      canCheckBiometrics = await auth.canCheckBiometrics;
    } on PlatformException catch (_) {
      canCheckBiometrics = false;
    }

    // Cek SharedPreferences: Kita hanya benarkan biometric kalau ada data user tersimpan
    final prefs = await SharedPreferences.getInstance();
    final String? savedId = prefs.getString('savedUserId');

    if (!mounted) return;
    setState(() {
      _canCheckBiometrics = canCheckBiometrics;
      _hasSavedUser = savedId != null;
    });
  }

  // --- 2. LOGIC BIOMETRIC ACTION ---
  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: 'Scan your face or fingerprint to login securely',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      _showSnack("Biometric Error: ${e.message}");
      return;
    }

    if (!mounted) return;

    if (authenticated) {
      // BIOMETRIC LULUS! Ambil data lama & Login terus
      final prefs = await SharedPreferences.getInstance();
      String? username = prefs.getString('savedUsername');
      String? role = prefs.getString('savedRole');
      String? userId = prefs.getString('savedUserId');

      if (username != null && role != null && userId != null) {
        await LoginPage._recordActivity(userId, "Biometric Login", "User logged in via FaceID/Fingerprint.");
        _navigateToHomePage(username, role, userId);
      } else {
        _showSnack("Session expired. Please login with password first.");
      }
    }
  }

  // --- 3. LOGIC AUTO LOGIN (APP START) ---
  Future<void> _checkLoginStatus() async {
    if (widget.autoLoginUsername != null) {
      usernameController.text = widget.autoLoginUsername!;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final String? savedUserId = prefs.getString('savedUserId');

    // Kalau ada tiket "Trusted Device" (isLoggedIn = true)
    if (isLoggedIn && savedUserId != null) {
      if (!await _isNetworkAvailable()) {
        final savedUsername = prefs.getString('savedUsername');
        final savedRole = prefs.getString('savedRole');
        if (savedUsername != null && savedRole != null) {
          _navigateToHomePage(savedUsername, savedRole, savedUserId);
        }
        return;
      }

      setState(() => loading = true);
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(savedUserId).get();
        if (userDoc.exists && _auth.currentUser != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          String freshUsername = userData['username'];
          String freshRole = userData['role'];

          if (userData['status'] == 'Active') {
            // Update data latest & Masuk Home
            await prefs.setString('savedUsername', freshUsername);
            await prefs.setString('savedRole', freshRole);
            await LoginPage._recordActivity(savedUserId, "Auto Login", "Session restored via auto-login.");
            _navigateToHomePage(freshUsername, freshRole, savedUserId);
          } else {
            await LoginPage.clearLoginState(context);
          }
        }
      } catch (e) {
        debugPrint("Auto login error: $e");
      } finally {
        if (mounted) setState(() => loading = false);
      }
    }
  }

  // --- 4. LOGIC MANUAL LOGIN (USERNAME/PASS) ---
  Future<void> loginUser() async {
    String input = usernameController.text.trim();
    String password = passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      _showSnack("Please enter your credentials.");
      return;
    }

    if (!await _isNetworkAvailable()) {
      _showSnack("No internet connection. Please connect first.");
      return;
    }

    setState(() => loading = true);

    try {
      QuerySnapshot userSnap;
      if (input.contains('@')) {
        userSnap = await FirebaseFirestore.instance.collection("users").where('email', isEqualTo: input).limit(1).get();
      } else {
        userSnap = await FirebaseFirestore.instance.collection("users").where('username', isEqualTo: input).limit(1).get();
      }

      if (userSnap.docs.isEmpty) {
        _showSnack("User not found in the system.");
        setState(() => loading = false);
        return;
      }

      var userData = userSnap.docs.first.data() as Map<String, dynamic>;
      String email = userData['email'];
      String username = userData['username'];
      String role = userData['role'];
      String userId = userSnap.docs.first.id;

      // CHECK 2FA STATUS DARI DATABASE
      bool is2FAEnabled = userData['is2FAEnabled'] ?? false;

      if (userData['status'] != 'Active') {
        _showSnack("Account disabled. Please contact your administrator.");
        setState(() => loading = false);
        return;
      }

      // Login ke Firebase
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      // --- LOGIC PENENTUAN 2FA ---
      if (is2FAEnabled) {
        // Kena OTP! Bawa ke Verify Page
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Verify2FAPage(
              userId: userId,
              username: username,
              role: role,
              email: email,
              rememberMe: rememberMe,
            ),
          ),
        );
      } else {
        // TAK PAYAH OTP! Login Biasa
        await LoginPage._recordActivity(userId, "Login", "User manually signed in.");

        if (rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true); // Cop Trusted Device
          await prefs.setString('savedUsername', username);
          await prefs.setString('savedRole', role);
          await prefs.setString('savedUserId', userId);
        }

        _navigateToHomePage(username, role, userId);
      }

    } on FirebaseAuthException catch (e) {
      String errorMsg = "Login Failed: ${e.message}";
      if (e.code == 'wrong-password') errorMsg = "Incorrect password.";
      _showSnack(errorMsg);
    } catch (e) {
      _showSnack("System Error: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<bool> _isNetworkAvailable() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  void _navigateToHomePage(String username, String role, String userId) {
    if (!mounted) return;
    Widget target;
    if (role == "admin") {
      target = AdminPage(loggedInUsername: username, userId: userId, username: '',);
    } else if (role == "manager") {
      target = ManagerPage(loggedInUsername: username, userId: userId);
    } else {
      target = StaffPage(loggedInUsername: username, userId: userId);
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => target));
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, backgroundColor: primaryBlue)
  );

  // --- UI SECTION (Dah Fix Keyboard & Nama App) ---
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Logic: Tekan luar field, keyboard tutup
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        // Logic: Resize UI bila keyboard naik supaya tak tertutup
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30),

                      // LOGO
                      Image.asset("assets/logo.png", height: 100),
                      const SizedBox(height: 15),

                      // NAMA APP
                      Text(
                        "InventryX",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: primaryBlue,
                          letterSpacing: 1.5,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Tajuk Sign In
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Sign In", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
                      ),

                      const SizedBox(height: 30),

                      _buildModernField(usernameController, Icons.person_outline_rounded, label: "Email or Username"),
                      const SizedBox(height: 25),
                      _buildModernField(passwordController, Icons.lock_outline_rounded, label: "Password", isPassword: true),

                      const SizedBox(height: 15),
                      _buildUtilsRow(),

                      const SizedBox(height: 40),
                      _buildLoginButton(),

                      // BUTANG BIOMETRIC (FACE ID / FINGERPRINT)
                      if (_canCheckBiometrics && _hasSavedUser) ...[
                        const SizedBox(height: 30),
                        Center(
                          child: Column(
                            children: [
                              IconButton(
                                iconSize: 60,
                                icon: Icon(Icons.lock_person_rounded, color: primaryBlue),
                                onPressed: _authenticate,
                                tooltip: "Secure Login",
                              ),
                              const SizedBox(height: 5),
                              const Text("Tap to unlock", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],

                      // Jarak bawah untuk keyboard breathing room
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            if (loading) _buildBlurLoading(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernField(TextEditingController controller, IconData icon, {required String label, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: const Color(0xFFF5F7FB), borderRadius: BorderRadius.circular(18)),
          child: TextField(
            controller: controller,
            obscureText: isPassword && !showPassword,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: primaryBlue),
              suffixIcon: isPassword ? IconButton(
                icon: Icon(showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                onPressed: () => setState(() => showPassword = !showPassword),
              ) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUtilsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => setState(() => rememberMe = !rememberMe),
          child: Row(
            children: [
              Checkbox(
                value: rememberMe,
                onChanged: (v) => setState(() => rememberMe = v!),
                activeColor: primaryBlue,
              ),
              const Text("Stay Signed In", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
          child: Text("Forgot Password?", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(colors: [primaryBlue, primaryBlue.withOpacity(0.85)]),
        boxShadow: [BoxShadow(color: primaryBlue.withOpacity(0.3), blurRadius: 25, offset: const Offset(0, 10))],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
        onPressed: loading ? null : loginUser,
        child: const Text("SIGN IN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
      ),
    );
  }

  Widget _buildBlurLoading() => Container(
      color: Colors.white.withOpacity(0.7),
      child: Center(child: CircularProgressIndicator(color: primaryBlue))
  );
}