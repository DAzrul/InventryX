import 'dart:io'; // Mandatory for platform checking
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Destination Imports
import 'admin/admin_page.dart';
import 'manager/manager_page.dart';
import 'staff/staff_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  final String? autoLoginUsername;
  const LoginPage({super.key, this.autoLoginUsername});

  // Updated to log sign-out activity before clearing state
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

  // Global helper to record activity into the user's sub-collection
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
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool rememberMe = false;
  bool showPassword = false;
  bool loading = false;

  final Color primaryBlue = const Color(0xFF233E99);

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // --- REPAIRED AUTO LOGIN LOGIC ---
  Future<void> _checkLoginStatus() async {
    if (widget.autoLoginUsername != null) {
      usernameController.text = widget.autoLoginUsername!;
      setState(() => loading = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final String? savedUserId = prefs.getString('savedUserId');

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
            await prefs.setString('savedUsername', freshUsername);
            await prefs.setString('savedRole', freshRole);

            // Record Auto-Login Activity
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

  // --- MANUAL LOGIN LOGIC ---
  Future<void> loginUser() async {
    String input = usernameController.text.trim();
    String password = passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      _showSnack("Enter your credentials, mat!");
      return;
    }

    if (!await _isNetworkAvailable()) {
      _showSnack("No internet? Fucking connect first.");
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
        _showSnack("User not found dlm system!");
        setState(() => loading = false);
        return;
      }

      var userData = userSnap.docs.first.data() as Map<String, dynamic>;
      String email = userData['email'];
      String username = userData['username'];
      String role = userData['role'];
      String userId = userSnap.docs.first.id;

      if (userData['status'] != 'Active') {
        _showSnack("Account disabled. Go talk to admin.");
        setState(() => loading = false);
        return;
      }

      await _auth.signInWithEmailAndPassword(email: email, password: password);

      // Record Manual Login Activity
      await LoginPage._recordActivity(userId, "Login", "User manually signed in.");

      if (rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('savedUsername', username);
        await prefs.setString('savedRole', role);
        await prefs.setString('savedUserId', userId);
      }

      _navigateToHomePage(username, role, userId);
    } on FirebaseAuthException catch (e) {
      _showSnack("Auth Failed: ${e.message}");
    } catch (e) {
      _showSnack("System Error: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ... (Keep the rest of your UI building blocks from previous turn) ...

  Future<bool> _isNetworkAvailable() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  void _navigateToHomePage(String username, String role, String userId) {
    if (!mounted) return;
    Widget target = (role == "admin") ? AdminPage(loggedInUsername: username, userId: userId) :
    (role == "manager") ? ManagerPage(loggedInUsername: username, userId: userId) :
    StaffPage(loggedInUsername: username, userId: userId);

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => target));
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, backgroundColor: primaryBlue)
  );

  @override
  Widget build(BuildContext context) {
    // UI logic from previous turn mat...
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  Center(child: Image.asset("assets/logo.png", height: 100)),
                  const SizedBox(height: 50),
                  const Text("Sign In", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
                  const SizedBox(height: 40),
                  _buildModernField(usernameController, Icons.person_outline_rounded, label: "Email or Username"),
                  const SizedBox(height: 25),
                  _buildModernField(passwordController, Icons.lock_outline_rounded, label: "Password", isPassword: true),
                  const SizedBox(height: 15),
                  _buildUtilsRow(),
                  const SizedBox(height: 40),
                  _buildLoginButton(),
                ],
              ),
            ),
          ),
          if (loading) _buildBlurLoading(),
        ],
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
              Checkbox(value: rememberMe, onChanged: (v) => setState(() => rememberMe = v!)),
              const Text("Stay Signed In", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
          child: Text("Forgot?", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w800, fontSize: 13)),
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
        gradient: LinearGradient(colors: [primaryBlue, primaryBlue.withValues(alpha: 0.85)]),
        boxShadow: [BoxShadow(color: primaryBlue.withValues(alpha: 0.3), blurRadius: 25, offset: const Offset(0, 10))],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
        onPressed: loading ? null : loginUser,
        child: const Text("SIGN IN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
      ),
    );
  }

  Widget _buildBlurLoading() => Container(color: Colors.white.withValues(alpha: 0.7), child: Center(child: CircularProgressIndicator(color: primaryBlue)));
}