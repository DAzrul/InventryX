import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// [NOTE] Ensure this path is correct based on your folder structure mat!
import '../forgot_password_page.dart';

class ChangePasswordProfilePage extends StatefulWidget {
  final String username;
  final String userId;

  const ChangePasswordProfilePage({
    super.key,
    required this.username,
    required this.userId,
  });

  @override
  State<ChangePasswordProfilePage> createState() => _ChangePasswordProfilePageState();
}

class _ChangePasswordProfilePageState extends State<ChangePasswordProfilePage> {
  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool loading = false;
  bool showAllPasswords = false;
  User? currentUser;

  final Color primaryBlue = const Color(0xFF233E99);

  @override
  void initState() {
    super.initState();
    currentUser = _auth.currentUser;
  }

  @override
  void dispose() {
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // --- LOGIC: UPDATE PASSWORD ---
  Future<void> _changePassword() async {
    final oldPass = oldPasswordController.text.trim();
    final newPass = newPasswordController.text.trim(); // No lowercase mat! Case-sensitive is better for security.
    final confirmPass = confirmPasswordController.text.trim();

    if (currentUser == null) {
      _showSnackBar("Session expired. Please log in again.", Colors.red);
      return;
    }

    // 1. Basic Validation
    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _showSnackBar("Please fill in all fields.", Colors.orange);
      return;
    }

    // 2. Anti-Trash Password Logic
    if (newPass == "123456" || newPass == "password" || newPass == "12345678") {
      _showSnackBar("This password is too weak and easy to guess!", Colors.red);
      return;
    }

    // 3. New Password check
    if (oldPass == newPass) {
      _showSnackBar("New password cannot be the same as current password.", Colors.red);
      return;
    }

    if (newPass != confirmPass) {
      _showSnackBar("New passwords do not match.", Colors.red);
      return;
    }

    if (newPass.length < 6) {
      _showSnackBar("Password must be at least 6 characters long.", Colors.red);
      return;
    }

    // 4. Complexity Check (Pro Touch)
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(newPass);
    final hasDigit = RegExp(r'[0-9]').hasMatch(newPass);
    if (!hasLetter || !hasDigit) {
      _showSnackBar("Password must contain both letters and numbers.", Colors.red);
      return;
    }

    setState(() => loading = true);

    try {
      // 5. Re-authentication (Required for sensitive actions)
      AuthCredential credential = EmailAuthProvider.credential(
          email: currentUser!.email!,
          password: oldPass
      );
      await currentUser!.reauthenticateWithCredential(credential);

      // 6. Update in Firebase Auth
      await currentUser!.updatePassword(newPass);

      // 7. Record Activity in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('activities')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Security update: User changed account password.',
        'iconCode': Icons.lock_person_rounded.codePoint,
        'action': 'Security Update',
      });

      if (mounted) {
        _showSnackBar("Password updated successfully!", Colors.green);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context, 'success');
        });
      }

    } on FirebaseAuthException catch (e) {
      String errorMsg = "Update failed. Please try again.";
      if (e.code == 'wrong-password') errorMsg = "Current password is incorrect.";
      if (e.code == 'requires-recent-login') errorMsg = "Please log out and log in again for security.";
      _showSnackBar(errorMsg, Colors.red);
    } catch (e) {
      _showSnackBar("An error occurred: $e", Colors.red);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        )
    );
  }

  void _forgotPassword() {
    Navigator.pop(context, null);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage()));
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text("Security Settings", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Change Password", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              "Strengthen your account security by updating your password regularly.",
              style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 35),

            _buildInputLabel("Current Password"),
            _buildPasswordField(controller: oldPasswordController, hint: "Enter existing password", icon: Icons.lock_outline_rounded),
            const SizedBox(height: 25),

            _buildInputLabel("New Password"),
            _buildPasswordField(controller: newPasswordController, hint: "Enter new secure password", icon: Icons.lock_reset_rounded),
            const SizedBox(height: 20),

            _buildInputLabel("Confirm New Password"),
            _buildPasswordField(controller: confirmPasswordController, hint: "Re-type new password", icon: Icons.verified_user_outlined),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text("Show characters", style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
                Checkbox(
                  value: showAllPasswords,
                  activeColor: primaryBlue,
                  onChanged: (val) => setState(() => showAllPasswords = val!),
                ),
              ],
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                  shadowColor: primaryBlue.withValues(alpha: 0.4),
                ),
                onPressed: loading ? null : _changePassword,
                child: loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("UPDATE PASSWORD", style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              ),
            ),

            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: _forgotPassword,
                child: Text("Forgot Password?", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w900, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey[700])),
    );
  }

  Widget _buildPasswordField({required TextEditingController controller, required String hint, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        obscureText: !showAllPasswords,
        style: const TextStyle(fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(icon, color: primaryBlue, size: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}