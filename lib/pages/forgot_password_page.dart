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

  // --- POPUP MESSAGE (MODERNIZED) ---
  void _showPopup(String title, String message, {bool isSuccess = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (isSuccess && mounted) {
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

  Future<bool> _isNetworkAvailable() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  void sendResetLink() async {
    String email = emailController.text.trim();

    if (email.isEmpty) {
      _showPopup("Oops!", "Please enter your email address first, mat!");
      return;
    }

    if (!email.contains("@") || !email.contains(".")) {
      _showPopup("Invalid Email", "That doesn't look like a real email. Try again.");
      return;
    }

    if (!await _isNetworkAvailable()) {
      _showPopup("No Connection", "Offline Mode: You must be online to request a password reset.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _showPopup("Link Sent!", "A password reset link has been sent to $email. Go check it out!", isSuccess: true);
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Failed to send link. Please check the email or contact support.";
      if (e.code == 'user-not-found') {
        errorMessage = "Email is not registered. Double check your address.";
      }
      _showPopup("Auth Error", errorMessage);
    } catch (e) {
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
                    child: Image.asset("assets/logo.png", fit: BoxFit.contain),
                  ),
                ),
                const Text("Reset Password", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 10),
                Text("Enter your email address to receive a recovery link.",
                    style: TextStyle(fontSize: 15, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                const SizedBox(height: 40),

                // Modern Email Field
                _buildModernField(emailController, "Email Address", Icons.alternate_email_rounded),

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
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: primaryBlue, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              hintText: "example@email.com",
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
        gradient: LinearGradient(colors: [primaryBlue, primaryBlue.withValues(alpha: 0.85)]),
        boxShadow: [BoxShadow(color: primaryBlue.withValues(alpha: 0.3), blurRadius: 25, offset: const Offset(0, 10))],
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