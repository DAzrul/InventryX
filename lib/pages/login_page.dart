import 'dart:io';
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
import 'verify_2fa_page.dart';

class LoginPage extends StatefulWidget {
  final String? autoLoginUsername;
  const LoginPage({super.key, this.autoLoginUsername});

  static Future<void> clearLoginState(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('savedUserId');

    if (userId != null) {
      await _recordActivity(
          userId, "Sign Out", "User signed out of the account.");
    }

    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('savedRole');
    await prefs.remove('savedUserId');
    await prefs.remove('savedUsername');
    await FirebaseAuth.instance.signOut();
  }

  static Future<void> _recordActivity(
      String userId, String action, String details) async {
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

  // Warna Utama (Dark Blue dari design)
  final Color primaryBlue = const Color(0xFF233E99);

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // --- LOGIC AUTO LOGIN ---
  Future<void> _checkLoginStatus() async {
    if (widget.autoLoginUsername != null) {
      usernameController.text = widget.autoLoginUsername!;
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
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(savedUserId)
            .get();
        if (userDoc.exists && _auth.currentUser != null) {
          Map<String, dynamic> userData =
          userDoc.data() as Map<String, dynamic>;
          String freshUsername = userData['username'];
          String freshRole = userData['role'];

          if (userData['status'] == 'Active') {
            await prefs.setString('savedUsername', freshUsername);
            await prefs.setString('savedRole', freshRole);
            await LoginPage._recordActivity(
                savedUserId, "Auto Login", "Session restored via auto-login.");
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

  // --- LOGIC MANUAL LOGIN ---
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
        userSnap = await FirebaseFirestore.instance
            .collection("users")
            .where('email', isEqualTo: input)
            .limit(1)
            .get();
      } else {
        userSnap = await FirebaseFirestore.instance
            .collection("users")
            .where('username', isEqualTo: input)
            .limit(1)
            .get();
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

      bool is2FAEnabled = userData['is2FAEnabled'] ?? false;

      if (userData['status'] != 'Active') {
        _showSnack("Account disabled. Please contact your administrator.");
        setState(() => loading = false);
        return;
      }

      await _auth.signInWithEmailAndPassword(email: email, password: password);

      if (is2FAEnabled) {
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
        await LoginPage._recordActivity(
            userId, "Login", "User manually signed in.");

        if (rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
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
      target = AdminPage(
        loggedInUsername: username,
        userId: userId,
        username: '',
      );
    } else if (role == "manager") {
      target = ManagerPage(
        loggedInUsername: username,
        userId: userId,
        username: '',
      );
    } else {
      target = StaffPage(
        loggedInUsername: username,
        userId: userId,
        username: '',
      );
    }
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => target));
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: primaryBlue));

  // --- UI SECTION ---
  @override
  Widget build(BuildContext context) {
    // Detect jika keyboard terbuka
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        // PENTING: Ini membenarkan UI ditolak ke atas oleh keyboard
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  // Padding dinamik: Bila keyboard buka, kita tambah padding bawah supaya boleh scroll
                  padding: EdgeInsets.only(
                    left: 24.0,
                    right: 24.0,
                    bottom: isKeyboardVisible ? MediaQuery.of(context).viewInsets.bottom + 20 : 20,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Kurangkan jarak atas bila keyboard buka supaya logo tak hilang terus
                      SizedBox(height: isKeyboardVisible ? 10 : 40),

                      // 1. LOGO MENGECIL (Animasi Halus)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        height: isKeyboardVisible ? 100 : 180, // Kecilkan logo bila menaip
                        child: Image.asset("assets/logo.png"),
                      ),

                      // Jarak antara logo dan tajuk
                      SizedBox(height: isKeyboardVisible ? 0 : 10),

                      // 2. TAJUK (Font 42, #005A99)
                      const Text(
                        "InventryX",
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF005A99),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // 3. INPUT FIELDS
                      _buildModernField(usernameController, Icons.person_outline,
                          label: "Username"),
                      const SizedBox(height: 20),
                      _buildModernField(passwordController, Icons.lock_outline,
                          label: "Password", isPassword: true),

                      const SizedBox(height: 20),

                      // 4. REMEMBER ME & FORGOT PASSWORD
                      _buildUtilsRow(),

                      const SizedBox(height: 30),

                      // 5. SIGN IN BUTTON
                      _buildLoginButton(),

                      // Ruang ekstra di bawah supaya butang tak rapat sangat dengan keyboard
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

  Widget _buildModernField(TextEditingController controller, IconData icon,
      {required String label, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && !showPassword,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey),
              suffixIcon: isPassword
                  ? IconButton(
                icon: Icon(
                  showPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: Colors.grey,
                ),
                onPressed: () =>
                    setState(() => showPassword = !showPassword),
              )
                  : null,
              border: InputBorder.none,
              contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              hintText: "Enter ${label.toLowerCase()}",
              hintStyle: TextStyle(color: Colors.grey.shade400),
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
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: rememberMe,
                onChanged: (v) => setState(() => rememberMe = v!),
                activeColor: primaryBlue,
                side: const BorderSide(color: Colors.grey, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "Remember me",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        TextButton(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
          child: const Text(
            "Forgot password?",
            style: TextStyle(
              color: Color(0xFF233E99), // Guna primaryBlue
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: loading ? null : loginUser,
        child: const Text(
          "Sign In",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildBlurLoading() => Container(
    color: Colors.white.withOpacity(0.7),
    child: Center(child: CircularProgressIndicator(color: primaryBlue)),
  );
}