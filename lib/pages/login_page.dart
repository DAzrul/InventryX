import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin/admin_page.dart';
import 'manager/manager_page.dart';
import 'staff/staff_page.dart';
import 'forgot_password_page.dart';
import 'register_page.dart'; // Walaupun pautan dibuang, import dikekalkan jika diperlukan di masa hadapan

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  // Fungsi utiliti statik untuk membersihkan status log masuk (Digunakan oleh Logout)
  static Future<void> clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('savedUsername');
    await prefs.remove('savedRole');
    // Pilihan: FirebaseAuth.instance.signOut();
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

  // --- FUNGSI NAVIGASI UTAMA ---
  void _navigateToHomePage(String username, String role) {
    if (role == "admin") {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminPage(loggedInUsername: username))
      );
    } else if (role == "manager") {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ManagerPage()));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const StaffPage()));
    }
  }

  // --- FUNGSI SEMAK STATUS LOG MASUK DALAM INITSTATE (Autologin) ---
  @override
  void initState() {
    super.initState();
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    // Pastikan widget masih mounted sebelum guna context atau state
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final savedUsername = prefs.getString('savedUsername');
    final savedRole = prefs.getString('savedRole');

    if (isLoggedIn && savedUsername != null && savedRole != null) {
      // Jika status disimpan, navigasi terus tanpa meminta login
      _navigateToHomePage(savedUsername, savedRole);
    }
  }

  // --- FUNGSI UNTUK KOSONGKAN MEDAN ---
  void _clearControllers() {
    usernameController.clear();
    passwordController.clear();
  }

  // --- POPUP MESSAGE ---
  void showPopupMessage(String title, {String? details}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF233E99),
            ),
          ),
          content: details != null ? Text(details) : null,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _clearControllers();
              },
              child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        );
      },
    );
  }

  // --- Logik Log Masuk DENGAN Firebase Authentication ---
  Future<void> loginUser() async {
    String inputId = usernameController.text.trim();
    String password = passwordController.text.trim();

    if (inputId.isEmpty || password.isEmpty) {
      showPopupMessage("Incomplete Information", details: "Please enter your email and password.");
      return;
    }

    // Pastikan input adalah e-mel untuk Firebase Auth
    final String email = inputId.contains('@') ? inputId : '';

    if (email.isEmpty) {
      showPopupMessage("Login Failed", details: "Please enter a valid email address to log in.");
      return;
    }


    setState(() => loading = true);

    try {
      // LANGKAH 1: Log masuk menggunakan Firebase Authentication
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        showPopupMessage("Login Failed", details: "Authentication service error.");
        setState(() => loading = false);
        return;
      }

      // LANGKAH 2: Semak data pengguna dalam Firestore (untuk Role & Status)
      QuerySnapshot userSnap = await FirebaseFirestore.instance
          .collection("users")
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userSnap.docs.isEmpty) {
        showPopupMessage("Login Failed", details: "User data not found in Firestore.");
        await _auth.signOut();
        setState(() => loading = false);
        return;
      }

      var userDoc = userSnap.docs.first;
      var user = userDoc.data() as Map<String, dynamic>;

      // Semak Status Akaun
      if (user["status"] != "Active") {
        showPopupMessage("Account Disabled", details: "Your account has been disabled. Please contact the Administrator.");
        await _auth.signOut();
        setState(() => loading = false);
        return;
      }

      // Jika berjaya dan status Active
      String loggedInUsername = user["username"] ?? user["email"] ?? "User";
      String role = user["role"];

      // --- FUNGSI 'REMEMBER ME' ---
      if (rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('savedUsername', loggedInUsername);
        await prefs.setString('savedRole', role);
      }

      _clearControllers();
      showPopupMessage("Login Successful!", details: "Welcome, $loggedInUsername."); // Pemberitahuan ringkas
      _navigateToHomePage(loggedInUsername, role); // Navigasi ke halaman utama

    } on FirebaseAuthException catch (e) {
      String errorMessage = "Login failed.";
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        errorMessage = "Invalid email or password.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "The email address format is invalid.";
      }
      showPopupMessage("Authentication Failed", details: errorMessage);
    } catch (e) {
      showPopupMessage("System Error", details: "Failed to process login: ${e.toString()}");
    } finally {
      setState(() => loading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isPortrait = constraints.maxHeight > constraints.maxWidth;
          double horizontalPadding = constraints.maxWidth * 0.08;

          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  SizedBox(
                    height: isPortrait
                        ? constraints.maxHeight * 0.2
                        : constraints.maxHeight * 0.35,
                    child: Image.asset("assets/logo.png", fit: BoxFit.contain),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.02),

                  Text(
                    "Welcome",
                    style: TextStyle(
                        fontSize: isPortrait
                            ? constraints.maxWidth * 0.08
                            : constraints.maxHeight * 0.07,
                        fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.005),

                  Text(
                    "Sign in to continue.",
                    style: TextStyle(
                        fontSize: isPortrait
                            ? constraints.maxWidth * 0.045
                            : constraints.maxHeight * 0.04,
                        color: Colors.grey[600]),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.03),


                  // Email field
                  TextField(
                    controller: usernameController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Email Address",
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.02),

                  // Password field
                  TextField(
                    controller: passwordController,
                    obscureText: !showPassword,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(showPassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => showPassword = !showPassword),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.01),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Checkbox Remember Me
                          Checkbox(
                            value: rememberMe,
                            onChanged: (v) =>
                                setState(() => rememberMe = v!),
                          ),
                          const Text("Remember me"),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                          );
                        },
                        child: const Text("Forgot password?"),
                      )

                    ],
                  ),

                  SizedBox(height: constraints.maxHeight * 0.03),

                  // Sign In Button
                  SizedBox(
                    width: double.infinity,
                    height: constraints.maxHeight * 0.07,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF233E99),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: loading ? null : loginUser,
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                        "SIGN IN",
                        style: TextStyle(
                          fontSize: isPortrait
                              ? constraints.maxWidth * 0.05
                              : constraints.maxHeight * 0.04,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.02),

                ],
              ),
            ),
          );
        },
      ),
    );
  }
}