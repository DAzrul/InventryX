import 'package:flutter/material.dart';
import '../utils/features_modal.dart';

class BottomNavPage extends StatelessWidget {
  final Widget child;
  final String loggedInUsername;
  final int currentIndex;
  final Function(int)? onTap;

  const BottomNavPage({
    super.key,
    required this.child,
    required this.loggedInUsername,
    this.currentIndex = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF233E99);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      extendBody: true, // Biar content scroll bawah nav bar
      resizeToAvoidBottomInset: false,
      body: child,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 15),
        height: 65,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) {
              if (index == 1) {
                FeaturesModal.show(context, loggedInUsername);
              } else if (onTap != null) {
                onTap!(index); // Hantar balik index ke AdminPage
              } else {
                // Kalau guna dlm UserListPage, balik ke AdminPage asal
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            backgroundColor: Colors.white,
            selectedItemColor: primaryColor,
            unselectedItemColor: Colors.grey.shade400,
            showSelectedLabels: true,
            showUnselectedLabels: false,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
            items: [
              _navItem(Icons.home_outlined, Icons.home_rounded, "Home", primaryColor),
              _navItem(Icons.grid_view_outlined, Icons.grid_view_rounded, "Features", primaryColor),
              _navItem(Icons.person_outline_rounded, Icons.person_rounded, "Profile", primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(IconData inactive, IconData active, String label, Color color) {
    return BottomNavigationBarItem(
      icon: Icon(inactive, size: 24),
      activeIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(active, size: 24, color: color),
      ),
      label: label,
    );
  }
}