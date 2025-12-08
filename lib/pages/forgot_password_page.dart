import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Import untuk semakan rangkaian

import 'login_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  // --- FUNGSI POPUP MESSAGE (DIPERBAIKI) ---
  // Parameter pertama (message) adalah MESEJ/TAJUK yang akan dipaparkan
  void showPopupMessage(String message, {bool success = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Jika berjaya, kembali ke halaman login
              if (success && mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  // --- FUNGSI SEMAK RANGKAIAN ---
  Future<bool> _isNetworkAvailable() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  // --- Fungsi Hantar Pautan Reset Sebenar (DIPERBAIKI PANGGILAN) ---
  void sendResetLink() async {
    String email = emailController.text.trim();

    if (email.isEmpty) {
      // PANGGILAN BETUL: HANYA SATU PARAMETER POSITIONAL
      showPopupMessage("Please enter your email");
      return;
    }

    if (!email.contains("@") || !email.contains(".")) {
      showPopupMessage("Please enter a valid email");
      return;
    }

    // [LANGKAH 0: SEMAK RANGKAIAN]
    if (!await _isNetworkAvailable()) {
      showPopupMessage("Offline Mode: You must be online to request a password reset link.");
      return;
    }


    setState(() {
      _isLoading = true;
    });

    try {
      // Panggil Firebase Authentication untuk menghantar emel
      await _auth.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      // PANGGILAN BETUL
      showPopupMessage("A password reset link has been sent to $email. Please check your email.", success: true);

    } on FirebaseAuthException catch (e) {
      String errorMessage = "Failed to send link. Please check email or contact support..";

      if (e.code == 'user-not-found') {
        errorMessage = "Email is not registered. Please double check the address entered..";
      } else if (e.code == 'network-request-failed') {
        errorMessage = "Network connection failed. Please check your internet.";
      }

      if (!mounted) return;
      // PANGGILAN BETUL
      showPopupMessage(errorMessage);

    } catch (e) {
      if (!mounted) return;
      showPopupMessage("System Error: Failed to process request: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isPortrait = constraints.maxHeight > constraints.maxWidth;
          double horizontalPadding = constraints.maxWidth * 0.08;

          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children: [
                  SizedBox(
                    height: isPortrait
                        ? constraints.maxHeight * 0.2
                        : constraints.maxHeight * 0.35,
                    child: Image.asset("assets/logo.png", fit: BoxFit.contain),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.02),

                  Text(
                    "Forgot Password",
                    style: TextStyle(
                      fontSize: isPortrait
                          ? constraints.maxWidth * 0.07
                          : constraints.maxHeight * 0.06,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.005),

                  Text(
                    "Enter your email to receive a password reset link.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isPortrait
                          ? constraints.maxWidth * 0.04
                          : constraints.maxHeight * 0.035,
                      color: Colors.grey[600],
                    ),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.03),

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.03),

                  SizedBox(
                    width: double.infinity,
                    height: constraints.maxHeight * 0.07,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF233E99),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isLoading ? null : sendResetLink,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                        "Send Link",
                        style: TextStyle(
                          fontSize: isPortrait
                              ? constraints.maxWidth * 0.05
                              : constraints.maxHeight * 0.04,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.02),

                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: const Text(
                      "Back to Sign In",
                      style: TextStyle(
                        color: Color(0xFF233E99),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}