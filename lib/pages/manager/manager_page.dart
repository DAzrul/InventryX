import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import '../../pages/login_page.dart'; // Import LoginPage

class ManagerPage extends StatefulWidget {
  // Nota: Walaupun tiada parameter, kita menggunakan StatefulWidget untuk fungsi logout
  const ManagerPage({super.key});

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {

  // --- Fungsi Logout (Memadam Sesi) ---
  Future<void> _logout() async {

    // 1. Padamkan status 'Remember Me' (shared_preferences)
    await LoginPage.clearLoginState();

    // 2. Log keluar dari Firebase Authentication
    await FirebaseAuth.instance.signOut();

    // 3. Semak mounted sebelum menggunakan context
    if (!mounted) return;

    // 4. Navigasi ke halaman Login dan kosongkan stack
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manager Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Butang Logout di AppBar
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _logout, // Panggil fungsi logout
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
                "Manager Page",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w500)
            ),
            SizedBox(height: 10),
            Text(
                "Access features for Manager role.",
                style: TextStyle(fontSize: 16, color: Colors.grey)
            ),
          ],
        ),
      ),
    );
  }
}