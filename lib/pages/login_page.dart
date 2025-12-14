import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Import halaman-halaman destinasi
import 'admin/admin_page.dart';
import 'manager/manager_page.dart';
import 'staff/staff_page.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  final String? autoLoginUsername;

  const LoginPage({super.key, this.autoLoginUsername});

  static Future<void> clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('savedRole');
    await prefs.remove('savedUserId');
    await FirebaseAuth.instance.signOut();
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
    _checkLoginStatus();
  }

  // --- [BAHAGIAN YANG DIBETULKAN] ---
  Future<void> _checkLoginStatus() async {
    // Senario 1: Auto-Login dari Change Account (Switch Account)
    if (widget.autoLoginUsername != null) {
      usernameController.text = widget.autoLoginUsername!;
      showPopupMessage("Account Switch",
          details: "Please re-enter the password for ${widget.autoLoginUsername} to continue the session.");
      setState(() => loading = false);
      return;
    }

    // Senario 2: Auto-Login Biasa (App Restart)
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final String? savedUserId = prefs.getString('savedUserId'); // Kita bergantung pada ID, bukan Username

    if (isLoggedIn && savedUserId != null) {
      if (!await _isNetworkAvailable()) {
        // Jika tiada internet, terpaksa guna cached username lama (jika ada)
        final savedUsername = prefs.getString('savedUsername');
        final savedRole = prefs.getString('savedRole');
        if (savedUsername != null && savedRole != null) {
          _navigateToHomePage(savedUsername, savedRole, savedUserId);
        } else {
          showPopupMessage("Offline Mode", details: "Please connect to internet to sign in.");
        }
        return;
      }

      setState(() => loading = true);

      try {
        // [PENYELESAIAN] Tarik data terkini dari Firestore menggunakan User ID
        // Ini memastikan kita dapat username BARU jika ia telah ditukar
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(savedUserId)
            .get();

        if (userDoc.exists && _auth.currentUser != null && _auth.currentUser!.uid == savedUserId) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

          String freshUsername = userData['username']; // Username terkini dari DB
          String freshRole = userData['role'];         // Role terkini dari DB
          String status = userData['status'] ?? 'Active';

          if (status != 'Active') {
            await LoginPage.clearLoginState();
            showPopupMessage("Account Disabled", details: "Your account has been disabled.");
            setState(() => loading = false);
            return;
          }

          // Update SharedPreferences dengan data terkini supaya sync
          await prefs.setString('savedUsername', freshUsername);
          await prefs.setString('savedRole', freshRole);

          // Masuk ke Home Page dengan Username yang betul
          _navigateToHomePage(freshUsername, freshRole, savedUserId);

        } else {
          // Jika user dah kena delete kat database atau token expired
          await LoginPage.clearLoginState();
          setState(() => loading = false);
        }
      } catch (e) {
        // Jika ada error (contoh: network error masa fetch)
        setState(() => loading = false);
        print("Auto login error: $e");
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
          context, MaterialPageRoute(builder: (_) => ManagerPage(loggedInUsername: username, userId: userId,))
      );
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => StaffPage(loggedInUsername: username, userId: userId)));
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

  Future<bool> _isNetworkAvailable() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  // --- LOG MASUK MANUAL ---
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

    if (!await _isNetworkAvailable()) {
      showPopupMessage("Offline Mode", details: "You need an active internet connection to sign in.");
      return;
    }

    setState(() => loading = true);

    try {
      // 1. Cari User
      QuerySnapshot userSnap;
      if (input.contains('@')) {
        userSnap = await FirebaseFirestore.instance.collection("users").where('email', isEqualTo: input).limit(1).get();
      } else {
        userSnap = await FirebaseFirestore.instance.collection("users").where('username', isEqualTo: input).limit(1).get();
      }

      if (userSnap.docs.isNotEmpty) {
        userData = userSnap.docs.first.data() as Map<String, dynamic>;
        emailToAuthenticate = userData['email'];
        // Pastikan kita ambil username dari database, bukan dari input user semata-mata
        usernameForNavigation = userData['username'] ?? userData['email'];
        firestoreDocId = userSnap.docs.first.id;

        if (userData["status"] != "Active") {
          showPopupMessage("Account Disabled", details: "Contact Administrator.");
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

      // 2. Authenticate Firebase Auth
      await _auth.signInWithEmailAndPassword(email: emailToAuthenticate, password: password);

      // 3. Double Check (Jika step 1 skip sebab input adalah email terus)
      if (userData == null) {
        userSnap = await FirebaseFirestore.instance.collection("users").where('email', isEqualTo: emailToAuthenticate).limit(1).get();
        if (userSnap.docs.isNotEmpty) {
          userData = userSnap.docs.first.data() as Map<String, dynamic>;
          usernameForNavigation = userData['username'];
          firestoreDocId = userSnap.docs.first.id;
        }
      }

      String role = userData?["role"] ?? 'staff';

      // 4. Simpan Session
      if (rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        // Penting: Simpan username yang betul dari Database
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
        errorMessage = "Invalid email format.";
      }
      showPopupMessage("Authentication Failed", details: errorMessage);
    } catch (e) {
      showPopupMessage("System Error", details: e.toString());
    } finally {
      if(mounted) setState(() => loading = false);
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
                          Checkbox(
                            value: rememberMe,
                            onChanged: (v) => setState(() => rememberMe = v!),
                          ),
                          const Text("Remember me"),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage()));
                        },
                        child: const Text("Forgot password?"),
                      )
                    ],
                  ),
                  SizedBox(height: constraints.maxHeight * 0.03),

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