import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // [BARU] Untuk check session
import 'login_page.dart';
// Import halaman utama (halaman yang anda navigasi selepas login)
import 'admin/admin_page.dart';
import 'manager/manager_page.dart';
import 'staff/staff_page.dart';

class LaunchPage extends StatefulWidget {
  const LaunchPage({super.key});

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  bool _showButton = false; // Hanya tunjukkan butang jika tiada sesi dikesan

  // Helper untuk navigasi berdasarkan role (diambil dari LoginPage)
  void _navigateToHomePage(String username, String role) {
    if (role == "admin") {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminPage(loggedInUsername: username))
      );
    } else if (role == "manager") {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => ManagerPage()));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => StaffPage()));
    }
  }

  // --- SEMAK STATUS LOG MASUK DALAM INITSTATE ---
  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final savedUsername = prefs.getString('savedUsername');
    final savedRole = prefs.getString('savedRole');

    // Pastikan widget masih mounted sebelum menggunakan Navigator
    if (!mounted) return;

    if (isLoggedIn && savedUsername != null && savedRole != null) {
      // [TINDAKAN OTOMATIK] Jika sesi ditemui, navigasi terus
      _navigateToHomePage(savedUsername, savedRole);
    } else {
      // Jika tiada sesi, tunjukkan butang "LET'S GET STARTED!"
      setState(() {
        _showButton = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _checkSession();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isPortrait = constraints.maxHeight > constraints.maxWidth;
          double horizontalPadding = constraints.maxWidth * 0.08;

          // Paparkan loading indicator sehingga _showButton ditetapkan
          if (!_showButton) {
            return const Center(child: CircularProgressIndicator());
          }

          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  SizedBox(
                    height: isPortrait
                        ? constraints.maxHeight * 0.23
                        : constraints.maxHeight * 0.35,
                    child: Image.asset("assets/logo.png"),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.03),

                  Text(
                    "InventryX",
                    style: TextStyle(
                      fontSize: isPortrait
                          ? constraints.maxWidth * 0.085
                          : constraints.maxHeight * 0.07,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Text(
                    "", // Kosongkan ini
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: isPortrait
                          ? constraints.maxWidth * 0.04
                          : constraints.maxHeight * 0.04,
                    ),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.08),

                  // Butang hanya dipaparkan jika tiada sesi ditemui
                  SizedBox(
                    width: double.infinity,
                    height: constraints.maxHeight * 0.07,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF233E99),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        // Navigasi ke LoginPage jika tiada sesi disimpan
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      child: Text(
                        "LET'S GET STARTED!",
                        style: TextStyle(
                          fontSize: isPortrait
                              ? constraints.maxWidth * 0.05
                              : constraints.maxHeight * 0.04,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}