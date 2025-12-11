import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
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
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    if (index == 1) {
      StaffFeaturesModal.show(context);
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // [PENYELESAIAN] Guna StreamBuilder untuk dengar perubahan pada User Dokumen
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId) // Dengar by ID (ID takkan berubah)
            .snapshots(),
        builder: (context, snapshot) {

          // 1. Ambil username terkini dari database
          String currentUsername = widget.loggedInUsername; // Default ke lama jika loading

          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            currentUsername = data['username'] ?? widget.loggedInUsername;
          }

          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              // Hantar username TERKINI ke function content
              child: _buildMainContent(currentUsername),
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5)),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                backgroundColor: Colors.white,
                selectedItemColor: const Color(0xFF203288),
                unselectedItemColor: Colors.grey,
                showUnselectedLabels: true,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined, size: 28),
                    activeIcon: Icon(Icons.home, size: 28),
                    label: "Home",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.grid_view_rounded, size: 28),
                    label: "Features",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline, size: 28),
                    activeIcon: Icon(Icons.person, size: 28),
                    label: "Profile",
                  ),
                ],
              ),
            ),
          );
        }
    );
  }

  // Terima usernameTerkini sebagai parameter
  Widget _buildMainContent(String currentUsername) {
    if (_selectedIndex == 2) {
      // Hantar username BARU ke Profile Page
      return ProfilePage(username: currentUsername);
    }
    // Hantar username BARU ke Dashboard
    return StaffDashboardPage(username: currentUsername);
  }
}