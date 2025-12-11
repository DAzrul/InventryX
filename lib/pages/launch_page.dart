import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- IMPORT HALAMAN ---
import 'login_page.dart';
// Pastikan path import ini betul mengikut folder projek anda
import 'admin/admin_page.dart';
import 'manager/manager_page.dart';
import 'staff/staff_page.dart';

class LaunchPage extends StatefulWidget {
  const LaunchPage({super.key});

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  bool _showButton = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  // --- FUNGSI NAVIGASI ---
  void _navigateToHomePage(String username, String role, String userId) {
    if (!mounted) return;

    Widget targetPage;

    if (role == "admin") {
      // Admin mungkin masih perlukan data manual (bergantung kod admin anda)
      targetPage = AdminScreen(loggedInUsername: username, userId: userId);
    } else if (role == "manager") {
      // MANAGER: Panggil sebagai const kerana ManagerPage baru guna FirebaseAuth dalaman
      targetPage = ManagerPage(loggedInUsername: username, userId: userId);
    } else {
      // STAFF
      targetPage = StaffPage(loggedInUsername: username, userId: userId);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => targetPage),
    );
  }

  // --- SEMAK STATUS SESI ---
  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();

    // Ambil data sesi
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final String? savedUsername = prefs.getString('savedUsername');
    final String? savedRole = prefs.getString('savedRole');
    final String? savedUserId = prefs.getString('savedUserId');

    // Tambah delay sikit untuk nampak logo (opsyenal, 1.5 saat)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    if (isLoggedIn && savedUsername != null && savedRole != null && savedUserId != null) {
      // Sesi wujud, terus masuk
      _navigateToHomePage(savedUsername, savedRole, savedUserId);
    } else {
      // Tiada sesi, tunjuk butang "Get Started"
      setState(() {
        _showButton = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Latar belakang putih bersih
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isPortrait = constraints.maxHeight > constraints.maxWidth;
          double horizontalPadding = constraints.maxWidth * 0.08;

          // Jika sesi sedang disemak (belum tunjuk butang), paparkan Loading ringkas
          if (!_showButton) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: constraints.maxHeight * 0.2,
                    child: Image.asset("assets/logo.png"), // Pastikan logo wujud
                  ),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(), // Loading pusing
                ],
              ),
            );
          }

          // UI Utama (Lepas check session gagal)
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                      color: const Color(0xFF233E99),
                    ),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.08),

                  // Butang "LET'S GET STARTED!"
                  SizedBox(
                    width: double.infinity,
                    height: constraints.maxHeight * 0.07,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF233E99),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 5,
                      ),
                      onPressed: () {
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