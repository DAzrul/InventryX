import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_page.dart';
// Gantikan import ini dengan laluan yang betul dalam projek anda
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

  // Helper untuk navigasi berdasarkan role
  void _navigateToHomePage(String username, String role, String userId) {
    if (!mounted) return;
    if (role == "admin") {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminScreen(loggedInUsername: username, userId: userId,))
      );
    } else if (role == "manager") {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ManagerPage()));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const StaffPage()));
    }
  }

  // --- SEMAK STATUS LOG MASUK ---
  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final savedUsername = prefs.getString('savedUsername');
    final savedRole = prefs.getString('savedRole');
    final savedUserId = prefs.getString('savedUserId');

    if (!mounted) return;

    if (isLoggedIn && savedUsername != null && savedRole != null && savedUserId != null) {
      // Sesi ditemui, navigasi terus
      _navigateToHomePage(savedUsername, savedRole, savedUserId);
    } else {
      // Tiada sesi, tunjukkan UI
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