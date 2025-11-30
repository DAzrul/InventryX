import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import kekal untuk konteks Auth

class UserDeletePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String userId; // UID Firebase Auth
  final String loggedInUsername;

  const UserDeletePage({
    super.key,
    required this.userData,
    required this.userId,
    required this.loggedInUsername,
  });

  @override
  State<UserDeletePage> createState() => _UserDeletePageState();
}

class _UserDeletePageState extends State<UserDeletePage> {
  // Controllers (Dikekalkan)
  late TextEditingController emailController;
  late TextEditingController nameController;
  late TextEditingController phoneNoController;
  late TextEditingController passwordController;

  late bool isActive;
  late String selectedRole;

  bool loading = false;
  final List<String> roles = ['admin', 'manager', 'staff'];

  @override
  void initState() {
    super.initState();
    isActive = widget.userData['status'] == 'Active';
    selectedRole = widget.userData['role'] ?? 'staff';

    emailController = TextEditingController(text: widget.userData['email'] ?? '');
    nameController = TextEditingController(text: widget.userData['name'] ?? '');
    phoneNoController = TextEditingController(text: widget.userData['phoneNo'] ?? '');
    passwordController = TextEditingController(text: '1234password');
  }

  // --- Fungsi Popup Message ---
  Future<void> _showPopupMessage(String title, String message) async {
    return await showDialog(
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

  // --- Fungsi Toggle Status (Kemas kini Firestore sahaja) ---
  Future<void> _toggleUserStatus(bool activate) async {
    if (!mounted) return;
    setState(() => loading = true);

    String statusString = activate ? 'Active' : 'Disable';

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'status': statusString});

      if (mounted) {
        await _showPopupMessage("Success", "Status updated to $statusString.");
        Navigator.pop(context, true); // Pop dengan true untuk refresh
      }

    } catch (e) {
      if (mounted) {
        _showPopupMessage("Error", "Failed to update status: ${e.toString()}");
        setState(() => loading = false);
      }
    }
  }

  // --- Fungsi Padam Akaun (FIREBASE AUTH & FIRESTORE) ---
  Future<void> _deleteAccount() async {
    if (!mounted) return;
    setState(() => loading = true);

    try {
      // 1. PADAM DARI FIRESTORE
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .delete();

      // 2. AMARAN PENTING TENTANG AUTHENTICATION
      if (mounted) {
        await _showPopupMessage("Success (Partial)",
            "User data successfully deleted from Firestore. \n\n⚠️ ACTION REQUIRED: Please manually delete this user's account from the Firebase Authentication Console using their email: ${widget.userData['email'] ?? 'N/A'}");

        Navigator.pop(context, true); // Pop dengan true untuk refresh
      }

    } catch (e) {
      if (mounted) {
        _showPopupMessage("Error", "Failed to delete account: ${e.toString()}");
        setState(() => loading = false);
      }
    }
  }

  // --- Fungsi Pengesahan sebelum Padam ---
  void _confirmAndDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion ⚠️"),
        content: Text("Are you sure you want to permanently delete the account for ${widget.userData['username']}? This action cannot be undone. \n\n(Remember to manually delete the user from Firebase Authentication.)"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Tutup dialog
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Tutup dialog
              _deleteAccount(); // Teruskan dengan pemadaman
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete Permanently", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  // --- Widget Pembantu (Decoration & Status Tag) ---
  InputDecoration _inputDecoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 20, color: Colors.grey[600]) : null,
      filled: true,
      fillColor: Colors.grey[100],
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blue)),
    );
  }

  InputDecoration _dropdownDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    );
  }

  // Widget Tag Status Statik KECIL
  Widget _buildStatusDisplayTag({required String status, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    String currentStatus = isActive ? 'Active' : 'Disable';
    Color toggleActionColor = isActive ? Colors.red[500]! : Colors.green[500]!;
    Color statusTextColor = isActive ? Colors.green[600]! : Colors.red[600]!;
    String toggleActionLabel = isActive ? 'Disable' : 'Activate';


    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("User Management", style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER & STATUS ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(radius: 24, backgroundImage: AssetImage('assets/profile.png')),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.userData['username'] ?? 'Username',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.userData['role'] ?? 'Staff',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
                const Spacer(),
              ],
            ),

            const SizedBox(height: 10),

            // --- STATUS DISPLAY & TOMBOL AJKSI ---
            Row(
              children: [
                // 1. TOMBOL AKSI SEMASA (BESAR, BERWARNA) - Mengubah Status
                ElevatedButton(
                  onPressed: loading ? null : () => _toggleUserStatus(!isActive), // Toggle ke status berlawanan
                  style: ElevatedButton.styleFrom(
                      backgroundColor: toggleActionColor,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      minimumSize: const Size(100, 35)
                  ),
                  child: loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                    toggleActionLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),

                // 2. TAG STATUS STATIK KECIL (STATUS SEMASA)
                _buildStatusDisplayTag(status: currentStatus, textColor: statusTextColor),
              ],
            ),

            const Divider(height: 30),

            // Email (Hanya Paparan)
            const Text("Email", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(controller: emailController, readOnly: true, keyboardType: TextInputType.emailAddress, decoration: _inputDecoration("Username@gmail.com", Icons.email_outlined)),
            const SizedBox(height: 15),

            // Name (Hanya Paparan)
            const Text("Name", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(controller: nameController, readOnly: true, decoration: _inputDecoration("Username", Icons.person_outline)),
            const SizedBox(height: 15),

            // Phone Number (Hanya Paparan)
            const Text("Phone Number", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(controller: phoneNoController, readOnly: true, keyboardType: TextInputType.phone, decoration: _inputDecoration("0123456789", Icons.phone_outlined)),
            const SizedBox(height: 30),

            // Change Password (Hanya Paparan, menunjukkan placeholder)
            const Text("Password (Cannot be viewed)", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              readOnly: true, // Tidak membenarkan input
              obscureText: true,
              decoration: _inputDecoration("********", Icons.lock_outline),
            ),
            const SizedBox(height: 15),

            // Change Role (Dropdown Paparan)
            const Text("Role", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: _dropdownDecoration("Choose Role"),
              value: selectedRole,
              items: roles.map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase()));
              }).toList(),
              onChanged: null, // Disabled kerana ini hanya halaman Delete/View
              disabledHint: Text(selectedRole.toUpperCase()),
              isDense: true,
              isExpanded: true,
            ),

            const SizedBox(height: 30),

            // --- DELETE ACCOUNT BUTTON ---

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}