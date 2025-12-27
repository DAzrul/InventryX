import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../user_list_page.dart';

class UserManagementPage extends StatefulWidget {
  final String username;

  const UserManagementPage({super.key, required this.username});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneNoController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? selectedRole;
  String? selectedDefaultPassword;
  bool loading = false;
  String? adminProfilePictureUrl;

  final List<String> roles = ['admin', 'manager', 'staff'];
  final List<String> defaultPasswords = ['adminpassword', 'password123', 'DefaultPass'];

  @override
  void initState() {
    super.initState();
    _loadAdminProfilePicture();
  }

  Future<void> _loadAdminProfilePicture() async {
    try {
      QuerySnapshot adminSnap = await FirebaseFirestore.instance
          .collection("users")
          .where("username", isEqualTo: widget.username)
          .limit(1)
          .get();

      if (adminSnap.docs.isNotEmpty) {
        var userData = adminSnap.docs.first.data() as Map<String, dynamic>;
        setState(() {
          adminProfilePictureUrl = userData['profilePictureUrl'];
        });
      }
    } catch (e) {
      debugPrint("Error loading admin profile: $e");
    }
  }

  void showPopupMessage(String title, {String? message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: message != null ? Text(message) : null,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }

  Future<bool> _isNetworkAvailable() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> registerUser() async {
    String email = emailController.text.trim();
    String name = nameController.text.trim();
    String phoneNo = phoneNoController.text.trim();
    String role = selectedRole ?? '';
    String password = selectedDefaultPassword ?? '';

    if (role.isEmpty || email.isEmpty || name.isEmpty || phoneNo.isEmpty || password.isEmpty) {
      showPopupMessage("Missing Info", message: "Fill in all fields to register the new user.");
      return;
    }

    if (!await _isNetworkAvailable()) {
      showPopupMessage("Offline Mode", message: "Internet connection is required for cloud registration.");
      return;
    }

    setState(() => loading = true);
    try {
      String username = email.split('@')[0];

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String userUid = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection("users").doc(userUid).set({
        "username": username,
        "email": email,
        "name": name,
        "phoneNo": phoneNo,
        "role": role,
        "status": "Active",
        "registeredBy": widget.username,
        "createdAt": FieldValue.serverTimestamp(),
        "profilePictureUrl": "",
      });

      if (!mounted) return;
      showPopupMessage("Success", message: "User $name (ID: $username) registered successfully.");

      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => UserListPage(loggedInUsername: widget.username))
      );
    } catch (e) {
      showPopupMessage("Registration Failed", message: e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF233E99);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Register User", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER INFO ---
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: (adminProfilePictureUrl != null) ? CachedNetworkImageProvider(adminProfilePictureUrl!) : null,
                    child: adminProfilePictureUrl == null ? const Icon(Icons.person) : null,
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Authorized Admin", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text(widget.username, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            const Text("User Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),

            // --- INPUT FIELDS ---
            _buildDropdown(hint: "Choose User Role", value: selectedRole, items: roles, icon: Icons.admin_panel_settings_rounded, onChanged: (v) => setState(() => selectedRole = v)),
            const SizedBox(height: 15),
            _buildTextField(controller: emailController, hint: "Email Address", icon: Icons.email_rounded, type: TextInputType.emailAddress),
            const SizedBox(height: 15),
            _buildTextField(controller: nameController, hint: "Full Name", icon: Icons.person_rounded),
            const SizedBox(height: 15),
            _buildTextField(controller: phoneNoController, hint: "Phone Number", icon: Icons.phone_rounded, type: TextInputType.phone),
            const SizedBox(height: 15),
            _buildDropdown(hint: "Default Password", value: selectedDefaultPassword, items: defaultPasswords, icon: Icons.lock_rounded, isPassword: true, onChanged: (v) => setState(() => selectedDefaultPassword = v)),

            const SizedBox(height: 40),

            // --- REGISTER BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  shadowColor: primaryBlue.withOpacity(0.4),
                ),
                onPressed: loading ? null : registerUser,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Create New User", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildTextField({required TextEditingController controller, required String hint, required IconData icon, TextInputType type = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
          prefixIcon: Icon(icon, color: const Color(0xFF233E99), size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildDropdown({required String hint, required String? value, required List<String> items, required IconData icon, bool isPassword = false, required Function(String?) onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items.map((s) => DropdownMenuItem(value: s, child: Text(isPassword ? "Set: $s" : s.toUpperCase(), style: const TextStyle(fontSize: 14)))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF233E99), size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        ),
      ),
    );
  }
}