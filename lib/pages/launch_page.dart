import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- IMPORT HALAMAN ---
import 'login_page.dart';
import 'admin/admin_page.dart';
import 'manager/manager_page.dart';
import 'staff/staff_page.dart';

class LaunchPage extends StatefulWidget {
  const LaunchPage({super.key});

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> with SingleTickerProviderStateMixin {
  bool _showButton = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final Color primaryBlue = const Color(0xFF233E99);
  final Color bgSecondary = const Color(0xFFF8FAFF);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _checkSession();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // --- SEMAK STATUS SESI ---
  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final String? savedUsername = prefs.getString('savedUsername');
    final String? savedRole = prefs.getString('savedRole');
    final String? savedUserId = prefs.getString('savedUserId');

    // Nampak logo kejap mat
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    if (isLoggedIn && savedUsername != null && savedRole != null && savedUserId != null) {
      _navigateToHomePage(savedUsername, savedRole, savedUserId);
    } else {
      setState(() {
        _showButton = true;
      });
      _animationController.forward(); // Start "fucking" animation
    }
  }

  void _navigateToHomePage(String username, String role, String userId) {
    if (!mounted) return;
    Widget targetPage = (role == "admin") ? AdminPage(loggedInUsername: username, userId: userId, username: '',) :
    (role == "manager") ? ManagerPage(loggedInUsername: username, userId: userId) :
    StaffPage(loggedInUsername: username, userId: userId);

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => targetPage));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          double logoSize = constraints.maxWidth * 0.65;

          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, bgSecondary],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- LOGO SECTION WITH SHADOW ---
                Hero(
                  tag: 'logo',
                  child: Container(
                    height: logoSize,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: primaryBlue.withValues(alpha: 0.1),
                          blurRadius: 50,
                          offset: const Offset(0, 20),
                        )
                      ],
                    ),
                    child: Image.asset("assets/logo.png", fit: BoxFit.contain),
                  ),
                ),

                const SizedBox(height: 20),

                // --- BRAND NAME ---
                Text(
                  "InventryX",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: primaryBlue,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "Smart Inventory Management",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 60),

                // --- LOADING OR BUTTON ---
                SizedBox(
                  height: 100,
                  child: !_showButton
                      ? CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                    strokeWidth: 3,
                  )
                      : FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildGetStartedButton(constraints),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGetStartedButton(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
          ),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "GET STARTED",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
              SizedBox(width: 10),
              Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}