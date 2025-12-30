import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// [PENTING] Pastikan import ni betul
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
  String? adminProfilePictureUrl;

  final Color primaryBlue = const Color(0xFF233E99);
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
          .collection("users").where("username", isEqualTo: widget.username).limit(1).get();
      if (adminSnap.docs.isNotEmpty) {
        setState(() => adminProfilePictureUrl = (adminSnap.docs.first.data() as Map<String, dynamic>)['profilePictureUrl']);
      }
    } catch (e) { debugPrint("Error: $e"); }
  }

  // --- LOGIC: USERNAME VALIDATOR ---
  bool isValidUsername(String username) {
    final RegExp usernameRegExp = RegExp(r'^[a-z0-9._]+$');
    return usernameRegExp.hasMatch(username);
  }

  // --- LOGIC REGISTER DENGAN PREMIUM MESSAGE ---
  Future<void> registerUser() async {
    String email = emailController.text.trim();
    String name = nameController.text.trim();
    String phoneNo = phoneNoController.text.trim();
    String username = usernameController.text.trim().toLowerCase();
    String role = selectedRole ?? '';
    String password = selectedDefaultPassword ?? '';

    // 1. Validation Check
    if (username.isEmpty || role.isEmpty || email.isEmpty || name.isEmpty || phoneNo.isEmpty || password.isEmpty) {
      _showStyledSnackBar("Please fill in all fields to proceed.", isError: true);
      return;
    }

    if (!isValidUsername(username)) {
      _showStyledSnackBar("Invalid Username! Lowercase, numbers, dots only.", isError: true);
      return;
    }

    if (!await _isNetworkAvailable()) {
      _showStyledSnackBar("No internet connection detected.", isError: true);
      return;
    }

    setState(() => loading = true);

    try {
      // 2. Duplicate Username Check
      final checkUser = await FirebaseFirestore.instance
          .collection("users").where("username", isEqualTo: username).get();

      if (checkUser.docs.isNotEmpty) {
        _showStyledSnackBar("Username is already taken!", isError: true);
        setState(() => loading = false);
        return;
      }

      // 3. Register using Secondary Instance
      FirebaseApp secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );

      UserCredential userCredential = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(email: email, password: password);

      String userUid = userCredential.user!.uid;

      // 4. Save to Firestore
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

      // Cleanup
      await secondaryApp.delete();

      if (!mounted) return;

      // [FIX] Panggil Success Dialog Baru
      _showSuccessDialog(name);

    } catch (e) {
      // [FIX] System Error Message
      _showStyledSnackBar("Registration Failed: $e", isError: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // --- [UPDATE 1] WIDGET SNACKBAR PREMIUM ---
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
                    isError ? "Oh Snap!" : "Success!",
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
        backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF43A047), // Merah vs Hijau
        behavior: SnackBarBehavior.floating, // Terapung
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(20),
        elevation: 10,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- [UPDATE 2] DIALOG SUCCESS PREMIUM ---
  void _showSuccessDialog(String createdName) {
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
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.green, size: 50),
              ),
              const SizedBox(height: 20),
              const Text("Account Created!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text(
                "User account for $createdName has been successfully registered.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
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
                    // Redirect ke User List
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

  // --- UI COMPONENTS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, foregroundColor: Colors.black,
        title: const Text("Register New User", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildAdminCard(),
            const SizedBox(height: 30),
            _buildSectionCard(
              title: "System Credentials",
              children: [
                _buildTextField(usernameController, "Username (no spaces)", Icons.alternate_email_rounded),
                const SizedBox(height: 15),
                _buildDropdown("Assigned Role", selectedRole, roles, Icons.badge_rounded, (v) => setState(() => selectedRole = v)),
                const SizedBox(height: 15),
                _buildDropdown("Default Password", selectedDefaultPassword, defaultPasswords, Icons.key_rounded, (v) => setState(() => selectedDefaultPassword = v), isPass: true),
              ],
            ),
            const SizedBox(height: 20),
            _buildSectionCard(
              title: "Personal Profile",
              children: [
                _buildTextField(nameController, "Full Name", Icons.person_outline_rounded),
                const SizedBox(height: 15),
                _buildTextField(emailController, "Email Address", Icons.email_outlined, type: TextInputType.emailAddress),
                const SizedBox(height: 15),
                _buildTextField(phoneNoController, "Phone Number", Icons.phone_android_rounded, type: TextInputType.phone),
              ],
            ),
            const SizedBox(height: 40),
            _buildSubmitButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]),
      child: Row(children: [
        CircleAvatar(radius: 20, backgroundImage: adminProfilePictureUrl != null ? CachedNetworkImageProvider(adminProfilePictureUrl!) : null, child: adminProfilePictureUrl == null ? const Icon(Icons.admin_panel_settings) : null),
        const SizedBox(width: 15),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Authorized Registrar", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), Text(widget.username, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900))]),
      ]),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15)]),
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(colors: [primaryBlue, primaryBlue.withValues(alpha: 0.8)]), boxShadow: [BoxShadow(color: primaryBlue.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 8))]),
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