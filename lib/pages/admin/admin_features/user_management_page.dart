import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Import untuk navigasi Features
import '../admin_page.dart';
// --- PENGUBAHSUAIAN BERMULA DI SINI ---
// Sila ganti './user_list_page.dart' dengan laluan fail yang betul untuk UserListPage anda
import '../user_list_page.dart';
// --- PENGUBAHSUAIAN BERAKHIR DI SINI ---


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
  final TextEditingController positionController = TextEditingController();

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

  // --- FUNGSI BARU: Muatkan Gambar Profil Admin ---
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
      print("Error loading admin profile picture: $e");
    }
  }


  // --- FUNGSI POPUP MESSAGE YANG DIBETULKAN ---
  void showPopupMessage(String title, {String? message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message != null ? Text(message) : null,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }


  // --- Fungsi Logik Pendaftaran Pengguna DENGAN FIREBASE AUTH ---
  Future<void> registerUser() async {
    String email = emailController.text.trim();
    String name = nameController.text.trim();
    String phoneNo = phoneNoController.text.trim();
    String position = positionController.text.trim();
    String role = selectedRole ?? '';
    String password = selectedDefaultPassword ?? '';

    // 1. Validation
    if (role.isEmpty || email.isEmpty || name.isEmpty || phoneNo.isEmpty || position.isEmpty || password.isEmpty) {
      showPopupMessage("Error", message: "Please fill all required fields.");
      return;
    }
    if (password.length < 6) {
      showPopupMessage("Error", message: "Password must be at least 6 characters.");
      return;
    }

    String username;
    if (email.contains('@')) {
      username = email.substring(0, email.indexOf('@'));
    } else {
      showPopupMessage("Error", message: "Invalid email format.");
      return;
    }

    setState(() => loading = true);
    UserCredential? userCredential;

    try {
      // 2. Semak jika Username sudah wujud dalam Firestore
      QuerySnapshot existingUsernameSnap = await FirebaseFirestore.instance
          .collection("users")
          .where("username", isEqualTo: username)
          .limit(1)
          .get();

      if (existingUsernameSnap.docs.isNotEmpty) {
        showPopupMessage("Registration Failed", message: "Username ($username) already taken. Please use a different email.");
        setState(() => loading = false);
        return;
      }

      // 3. REGISTER PENGGUNA KE FIREBASE AUTHENTICATION
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? newUser = userCredential.user;

      if (newUser == null) {
        throw Exception("Failed to get new user data after registration.");
      }

      final String userUid = newUser.uid; // Dapatkan UID

      // 4. Tambah butiran tambahan ke Firestore menggunakan UID sebagai ID Dokumen
      await FirebaseFirestore.instance.collection("users").doc(userUid).set({
        "username": username,
        "email": email,
        "name": name,
        "phoneNo": phoneNo,
        "position": position,
        "role": role,
        "status": "Active",
        "registeredBy": widget.username,
        "createdAt": FieldValue.serverTimestamp(),
        "profilePictureUrl": "",
      });

      // 5. Tunjukkan mesej kejayaan
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Success"),
          content: Text("User $name registered successfully as $role. Username: $username\n\n(Password: $password)"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Tutup dialog

                // --- PENGUBAHSUAIAN BERMULA DI SINI ---
                // Navigasi ke UserListPage
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    // *GANTIKAN DENGAN WIDGET USERLISTPAGE ANDA YANG BETUL*
                    builder: (context) => UserListPage(loggedInUsername: widget.username),
                    // Jika UserListPage anda memerlukan parameter tambahan, sila tambah di sini
                  ),
                );
                // --- PENGUBAHSUAIAN BERAKHIR DI SINI ---
              },
              child: const Text("OK"),
            )
          ],
        ),
      );

      // 6. Kosongkan medan
      emailController.clear();
      nameController.clear();
      phoneNoController.clear();
      positionController.clear();
      setState(() {
        selectedRole = null;
        selectedDefaultPassword = null;
      });

    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'email-already-in-use') {
        errorMessage = "Email is already in use by another account.";
      } else {
        errorMessage = "Auth Error: ${e.message}";
      }
      showPopupMessage("Registration Failed", message: errorMessage);

    } catch (e) {
      if (userCredential != null) {
        userCredential.user?.delete();
      }
      showPopupMessage("Registration Error", message: "Failed to register user: ${e.toString()}");
    } finally {
      if(mounted) {
        setState(() => loading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Tentukan Image Provider berdasarkan URL gambar Admin
    ImageProvider adminAvatarImage = adminProfilePictureUrl != null && adminProfilePictureUrl!.isNotEmpty
        ? CachedNetworkImageProvider(adminProfilePictureUrl!) as ImageProvider
        : const AssetImage('assets/profile.png');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Administrator
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  // [DIUBAH] Menggunakan URL gambar Admin
                  CircleAvatar(radius: 18, backgroundImage: adminAvatarImage),
                  const SizedBox(width: 10),
                  Text(widget.username, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                ],
              ),
            ),

            const Text("User Registration", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // --- 1. Choose Role (Dropdown) ---
            DropdownButtonFormField<String>(
              decoration: _dropdownDecoration("Choose Role"),
              value: selectedRole,
              items: roles.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value.toUpperCase()),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() { selectedRole = newValue; });
              },
            ),
            const SizedBox(height: 20),

            // --- 2. Email ---
            TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: _inputDecoration("Email", Icons.email_outlined)),
            const SizedBox(height: 15),

            // --- 3. Name ---
            TextField(controller: nameController, decoration: _inputDecoration("Name", Icons.person_outline)),
            const SizedBox(height: 15),

            // --- 4. Phone Number ---
            TextField(controller: phoneNoController, keyboardType: TextInputType.phone, decoration: _inputDecoration("Phone number", Icons.phone_outlined)),
            const SizedBox(height: 15),

            // --- 5. Position ---
            TextField(controller: positionController, decoration: _inputDecoration("Position", Icons.work_outline)), // Icon diubah
            const SizedBox(height: 15),

            // --- 6. Choose Password Default (Dropdown) ---
            DropdownButtonFormField<String>(
              decoration: _dropdownDecoration("Choose Password Default (Min 6 chars)"),
              value: selectedDefaultPassword,
              items: defaultPasswords.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text("Set: $value"),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() { selectedDefaultPassword = newValue; });
              },
            ),
            const SizedBox(height: 30),

            // --- Register Button ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF233E99),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: loading ? null : registerUser,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Register", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // Widget Pembantu untuk InputDecoration
  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: Colors.grey[600]),
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  // Widget Pembantu untuk Dropdown Decoration
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
}