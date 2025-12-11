import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // [PENTING] Import Firestore
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

  void _onItemTapped(int index) {
    if (index == 1) {
      ManagerFeaturesModal.show(context);
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // [PENYELESAIAN] Guna StreamBuilder untuk dengar perubahan data user (Real-time update)
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId) // Dengar berdasarkan ID unik
            .snapshots(),
        builder: (context, snapshot) {

          // Dapatkan username terkini dari database
          String currentUsername = widget.loggedInUsername; // Nilai asal sebagai backup

          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            currentUsername = data['username'] ?? widget.loggedInUsername;
          }

          return Scaffold(
            backgroundColor: const Color(0xFFF9FAFC),

            body: SafeArea(
              // Hantar username TERKINI ke content
              child: _buildMainContent(currentUsername),
            ),

            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                backgroundColor: Colors.white,
                selectedItemColor: const Color(0xFF1E3A8A),
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

  Widget _buildMainContent(String currentUsername) {
    if (_selectedIndex == 2) {
      // ProfilePage akan terima username BARU jika ia ditukar
      return ProfilePage(username: currentUsername);
    }
    // Dashboard juga terima data terkini (jika perlu)
    return const ManagerDashboardPage();
  }
}