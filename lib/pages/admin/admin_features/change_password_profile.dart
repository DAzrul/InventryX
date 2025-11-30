// change_password_profile.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  // [DIUBAH] Hanya satu state untuk mengawal semua visibiliti
  bool showAllPasswords = false;

  User? currentUser;

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

  void _showPopupMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }

  // --- Fungsi Update Kata Laluan DENGAN FIREBASE AUTH ---
  Future<void> _changePassword() async {
    final oldPassword = oldPasswordController.text.trim();
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (currentUser == null) {
      _showPopupMessage("Error", "User not logged in or session expired.");
      return;
    }
    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showPopupMessage("Validation Error", "Please fill all fields.");
      return;
    }
    if (newPassword != confirmPassword) {
      _showPopupMessage("Validation Error", "New password and confirmation do not match.");
      return;
    }
    if (newPassword.length < 6) {
      _showPopupMessage("Validation Error", "New password must be at least 6 characters.");
      return;
    }

    setState(() => loading = true);

    try {
      // 1. Cipta kelayakan (credential)
      AuthCredential credential = EmailAuthProvider.credential(
        email: currentUser!.email!,
        password: oldPassword,
      );

      // 2. Sahkan semula pengguna
      await currentUser!.reauthenticateWithCredential(credential);

      // 3. Kemas kini kata laluan baharu
      await currentUser!.updatePassword(newPassword);

      // 4. [BARU] REKOD AKTIVITI KE FIRESTORE
      await FirebaseFirestore.instance
          .collection('users').doc(currentUser!.uid)
          .collection('activities').add({
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Successfully changed account password.',
        'iconCode': Icons.key_outlined.codePoint,
      });

      // 5. Jika berjaya
      Navigator.pop(context, 'success');

    } on FirebaseAuthException catch (e) {
      // ... (Error handling remains the same) ...
      Navigator.pop(context, 'fail');

    } catch (e) {
      Navigator.pop(context, 'fail');
    } finally {
      if(mounted) {
        setState(() => loading = false);
      }
    }
  }

  // --- Fungsi Navigasi Forgot Password ---
  void _forgotPassword() {
    if (currentUser?.email == null) {
      _showPopupMessage("Error", "Unable to find user email for reset.");
      return;
    }

    // Tutup modal Change Password dahulu
    Navigator.pop(context, null);

    // Navigasi ke halaman Forgot Password
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
    );
  }

  // Widget Pembantu untuk Input Password (Kini tanpa ikon mata)
  Widget _buildPasswordField({required TextEditingController controller, required String hint}) {
    return TextField(
      controller: controller,
      // [DIUBAH] obscuredText kini bergantung pada state umum showAllPasswords
      obscureText: !showAllPasswords,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_open_outlined, color: Colors.grey),
        // [DIHAPUSKAN] suffixIcon untuk ikon mata
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Change Password", style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Old Password
              const Text("Old Password", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: oldPasswordController,
                // [DIUBAH] obscuredText kini bergantung pada state umum showAllPasswords
                obscureText: !showAllPasswords,
                decoration: InputDecoration(
                  hintText: "Enter your current password",
                  prefixIcon: const Icon(Icons.lock_open_outlined, color: Colors.grey),
                  // [DIHAPUSKAN] suffixIcon untuk ikon mata lama
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 25),

              // New Password
              const Text("New Password (Min 6 chars)", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              _buildPasswordField(
                controller: newPasswordController,
                hint: "New Password",
              ),
              const SizedBox(height: 15),

              // Confirm Password
              const Text("Confirm Password", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              _buildPasswordField(
                controller: confirmPasswordController,
                hint: "Confirm password",
              ),
              const SizedBox(height: 15), // Kurangkan ruang di sini

              // --- CHECKBOX SHOW PASSWORD (BARU) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text("Show Passwords", style: TextStyle(fontSize: 14)),
                  Checkbox(
                    value: showAllPasswords,
                    onChanged: (newValue) {
                      setState(() {
                        showAllPasswords = newValue!;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20), // Tambah ruang sebelum butang

              // Change Password Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: loading ? null : _changePassword,
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  label: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Change Password", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 15),

              // Forgot Password Link
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: const Text("Forgot password?", style: TextStyle(color: Color(0xFF233E99))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}