import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

  final Color primaryBlue = const Color(0xFF233E99);
  final Color bgSecondary = const Color(0xFFF8FAFF);

  // --- POPUP MESSAGE ---
  void _showPopup(String title, String message, {bool isSuccess = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
            title,
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isSuccess ? Colors.green : Colors.black
            )
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Tutup dialog
              if (isSuccess && mounted) {
                // Jika berjaya, bawa user balik ke Login Page
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
            child: Text("Got it", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // --- CHECK INTERNET ---
  Future<bool> _isNetworkAvailable() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  // --- LOGIC HANTAR LINK ---
  void sendResetLink() async {
    String input = emailController.text.trim();

    // 1. Validasi Input Kosong
    if (input.isEmpty) {
      _showPopup("Oops!", "Please enter your username or email address.");
      return;
    }

    // 2. Semak Internet
    if (!await _isNetworkAvailable()) {
      _showPopup("No Internet", "Please check your internet connection and try again.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      String targetEmail = input;

      // 3. Logic Username vs Email
      // Jika input TIADA simbol '@', kita anggap ia adalah Username
      if (!input.contains("@")) {

        // Cari email berdasarkan username dalam Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection("users")
            .where("username", isEqualTo: input) // Pastikan input sama sebiji (case-sensitive)
            .limit(1)
            .get();

        if (userDoc.docs.isEmpty) {
          _showPopup("Not Found", "Username '$input' not found in our system.");
          setState(() => _isLoading = false);
          return;
        }

        // Ambil email sebenar dari database
        targetEmail = userDoc.docs.first['email'];
      }

      // 4. Hantar Link Reset ke Email
      await _auth.sendPasswordResetEmail(email: targetEmail);

      // Paparkan mesej kejayaan (Masking email sikit utk nampak pro)
      _showPopup("Check Your Email", "Recovery link has been sent to $targetEmail", isSuccess: true);

    } on FirebaseAuthException catch (e) {
      // Handle error rasmi Firebase
      String errMessage = "An error occurred.";
      if (e.code == 'user-not-found') errMessage = "No registered user found with this email.";
      if (e.code == 'invalid-email') errMessage = "The email format is invalid.";

      _showPopup("Error", errMessage);
    } catch (e) {
      // Handle error lain
      _showPopup("System Error", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    height: 120,
                    margin: const EdgeInsets.only(bottom: 40),
                    child: Image.asset("assets/logo.png", fit: BoxFit.contain), // Pastikan logo wujud
                  ),
                ),
                const Text("Reset Password", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 10),
                // [UPDATED LABEL]
                Text("Enter your username or email address to receive a recovery link.",
                    style: TextStyle(fontSize: 15, color: Colors.grey[600], fontWeight: FontWeight.w500)),

                const SizedBox(height: 40),

                // [UPDATED FIELD]
                _buildModernField(emailController, "Username or Email", Icons.person_search_rounded),

                const SizedBox(height: 40),

                // Action Button
                _buildActionButton(),

                const SizedBox(height: 30),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())),
                    child: Text("Back to Sign In", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernField(TextEditingController controller, String label, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: const Color(0xFFF5F7FB), borderRadius: BorderRadius.circular(18)),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress, // Keyboard setting umum
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: primaryBlue, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              hintText: "Enter username / email",
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(colors: [primaryBlue, primaryBlue.withOpacity(0.85)]),
        boxShadow: [BoxShadow(color: primaryBlue.withOpacity(0.3), blurRadius: 25, offset: const Offset(0, 10))],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))
        ),
        onPressed: _isLoading ? null : sendResetLink,
        child: _isLoading
            ? const SizedBox(height: 25, width: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : const Text("SEND RESET LINK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
      ),
    );
  }
}