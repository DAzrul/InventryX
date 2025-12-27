import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'staff_dashboard_page.dart';
import 'utils/staff_features_modal.dart';
import '../Profile/User_profile_page.dart';

class StaffPage extends StatefulWidget {
  final String loggedInUsername;
  final String userId;

  const StaffPage({
    super.key,
    required this.loggedInUsername,
    required this.userId
  });

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  // Index 0: Dashboard, Index 1: Features (Modal), Index 2: Profile
  int _selectedIndex = 0;
  final Color primaryColor = const Color(0xFF203288);

  void _onItemTapped(int index) {
    if (index == 1) {
      // Keluar modal features "chaotic" kau tu mat
      StaffFeaturesModal.show(context);
    } else {
      // Tukar antara Dashboard (0) atau Profile (2)
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          String currentUsername = widget.loggedInUsername;

          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            currentUsername = data['username'] ?? widget.loggedInUsername;
          }

          return Scaffold(
            backgroundColor: const Color(0xFFF6F8FB),
            resizeToAvoidBottomInset: false,
            extendBody: true,

            // --- MAIN CONTENT HANDLER ---
            // Kita guna IndexedStack supaya bila kau pusing-pusing skrin,
            // data kau tak hilang atau kena reload balik. Jimat data babi!
            body: IndexedStack(
              index: _selectedIndex == 2 ? 1 : 0,
              children: [
                StaffDashboardPage(username: currentUsername),
                ProfilePage(username: currentUsername, userId: '',),
              ],
            ),

            // --- FLOATING NAVIGATION BAR ---
            bottomNavigationBar: _buildFloatingNavBar(),
          );
        }
    );
  }

  Widget _buildFloatingNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          selectedItemColor: primaryColor,
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
      icon: Icon(inactiveIcon, size: 22),
      activeIcon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(activeIcon, size: 22, color: primaryColor),
      ),
      label: label,
    );
  }
}