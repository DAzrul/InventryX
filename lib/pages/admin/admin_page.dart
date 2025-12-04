// File: lib/pages/admin/admin_page.dart (AdminScreen)
import 'package:flutter/material.dart';
// Import halaman dan utilitas yang relevan (Path disesuaikan)
import '../user_settings_page.dart';
import 'user_list_page.dart'; // Asumsi UserListPage di admin_features
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
  int _currentIndex = 0; // State untuk Bottom Navigation
  late List<Widget> _pages;

  final List<BottomNavigationBarItem> _navItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Features'),
    BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    // Jika initialIndex adalah 1 (Features), kita set ke 0 (Home)
    _currentIndex = widget.initialIndex == 1 ? 0 : widget.initialIndex;

    _pages = [
      // Index 0: Dashboard
      AdminDashboardPage(
        loggedInUsername: widget.loggedInUsername,
        showFeatureGrid: false,
        onNavigateToUserList: _navigateToUserListPage,
      ),
      // Index 1: Settings (Index 2 di Bottom Nav)
      UserSettingsPage(username: widget.loggedInUsername, displayFullNavBar: false, userId: widget.userId),
    ];
  }

  // Fungsi navigasi ke UserList yang menunggu hasil (indeks baru)
  void _navigateToUserListPage() async {
    // Navigasi ke User List Page
    final newIndex = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserListPage(
          loggedInUsername: widget.loggedInUsername,
        ),
      ),
    );

    // Jika hasil (newIndex) diterima (misal 0 atau 2), tukar tab
    if (newIndex != null && newIndex is int) {
      if (mounted) {
        setState(() {
          // Index 0=Home, 2=Settings. Kita set _currentIndex ke nilai yang sama.
          _currentIndex = (newIndex == 2) ? 2 : 0;
        });
      }
    }
  }

  // Fungsi yang menangani TAP pada Bottom Navigation Bar
  void _onTapHandler(int index) {
    if (index == 1) {
      // Index 1 (Features) : Tampilkan Modal
      FeaturesModal.show(context, widget.loggedInUsername);
    } else {
      // Index 0 (Home) atau 2 (Settings) : Ubah tab
      setState(() {
        _currentIndex = index;
      });
    }
  }

  // Fungsi untuk mendapatkan halaman yang benar dari array _pages (0, 1)
  Widget _getPageWidget() {
    // Jika index = 0 (Home), ambil _pages[0]
    // Jika index = 2 (Settings), ambil _pages[1]
    if (_currentIndex == 0) {
      return _pages[0]; // Dashboard
    } else if (_currentIndex == 2) {
      return _pages[1]; // Settings
    }
    // Jika _currentIndex adalah 1 (Features), biarkan tetap di halaman saat ini (0)
    return _pages[0];
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _getPageWidget(),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex, // Mengontrol highlight ikon
        onTap: _onTapHandler,
        selectedItemColor: const Color(0xFF233E99), // Biru
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: _navItems,
      ),
    );
  }
}