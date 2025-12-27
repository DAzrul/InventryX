import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import path mat, pastikan betul!
import 'daily_sales.dart';
import 'history_sales.dart';
import '../staff/utils/staff_features_modal.dart';
import '../Profile/User_profile_page.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  // Index 0: Sales Home, Index 1: Features (Modal), Index 2: Profile
  int _selectedIndex = 1; // Default kat tengah sebab kita masuk dari Features
  int? selectedOptionIndex;

  final Color primaryColor = const Color(0xFF203288);

  // --- LOGIC: NAVIGATION TAPPED (GOD MODE) ---
  void _onItemTapped(int index) {
    if (index == 0) {
      // [FIX] CLICK HOME -> CUCI SEMUA STACK, BALIK DASHBOARD ASAL!
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (index == 1) {
      // CLICK FEATURES -> TUNJUK MODAL BALIK
      StaffFeaturesModal.show(context);
    } else {
      // CLICK PROFILE -> SWITCH INDEX KE PROFILE
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _handleOptionTap(int index) async {
    setState(() => selectedOptionIndex = index);
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    Widget targetPage = (index == 0) ? const DailySalesPage() : const HistorySalesPage();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => targetPage),
    ).then((_) {
      if (mounted) setState(() => selectedOptionIndex = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          String currentUsername = "User";
          if (snapshot.hasData && snapshot.data!.exists) {
            var d = snapshot.data!.data() as Map<String, dynamic>;
            currentUsername = d['username'] ?? "User";
          }

          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFF),
            extendBody: true, // Biar floating nav nampak kacak babi

            // --- MAIN CONTENT (SALES HOME VS PROFILE) ---
            body: IndexedStack(
              index: _selectedIndex == 2 ? 1 : 0,
              children: [
                _buildSalesHome(),
                ProfilePage(username: currentUsername, userId: '',),
              ],
            ),

            bottomNavigationBar: _buildFloatingNavBar(),
          );
        }
    );
  }

  // --- UI: SALES MAIN SELECTION (TAB 0) ---
  Widget _buildSalesHome() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Sales Management",
          style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Choose Action",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
            const SizedBox(height: 20),
            _SalesOptionCard(
              title: "Daily Sales Input",
              subtitle: "Record today's automated simulation",
              icon: Icons.add_chart_rounded,
              isActive: selectedOptionIndex == 0,
              primaryColor: const Color(0xFF233E99),
              onTap: () => _handleOptionTap(0),
            ),
            const SizedBox(height: 20),
            _SalesOptionCard(
              title: "Sales History",
              subtitle: "Track & edit previous records",
              icon: Icons.manage_history_rounded,
              isActive: selectedOptionIndex == 1,
              primaryColor: const Color(0xFF1E3A8A),
              onTap: () => _handleOptionTap(1),
            ),
            const SizedBox(height: 40),
            _buildInfoBox(),
          ],
        ),
      ),
    );
  }

  // --- UI: FLOATING NAVIGATION BAR (STAFF SIGNATURE) ---
  Widget _buildFloatingNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey.shade400,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          items: [
            _navItem(Icons.home_outlined, Icons.home_rounded, "Home"),
            _navItem(Icons.grid_view_outlined, Icons.grid_view_rounded, "Features"),
            _navItem(Icons.person_outline_rounded, Icons.person_rounded, "Profile"),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(IconData inactiveIcon, IconData activeIcon, String label) {
    return BottomNavigationBarItem(
      icon: Icon(inactiveIcon, size: 22),
      activeIcon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(activeIcon, size: 22, color: primaryColor),
      ),
      label: label,
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF233E99).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF233E99).withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF233E99)),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              "Keep your sales record updated daily for more accurate stock forecasting.",
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// --- OPTION CARD CLASS ---
class _SalesOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final Color primaryColor;
  final VoidCallback onTap;

  const _SalesOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: isActive ? null : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? primaryColor.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white24 : primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: isActive ? Colors.white : primaryColor, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isActive ? Colors.white : const Color(0xFF1A1C1E),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isActive ? Colors.white70 : Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isActive ? Colors.white54 : Colors.grey.shade300,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}