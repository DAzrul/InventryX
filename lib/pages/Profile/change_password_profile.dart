import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Import path ni pastikan betul mat
import '../../../pages/forgot_password_page.dart';

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

  // --- UI HELPER: TEXTFIELD ---
  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[700]),
      ),
    );
  }

  Widget _buildPasswordField({required TextEditingController controller, required String hint, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: !showAllPasswords,
        style: const TextStyle(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(icon, color: primaryBlue, size: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text("Security", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
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
            // --- HEADER TEXT ---
            const Text("Change Password", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              "Your new password must be different from previous used passwords.",
              style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 35),

            // --- OLD PASSWORD ---
            _buildInputLabel("Current Password"),
            _buildPasswordField(
              controller: oldPasswordController,
              hint: "Enter current password",
              icon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 25),

            // --- NEW PASSWORD ---
            _buildInputLabel("New Password (Min 6 chars)"),
            _buildPasswordField(
              controller: newPasswordController,
              hint: "Enter new password",
              icon: Icons.lock_reset_rounded,
            ),
            const SizedBox(height: 20),

            // --- CONFIRM PASSWORD ---
            _buildInputLabel("Confirm New Password"),
            _buildPasswordField(
              controller: confirmPasswordController,
              hint: "Re-type new password",
              icon: Icons.verified_user_outlined,
            ),

            // --- SHOW PASSWORD CHECKBOX ---
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text("Show characters", style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
                Transform.scale(
                  scale: 0.9,
                  child: Checkbox(
                    value: showAllPasswords,
                    activeColor: primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) => setState(() => showAllPasswords = val!),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // --- ACTION BUTTON ---
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
                    : const Text("Update Password", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 20),

            // --- FORGOT PASSWORD LINK ---
            Center(
              child: TextButton(
                onPressed: _forgotPassword,
                child: Text(
                  "Forgot Password?",
                  style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- LOGIC FUNCTIONS (Kekal mantap macam asal mat) ---

  Future<void> _changePassword() async {
    final oldPass = oldPasswordController.text.trim();
    final newPass = newPasswordController.text.trim();
    final confirmPass = confirmPasswordController.text.trim();

    if (currentUser == null) {
      _showSnackBar("Session expired. Please login again.", Colors.red);
      return;
    }

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _showSnackBar("Please fill all fields", Colors.orange);
      return;
    }
    if (newPass != confirmPass) {
      _showSnackBar("New passwords don't match", Colors.red);
      return;
    }
    if (newPass.length < 6) {
      _showSnackBar("Password too short (Min 6)", Colors.red);
      return;
    }

    setState(() => loading = true);
    try {
      // 1. Re-authenticate user mat (Wajib dlm Firebase kalau nak tukar password)
      AuthCredential credential = EmailAuthProvider.credential(
          email: currentUser!.email!,
          password: oldPass
      );
      await currentUser!.reauthenticateWithCredential(credential);

      // 2. Update password dlm Firebase Auth
      await currentUser!.updatePassword(newPass);

      // 3. SIMPAN AKTIVITI DLM FIRESTORE (Wajib sebelum pop!)
      // Aku guna widget.userId supaya tally dengan doc ID dlm users collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('activities')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Successfully changed account password.',
        'iconCode': Icons.key_rounded.codePoint, // Icon kunci yang Pro
      });

      if (mounted) {
        _showSnackBar("Password updated successfully!", Colors.green);
        // Kita tunggu jap supaya user nampak snackbar hijau tu baru tutup modal
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context, 'success');
        });
      }

    } on FirebaseAuthException catch (e) {
      String errorMsg = "Failed to update password.";
      if (e.code == 'wrong-password') errorMsg = "Current password is incorrect.";
      _showSnackBar(errorMsg, Colors.red);
    } catch (e) {
      _showSnackBar("An error occurred. Try again.", Colors.red);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _forgotPassword() {
    Navigator.pop(context, null);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage()));
  }
}