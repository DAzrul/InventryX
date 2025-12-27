import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'manager_dashboard_page.dart';
import 'utils/manager_features_modal.dart';
import '../Profile/User_profile_page.dart';

class ManagerPage extends StatefulWidget {
  final String loggedInUsername;
  final String userId;

  const ManagerPage({
    super.key,
    required this.loggedInUsername,
    required this.userId
  });

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  int _selectedIndex = 0;
  final Color primaryBlue = const Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          String currentUsername = widget.loggedInUsername;
          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            currentUsername = data['username'] ?? widget.loggedInUsername;
          }

          return Scaffold(
            backgroundColor: const Color(0xFFF6F8FB),

            // --- FIX 1: ELAK OVERFLOW BILA KEYBOARD KELUAR ---
            resizeToAvoidBottomInset: false,

            extendBody: true, // Nav bar akan nampak lebih "floating"
            body: _buildMainContent(currentUsername),

            // --- FIX 2: WRAP NAV BAR DLM SAFEAREA ---
            bottomNavigationBar: SafeArea(
              child: _buildFloatingNavBar(),
            ),
          );
        }
    );
  }

  Widget _buildFloatingNavBar() {
    return Container(
      // --- FIX 3: KURANGKAN MARGIN BAWAH SUPAYA TAK TERTOLEK ---
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      height: 65, // Kecilkan sikit dari 70 ke 65 mat
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15, // Kecilkan blur radius sikit
            offset: const Offset(0, 4), // Offset jangan jauh sangat
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            if (index == 1) {
              ManagerFeaturesModal.show(context);
            } else {
              setState(() => _selectedIndex = index);
            }
          },
          backgroundColor: Colors.white,
          selectedItemColor: primaryBlue,
          unselectedItemColor: Colors.grey.shade400,
          showSelectedLabels: true,
          showUnselectedLabels: false,
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
      icon: Icon(inactiveIcon, size: 22), // Kecilkan sikit dari 24 ke 22
      activeIcon: Container(
        padding: const EdgeInsets.all(6), // Kecilkan padding dari 8 ke 6
        decoration: BoxDecoration(
          color: primaryBlue.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(activeIcon, size: 22, color: primaryBlue),
      ),
      label: label,
    );
  }

  Widget _buildMainContent(String currentUsername) {
    return IndexedStack(
      index: _selectedIndex == 2 ? 1 : 0,
      children: [
        const ManagerDashboardPage(),
        ProfilePage(username: currentUsername, userId: '',),
      ],
    );
  }
}