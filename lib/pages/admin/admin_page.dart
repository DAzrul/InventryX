import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../Profile/User_profile_page.dart';
import 'user_list_page.dart';
import 'admin_dashboard_page.dart';
import 'utils/features_modal.dart';

class AdminScreen extends StatefulWidget {
  final String loggedInUsername;
  final int initialIndex;
  final String userId;

  const AdminScreen({
    super.key,
    required this.loggedInUsername,
    this.initialIndex = 0,
    required this.userId,
  });

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _currentIndex = 0;

  final List<BottomNavigationBarItem> _navItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Features'),
    BottomNavigationBarItem(icon: Icon(Icons.person_outlined), label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex == 1 ? 0 : widget.initialIndex;
  }

  void _onTapHandler(int index) {
    if (index == 1) {
      FeaturesModal.show(context, widget.loggedInUsername);
    } else {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  // [FUNGSI BARU] Untuk tukar tab dari anak (Dashboard)
  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _getPageWidget(String currentUsername) {
    if (_currentIndex == 0) {
      return AdminDashboardPage(
        loggedInUsername: currentUsername,
        userId: widget.userId,
        showFeatureGrid: false,
        // Hantar fungsi ini ke dashboard
        onTabChange: _switchTab,
      );
    } else if (_currentIndex == 2) {
      return ProfilePage(
        username: currentUsername,
      );
    }
    // Default
    return AdminDashboardPage(
      loggedInUsername: currentUsername,
      userId: widget.userId,
      showFeatureGrid: false,
      onTabChange: _switchTab,
    );
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
            backgroundColor: Colors.white,

            body: _getPageWidget(currentUsername),

            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTapHandler,
              selectedItemColor: const Color(0xFF233E99),
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              items: _navItems,
            ),
          );
        }
    );
  }
}