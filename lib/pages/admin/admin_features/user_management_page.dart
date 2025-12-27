import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
    // Standard: Lowercase, numbers, dots, and underscores only. No spaces!
    final RegExp usernameRegExp = RegExp(r'^[a-z0-9._]+$');
    return usernameRegExp.hasMatch(username);
  }

  Future<void> registerUser() async {
    String email = emailController.text.trim();
    String name = nameController.text.trim();
    String phoneNo = phoneNoController.text.trim();
    String username = usernameController.text.trim().toLowerCase(); // Force lowercase
    String role = selectedRole ?? '';
    String password = selectedDefaultPassword ?? '';

    // 1. Validation Check
    if (username.isEmpty || role.isEmpty || email.isEmpty || name.isEmpty || phoneNo.isEmpty || password.isEmpty) {
      _showPopup("Missing Information", "Please fill in all fields to proceed with registration.");
      return;
    }

    if (!isValidUsername(username)) {
      _showPopup("Invalid Username", "Username must contain only lowercase letters, numbers, dots, or underscores. No spaces allowed!");
      return;
    }

    if (!await _isNetworkAvailable()) {
      _showPopup("Network Error", "No internet connection detected. Cloud registration requires an active network.");
      return;
    }

    setState(() => loading = true);

    try {
      // 2. Duplicate Username Check
      final checkUser = await FirebaseFirestore.instance
          .collection("users").where("username", isEqualTo: username).get();

      if (checkUser.docs.isNotEmpty) {
        _showPopup("Username Taken", "This username is already registered. Please choose a different one.");
        setState(() => loading = false);
        return;
      }

      // 3. Register using Secondary Instance to prevent Admin Logout
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
      _showPopup("Success", "Account for $name has been registered successfully.", isSuccess: true);

    } catch (e) {
      _showPopup("Registration Failed", e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
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

  void _showPopup(String title, String msg, {bool isSuccess = false}) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), content: Text(msg),
      actions: [TextButton(onPressed: () {
        Navigator.pop(context);
        if(isSuccess) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UserListPage(loggedInUsername: widget.username)));
      }, child: const Text("OK"))],
    ));
  }

  Future<bool> _isNetworkAvailable() async {
    final res = await Connectivity().checkConnectivity();
    return res != ConnectivityResult.none;
  }
}