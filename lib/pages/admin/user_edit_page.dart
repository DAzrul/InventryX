import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Firebase Auth diimport hanya untuk rujukan UID, tiada operasi password klien dilakukan di sini
// import 'package:firebase_auth/firebase_auth.dart'; // Tidak diperlukan lagi dalam file ini

class UserEditPage extends StatefulWidget {
  final Map<String, dynamic> userData; // Data pengguna yang dipilih
  final String userId; // Document ID pengguna (UID Firebase Auth)
  final String loggedInUsername; // Username Admin sesi semasa

  const UserEditPage({
    super.key,
    required this.userData,
    required this.userId,
    required this.loggedInUsername
  });

  @override
  State<UserEditPage> createState() => _UserEditPageState();
}

class _UserEditPageState extends State<UserEditPage> {
  // Controllers
  late TextEditingController emailController;
  late TextEditingController nameController;
  late TextEditingController phoneNoController;
  late TextEditingController positionController;
  // [DIBUANG] passwordController, confirmPasswordController

  final List<String> availableRoles = ['admin', 'manager', 'staff'];
  String? selectedRole;

  late bool isActive;
  // [DIBUANG] showPassword
  bool loading = false;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(text: widget.userData['email'] ?? '');
    nameController = TextEditingController(text: widget.userData['name'] ?? '');
    phoneNoController = TextEditingController(text: widget.userData['phoneNo'] ?? '');
    positionController = TextEditingController(text: widget.userData['position'] ?? '');

    selectedRole = widget.userData['role'];

    // [DIBUANG] Inisialisasi controller password

    isActive = widget.userData['status'] == 'Active';
  }

  // FUNGSI POPUP MESSAGE
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


  // --- Fungsi Update Status (Active/Disable) ---
  Future<void> _toggleUserStatus() async {
    setState(() => loading = true);
    bool newStatus = !isActive;
    String statusString = newStatus ? 'Active' : 'Disable';

    try {
      // Hanya kemas kini status di Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'status': statusString});

      // Kemas kini state local
      setState(() {
        isActive = newStatus;
        loading = false;
      });
      await _showPopupMessage("Success", "Status updated to $statusString.");

      // Navigasi kembali selepas kemas kini status berjaya
      Navigator.pop(context, true); // Hantar 'true' untuk refresh

    } catch (e) {
      _showPopupMessage("Error", "Failed to update status: ${e.toString()}");
      setState(() => loading = false);
    }
  }

  // --- Fungsi Update Data Profil (Data Teks Sahaja) ---
  Future<void> _updateProfile() async {
    // [DIBUANG] Tiada validasi password

    setState(() => loading = true);
    Map<String, dynamic> updateData = {
      'email': emailController.text.trim(),
      'name': nameController.text.trim(),
      'phoneNo': phoneNoController.text.trim(),
      'position': positionController.text.trim(),
      'role': selectedRole, // Guna state Dropdown
    };

    try {
      // 1. Kemas kini data Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update(updateData);


      await _showPopupMessage("Success", "User profile updated successfully.");

      // Navigasi kembali selepas kemas kini profil
      Navigator.pop(context, true); // Hantar 'true' untuk refresh

    } catch (e) {
      _showPopupMessage("Error", "Failed to update profile: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }


  // Widget Tag Status Statik KECIL
  Widget _buildStatusDisplayTag({required String status, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey[200], // Latar belakang kelabu
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor, // Warna Hijau atau Merah
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // [DIBUANG] _passwordDecoration (Widget Pembantu password)

  @override
  Widget build(BuildContext context) {
    // Tombol Aksi yang akan mengubah status (Warna Penuh)
    String currentStatus = isActive ? 'Active' : 'Disable';
    Color currentStatusTextColor = isActive ? Colors.green[600]! : Colors.red[600]!;

    String toggleActionLabel = isActive ? 'Disable' : 'Activate';
    Color toggleActionColor = isActive ? Colors.red[600]! : Colors.green[600]!;


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
                // 1. TOMBOL AKSI SEMASA (Hijau/Merah Penuh) - Memanggil _toggleUserStatus
                ElevatedButton(
                  onPressed: loading ? null : _toggleUserStatus,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: toggleActionColor,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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

                // 2. STATUS DISPLAY STATIK KECIL (TAG STATUS SEMASA)
                _buildStatusDisplayTag(status: currentStatus, textColor: currentStatusTextColor),
              ],
            ),

            const Divider(height: 30),

            // Email
            const Text("Email", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: _inputDecoration("Username@gmail.com", Icons.email_outlined)),
            const SizedBox(height: 15),

            // Name
            const Text("Name", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(controller: nameController, decoration: _inputDecoration("Username", Icons.person_outline)),
            const SizedBox(height: 15),

            // Phone Number
            const Text("Phone Number", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(controller: phoneNoController, keyboardType: TextInputType.phone, decoration: _inputDecoration("0123456789", Icons.phone_outlined)),
            const SizedBox(height: 30),

            // Position
            const Text("Position", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(controller: positionController, decoration: _inputDecoration("Position/Jawatan", Icons.work_outline)),
            const SizedBox(height: 30),

            // Role (Dropdown)
            const Text("Role", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: _inputDecoration("Role/Akses", Icons.people_outline),
              value: selectedRole,
              items: availableRoles.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value.toUpperCase()),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() { selectedRole = newValue; });
              },
            ),
            const SizedBox(height: 30),

            // [DIBUANG] Change Password Section

            // --- UPDATE BUTTON ---

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // Widget Pembantu Decoration
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
}