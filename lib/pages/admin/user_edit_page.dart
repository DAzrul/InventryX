import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Pastikan path widget ni betul ikut folder kau
import 'widgets/user_header_status.dart';
import 'widgets/user_info_fields.dart';

class UserEditPage extends StatefulWidget {
  final String userId;
  final String loggedInUsername;

  const UserEditPage({
    super.key,
    required this.userId,
    required this.loggedInUsername, required username, required Map<String, dynamic> userData,
  });

  @override
  State<UserEditPage> createState() => _UserEditPageState();
}

class _UserEditPageState extends State<UserEditPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();

  String _currentStatus = 'Active';
  String? _profilePictureUrl;
  bool _isLoading = true;
  String _displayName = 'Loading...';

  final Color primaryBlue = const Color(0xFF233E99);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      if (doc.exists && mounted) {
        var data = doc.data() as Map<String, dynamic>;
        setState(() {
          _emailController.text = data['email'] ?? '';
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phoneNo'] ?? '';
          _positionController.text = data['position'] ?? '';
          _roleController.text = data['role'] ?? '';
          _displayName = data['username'] ?? 'User';
          _currentStatus = data['status'] ?? 'Active';
          _profilePictureUrl = data['profilePictureUrl'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC: SAVE CHANGES (Profile Update Biasa) ---
  void _saveChanges() async {
    if (_isLoading) return;

    if (!await _isNetworkAvailable()) {
      _showStyledSnackBar("No internet connection.", isError: true);
      return;
    }

    if (_nameController.text.isEmpty || _roleController.text.isEmpty) {
      _showStyledSnackBar("Name and Role cannot be empty!", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'name': _nameController.text.trim(),
        'phoneNo': _phoneController.text.trim(),
        'position': _positionController.text.trim(),
        'status': _currentStatus,
        'role': _roleController.text.trim().toLowerCase(),
      });

      if (!mounted) return;
      _showSuccessDialog(); // Ini dialog, user tekan OK baru keluar

    } catch (e) {
      _showStyledSnackBar("Update failed: $e", isError: true);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- [UPDATED LOGIC] ADMIN RESET PASSWORD + AUTO BACK ---
  Future<void> _sendPasswordResetEmail() async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      _showStyledSnackBar("User email is missing/invalid.", isError: true);
      return;
    }

    // 1. Confirmation Dialog
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset User Password?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Send a password reset email to $email?\n\nThe user will receive a link to create a new password securely."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey))
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Send Email", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      // 2. Firebase Send Email
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      // 3. Save Log Activity
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('activities')
          .add({
        'action': 'Admin Reset Password',
        'description': 'Admin sent a password reset email link.',
        'timestamp': FieldValue.serverTimestamp(),
        'iconCode': Icons.lock_reset_rounded.codePoint,
        'performedBy': widget.loggedInUsername,
      });

      // 4. Show Snackbar Success
      _showStyledSnackBar("Reset link sent successfully to $email");

      // 5. [AUTO BACK LOGIC] Tunggu 1.5 saat, lepas tu balik ke User List
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        Navigator.pop(context); // Balik ke UserListPage
      }

    } on FirebaseAuthException catch (e) {
      String err = e.message ?? "Failed to send email.";
      if (e.code == 'user-not-found') err = "This email is not registered in Auth.";
      _showStyledSnackBar(err, isError: true);
      if (mounted) setState(() => _isLoading = false); // Stop loading kalau error
    } catch (e) {
      _showStyledSnackBar("System Error: $e", isError: true);
      if (mounted) setState(() => _isLoading = false);
    }
    // Nota: Kalau success, kita tak perlu set isLoading false sbb kita dah pop page
  }

  // --- WIDGET SNACKBAR PREMIUM ---
  void _showStyledSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isError ? "Error" : "Success",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(20),
        elevation: 10,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- DIALOG SUCCESS PREMIUM ---
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.green, size: 50),
              ),
              const SizedBox(height: 20),
              const Text("Changes Saved!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              const Text("User profile has been updated successfully.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Tutup dialog
                    Navigator.pop(context); // Balik ke list user
                  },
                  child: const Text("Awesome!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _isNetworkAvailable() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Account', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          children: [
            // HEADER & STATUS CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)],
              ),
              child: UserHeaderStatus(
                username: _displayName,
                role: _roleController.text,
                currentStatus: _currentStatus,
                profilePictureUrl: _profilePictureUrl,
                onStatusChange: (v) => setState(() => _currentStatus = v),
                isLoading: _isLoading,
              ),
            ),

            const SizedBox(height: 30),

            // USER INFO FIELDS
            UserInfoFields(
              emailController: _emailController,
              nameController: _nameController,
              phoneController: _phoneController,
              positionController: _positionController,
              roleController: _roleController,
              isReadOnly: false,
            ),

            const SizedBox(height: 40),

            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 8,
                  shadowColor: primaryBlue.withOpacity(0.3),
                ),
                child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),

            const SizedBox(height: 20),

            // RESET PASSWORD BUTTON
            SizedBox(
              width: double.infinity,
              height: 60,
              child: TextButton.icon(
                onPressed: _sendPasswordResetEmail,
                icon: const Icon(Icons.lock_reset_rounded, color: Colors.red),
                label: const Text('Send Password Reset Email', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.red)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}