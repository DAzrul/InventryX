import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// [PENTING] Pastikan import ini betul
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
  final TextEditingController usernameController = TextEditingController();

  bool loading = false;
  String? selectedRole;
  String? selectedDefaultPassword;

  final Color primaryBlue = const Color(0xFF233E99);
  final List<String> roles = ['admin', 'manager', 'staff'];
  final List<String> defaultPasswords = ['adminpassword', 'password123', 'DefaultPass'];

  // --- LOGIC 1: USERNAME VALIDATOR ---
  bool isValidUsername(String username) {
    // Hanya huruf kecil, nombor, titik dan underscore dibenarkan
    final RegExp usernameRegExp = RegExp(r'^[a-z0-9._]+$');
    return usernameRegExp.hasMatch(username);
  }

  // --- LOGIC 2: RESET FORM ---
  void _resetForm() {
    emailController.clear();
    nameController.clear();
    phoneNoController.clear();
    usernameController.clear();
    setState(() {
      selectedRole = null;
      selectedDefaultPassword = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Form cleared!"), duration: Duration(seconds: 1)),
    );
  }

  // --- LOGIC 3: REGISTER ---
  Future<void> registerUser() async {
    String email = emailController.text.trim();
    String name = nameController.text.trim();
    String phoneNo = phoneNoController.text.trim();

    // Ambil input username (mungkin kosong)
    String rawUsername = usernameController.text.trim().toLowerCase();

    String role = selectedRole ?? '';
    String password = selectedDefaultPassword ?? '';

    // A. Validation Check (Username & Phone TIDAK wajib di sini)
    if (role.isEmpty || email.isEmpty || name.isEmpty || password.isEmpty) {
      _showStyledSnackBar("Please fill in required fields (Email, Name, Role, Password).", isError: true);
      return;
    }

    // B. LOGIC AUTO-USERNAME DARI EMAIL
    String finalUsername = rawUsername;

    if (finalUsername.isEmpty) {
      // Kalau admin tak isi username, kita extract dari email
      if (email.contains('@')) {
        // Contoh: ali@gmail.com -> ali
        finalUsername = email.split('@')[0].toLowerCase();

        // Buang simbol pelik (selain huruf, nombor, titik, underscore)
        finalUsername = finalUsername.replaceAll(RegExp(r'[^a-z0-9._]'), '');
      }
    }

    // C. Validation Username (Lepas dah auto-generate)
    if (finalUsername.isEmpty) {
      _showStyledSnackBar("Could not generate username from email. Please enter manually.", isError: true);
      return;
    }

    if (!isValidUsername(finalUsername)) {
      _showStyledSnackBar("Username '$finalUsername' invalid! Use lowercase, numbers, dots only.", isError: true);
      return;
    }

    if (!await _isNetworkAvailable()) {
      _showStyledSnackBar("No internet connection detected.", isError: true);
      return;
    }

    setState(() => loading = true);

    try {
      // D. Duplicate Username Check
      // Kita check username yang dah di-generate tu wujud tak
      final checkUser = await FirebaseFirestore.instance
          .collection("users").where("username", isEqualTo: finalUsername).get();

      if (checkUser.docs.isNotEmpty) {
        _showStyledSnackBar("Username '$finalUsername' is already taken! Please enter a different one manually.", isError: true);
        setState(() => loading = false);
        return;
      }

      // E. Register using Secondary Instance
      FirebaseApp secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );

      UserCredential userCredential = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(email: email, password: password);

      String userUid = userCredential.user!.uid;

      // F. Save to Firestore
      await FirebaseFirestore.instance.collection("users").doc(userUid).set({
        "username": finalUsername, // Guna finalUsername (sama ada input atau auto)
        "email": email,
        "name": name,
        "phoneNo": phoneNo.isEmpty ? "-" : phoneNo,
        "role": role,
        "status": "Active",
        "registeredBy": widget.username,
        "createdAt": FieldValue.serverTimestamp(),
        "profilePictureUrl": "",
      });

      // Cleanup
      await secondaryApp.delete();

      if (!mounted) return;

      // Paparkan username yang berjaya didaftarkan dalam dialog
      _showSuccessDialog(name, finalUsername);

    } catch (e) {
      _showStyledSnackBar("Registration Failed: $e", isError: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // --- WIDGET SNACKBAR ---
  void _showStyledSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isError ? "Oh Snap!" : "Success!", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(message, style: const TextStyle(fontSize: 12, color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- DIALOG SUCCESS (Updated Text) ---
  void _showSuccessDialog(String createdName, String finalUser) {
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
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.green, size: 50),
              ),
              const SizedBox(height: 20),
              const Text("Account Created!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              // Bagitahu admin username apa yang disave
              Text("User: $createdName\nUsername: $finalUser", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14)),
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
                    Navigator.pop(context);
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UserListPage(loggedInUsername: widget.username)));
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        appBar: AppBar(
          backgroundColor: Colors.white, elevation: 0, foregroundColor: Colors.black,
          title: const Text("Register New User", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.pop(context)),
          actions: [
            IconButton(
              onPressed: _resetForm,
              icon: const Icon(Icons.refresh_rounded, color: Colors.redAccent),
              tooltip: "Clear Form",
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: loading
            ? Center(child: CircularProgressIndicator(color: primaryBlue))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildSectionCard(
                title: "System Credentials",
                children: [
                  // [FIX] Label Username ditukar
                  _buildTextField(usernameController, "Username (Auto if empty)", Icons.alternate_email_rounded),
                  const SizedBox(height: 15),
                  _buildDropdown("Assigned Role *", selectedRole, roles, Icons.badge_rounded, (v) => setState(() => selectedRole = v)),
                  const SizedBox(height: 15),
                  _buildDropdown("Default Password *", selectedDefaultPassword, defaultPasswords, Icons.key_rounded, (v) => setState(() => selectedDefaultPassword = v), isPass: true),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionCard(
                title: "Personal Profile",
                children: [
                  _buildTextField(nameController, "Full Name *", Icons.person_outline_rounded),
                  const SizedBox(height: 15),
                  _buildTextField(emailController, "Email Address *", Icons.email_outlined, type: TextInputType.emailAddress),
                  const SizedBox(height: 15),
                  _buildTextField(phoneNoController, "Phone Number (Optional)", Icons.phone_android_rounded, type: TextInputType.phone),
                ],
              ),
              const SizedBox(height: 40),
              _buildSubmitButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.blueGrey)),
        const Divider(height: 25),
        ...children
      ]),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl, keyboardType: type,
      decoration: InputDecoration(
        labelText: hint, prefixIcon: Icon(icon, color: primaryBlue, size: 20),
        filled: true, fillColor: const Color(0xFFF5F7FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDropdown(String hint, String? val, List<String> items, IconData icon, Function(String?) onChg, {bool isPass = false}) {
    return DropdownButtonFormField<String>(
      value: val, onChanged: onChg,
      decoration: InputDecoration(prefixIcon: Icon(icon, color: primaryBlue, size: 20), filled: true, fillColor: const Color(0xFFF5F7FB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
      items: items.map((s) => DropdownMenuItem(value: s, child: Text(isPass ? "Pass: $s" : s.toUpperCase(), style: const TextStyle(fontSize: 14)))).toList(),
      hint: Text(hint, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity, height: 60,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(colors: [primaryBlue, primaryBlue.withOpacity(0.8)]), boxShadow: [BoxShadow(color: primaryBlue.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))]),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        onPressed: loading ? null : registerUser,
        child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("CREATE USER ACCOUNT", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
      ),
    );
  }

  Future<bool> _isNetworkAvailable() async {
    final res = await Connectivity().checkConnectivity();
    return res != ConnectivityResult.none;
  }
}