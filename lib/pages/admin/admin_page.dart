import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_dashboard_page.dart';
import '../Profile/User_profile_page.dart';
import 'widgets/bottom_nav_page.dart';

class AdminPage extends StatefulWidget {
  final String loggedInUsername;
  final String userId;

  const AdminPage({super.key, required this.loggedInUsername, required this.userId, required String username});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _selectedIndex = 0;

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

          return BottomNavPage(
            loggedInUsername: currentUsername,
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            child: IndexedStack(
              // Index 0: Dashboard, Index 1: Profile
              index: _selectedIndex == 2 ? 1 : 0,
              children: [
                AdminDashboardPage(loggedInUsername: currentUsername, userId: widget.userId),
                ProfilePage(username: currentUsername, userId: widget.userId),
              ],
            ),
          );
        }
    );
  }
}