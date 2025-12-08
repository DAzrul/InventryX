import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Gantikan import ini dengan laluan yang betul dalam projek anda
import 'admin/admin_page.dart';
import 'manager/manager_page.dart';
import 'staff/staff_page.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  // [UBAH] Tambah parameter untuk auto-login dari ProfilePage (Switch Account)
  final String? autoLoginUsername;

  const LoginPage({super.key, this.autoLoginUsername});

  static Future<void> clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('savedRole');
    await prefs.remove('savedUserId');
    await FirebaseAuth.instance.signOut();
    // Nota: 'savedUsername' dikekalkan untuk paparan pada skrin Login, tetapi ia dibersihkan
    // jika kita hanya mahu satu pilihan. Kita kekalkan remove untuk kesederhanaan.
    await prefs.remove('savedUsername');
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

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); // Panggil fungsi untuk semak status sesi
  }

  // FUNGSI BARU: Semak Status Log Masuk dan Cuba Auto-Login
  Future<void> _checkLoginStatus() async {
    // Senario 1: Auto-Login dari Change Account (autoLoginUsername disediakan)
    if (widget.autoLoginUsername != null) {
      usernameController.text = widget.autoLoginUsername!;
      // Mesej kepada pengguna jika ini adalah switch account
      showPopupMessage("Account Switch",
          details: "Please re-enter the password for ${widget.autoLoginUsername} to continue the session.");

      setState(() {
        loading = false; // Pastikan Loading dimatikan
      });
      return;
    }

    // Senario 2: Auto-Login dari Remember Me (Log Masuk Biasa)
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final String? savedUsername = prefs.getString('savedUsername');
    final String? savedRole = prefs.getString('savedRole');
    final String? savedUserId = prefs.getString('savedUserId');

    if (isLoggedIn && savedUsername != null && savedRole != null && savedUserId != null) {
      if (!await _isNetworkAvailable()) {
        showPopupMessage("Offline Mode", details: "Could not restore session. Please connect to the internet and sign in manually.");
        return;
      }

      // Jika token Firebase Auth masih sah, navigasi terus
      if (_auth.currentUser != null && _auth.currentUser!.uid == savedUserId) {
        _navigateToHomePage(savedUsername, savedRole, savedUserId);
        // Tetapkan loading true semasa proses navigasi berlaku
        setState(() => loading = true);
      } else {
        // Token Auth Firebase tamat tempoh atau tidak sepadan. Log masuk manual.
        await LoginPage.clearLoginState();
        showPopupMessage("Session Expired", details: "Your previous session has expired. Please sign in again.");
        setState(() => loading = false);
      }
    }
  }

  void _navigateToHomePage(String username, String role, String userId) {
    if (!mounted) return;
    if (role == "admin") {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminScreen(loggedInUsername: username, userId: userId,))
      );
    } else if (role == "manager") {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ManagerPage()));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const StaffPage()));
    }
  }

  void _clearControllers() {
    usernameController.clear();
    passwordController.clear();
  }

  void showPopupMessage(String title, {String? details}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF233E99))),
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

  // FUNGSI SEMAK RANGKAIAN
  Future<bool> _isNetworkAvailable() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }


  Future<void> loginUser() async {
    String input = usernameController.text.trim();
    String password = passwordController.text.trim();
    String emailToAuthenticate = '';
    String usernameForNavigation = '';
    String firestoreDocId = '';
    Map<String, dynamic>? userData;

    if (input.isEmpty || password.isEmpty) {
      showPopupMessage("Incomplete Information", details: "Please enter your username/email and password.");
      return;
    }

    // LANGKAH 0: SEMAK RANGKAIAN
    if (!await _isNetworkAvailable()) {
      showPopupMessage("Offline Mode", details: "You need an active internet connection to sign in.");
      return;
    }

    setState(() => loading = true);

    try {
      // LANGKAH 1: Cari Pengguna di Firestore berdasarkan Email ATAU Username
      QuerySnapshot userSnap;
      if (input.contains('@')) {
        userSnap = await FirebaseFirestore.instance.collection("users").where('email', isEqualTo: input).limit(1).get();
        emailToAuthenticate = input;
      } else {
        userSnap = await FirebaseFirestore.instance.collection("users").where('username', isEqualTo: input).limit(1).get();
      }

      if (userSnap.docs.isNotEmpty) {
        userData = userSnap.docs.first.data() as Map<String, dynamic>;
        emailToAuthenticate = userData['email'];
        usernameForNavigation = userData['username'] ?? userData['email'];
        firestoreDocId = userSnap.docs.first.id;

        if (userData["status"] != "Active") {
          showPopupMessage("Account Disabled", details: "Your account has been disabled. Please contact the Administrator.");
          await _auth.signOut();
          setState(() => loading = false);
          return;
        }
      } else if (!input.contains('@')) {
        showPopupMessage("Login Failed", details: "Username or email not found.");
        setState(() => loading = false);
        return;
      } else {
        emailToAuthenticate = input;
      }

      if (emailToAuthenticate.isEmpty) {
        showPopupMessage("Login Failed", details: "Could not determine authentication email.");
        setState(() => loading = false);
        return;
      }

      // LANGKAH 2: Log masuk menggunakan Firebase Authentication
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: emailToAuthenticate,
        password: password,
      );

      // LANGKAH 3: Semak semula data jika ia tidak diambil di Langkah 1
      if (userData == null) {
        userSnap = await FirebaseFirestore.instance.collection("users").where('email', isEqualTo: emailToAuthenticate).limit(1).get();

        if (userSnap.docs.isEmpty) {
          showPopupMessage("Login Failed", details: "User data not found in Firestore after authentication.");
          await _auth.signOut();
          setState(() => loading = false);
          return;
        }
        userData = userSnap.docs.first.data() as Map<String, dynamic>;
        usernameForNavigation = userData['username'] ?? userData['email'];
        firestoreDocId = userSnap.docs.first.id;

        if (userData["status"] != "Active") {
          showPopupMessage("Account Disabled", details: "Your account has been disabled. Please contact the Administrator.");
          await _auth.signOut();
          setState(() => loading = false);
          return;
        }
      }

      String role = userData!["role"] ?? 'staff';

      // --- FUNGSI 'REMEMBER ME' ---
      if (rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('savedUsername', usernameForNavigation);
        await prefs.setString('savedRole', role);
        await prefs.setString('savedUserId', firestoreDocId);
      }

      _clearControllers();
      _navigateToHomePage(usernameForNavigation, role, firestoreDocId);

    } on FirebaseAuthException catch (e) {
      String errorMessage = "Login failed.";
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        errorMessage = "Invalid username/email or password.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "The email address format is invalid.";
      } else if (e.code == 'network-request-failed') {
        errorMessage = "Network connection failed. Please check your internet.";
      }
      showPopupMessage("Authentication Failed", details: errorMessage);
    } catch (e) {
      showPopupMessage("System Error", details: "Failed to process login: ${e.toString()}");
      debugPrint("Login General Error: $e");
    } finally {
      if(mounted) {
        setState(() => loading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // ... (Kod UI) ...
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
                    height: isPortrait ? constraints.maxHeight * 0.2 : constraints.maxHeight * 0.35,
                    child: Image.asset("assets/logo.png", fit: BoxFit.contain),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.02),
                  Text("Welcome", style: TextStyle(
                      fontSize: isPortrait ? constraints.maxWidth * 0.08 : constraints.maxHeight * 0.07,
                      fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.005),
                  Text("Sign in to continue.", style: TextStyle(
                      fontSize: isPortrait ? constraints.maxWidth * 0.045 : constraints.maxHeight * 0.04,
                      color: Colors.grey[600]),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.03),

                  // Email/Username field
                  TextField(
                    controller: usernameController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Email or Username",
                      prefixIcon: const Icon(Icons.person_outline),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
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
                        icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => showPassword = !showPassword),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
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
                            onChanged: (v) => setState(() => rememberMe = v!),
                          ),
                          const Text("Remember me"),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          // Pastikan laluan ForgotPasswordPage adalah betul
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: loading ? null : loginUser,
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                        "SIGN IN",
                        style: TextStyle(
                          fontSize: isPortrait ? constraints.maxWidth * 0.05 : constraints.maxHeight * 0.04,
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