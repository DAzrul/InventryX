import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart'; // [PENTING]

// [PENTING] Import navigation admin
import 'admin_page.dart';
import 'utils/features_modal.dart'; // Modal Admin
import '../Profile/User_profile_page.dart';

import 'user_edit_page.dart';
import 'user_delete_page.dart';
import 'admin_features/user_management_page.dart'; // Ini page "Add User" form kau

class UserListPage extends StatefulWidget {
  final String loggedInUsername;

  const UserListPage({super.key, required this.loggedInUsername});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  // [FIX] Default Index = 1 (Sebab ni page Features)
  int _selectedIndex = 1;

  String _selectedRole = 'All';
  final List<String> _roles = ['All', 'Admin', 'Staff', 'Manager'];
  final Color primaryBlue = const Color(0xFF233E99);

  // --- LOGIC NUCLEAR: RESET APP ---
  void _onItemTapped(int index) {
    if (index == 0) {
      // 1. HOME: Nuclear Reset ke Admin Dashboard
      final user = FirebaseAuth.instance.currentUser;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => AdminPage(
            username: widget.loggedInUsername, // Maintain username
            userId: user?.uid ?? '', loggedInUsername: '',
          ),
        ),
            (Route<dynamic> route) => false,
      );
    } else if (index == 1) {
      // 2. FEATURES: Buka Modal Admin
      FeaturesModal.show(context, widget.loggedInUsername);
    } else {
      // 3. PROFILE: Tukar tab
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          String currentUsername = widget.loggedInUsername;
          if (snapshot.hasData && snapshot.data!.exists) {
            var d = snapshot.data!.data() as Map<String, dynamic>;
            currentUsername = d['username'] ?? currentUsername;
          }

          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFF),

            // --- MAIN CONTENT HANDLER ---
            body: IndexedStack(
              // index 0: User List Content, index 1: Profile
              index: _selectedIndex == 2 ? 1 : 0,
              children: [
                _buildUserManagementUI(), // Main Content
                ProfilePage(username: currentUsername, userId: uid ?? ''), // Profile
              ],
            ),

            // --- FLOATING NAVBAR (DESIGN SAMA) ---
            bottomNavigationBar: _buildFloatingNavBar(),
          );
        }
    );
  }

  // --- UI: NAVBAR ---
  Widget _buildFloatingNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
      icon: Icon(inactiveIcon, size: 22),
      activeIcon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: primaryBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(activeIcon, size: 22, color: primaryBlue),
      ),
      label: label,
    );
  }

  // --- CONTENT ASAL KAU (DIBUNGKUS DLM WIDGET) ---
  Widget _buildUserManagementUI() {
    return Column(
      children: [
        _buildHeader(),
        _buildTotalStatCard(),
        _buildFilterAndAddSection(),
        const SizedBox(height: 15),
        Expanded(child: _buildUserListStream()),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 55, 20, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
            onPressed: () => Navigator.pop(context), // Back button manual
          ),
          const Text("User Management",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildTotalStatCard() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: primaryBlue,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: primaryBlue.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("users").snapshots(),
          builder: (context, snapshot) {
            final count = snapshot.hasData ? snapshot.data!.docs.length.toString() : '...';
            return Row(
              children: [
                const Icon(Icons.people_alt_rounded, color: Colors.white70, size: 35),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Total System Users", style: TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w600)),
                    Text("$count Staff", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterAndAddSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _roles.map((role) {
                  bool isSelected = _selectedRole == role;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedRole = role),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryBlue : Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: isSelected ? primaryBlue : Colors.grey.shade200),
                      ),
                      child: Text(role, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            // [NOTE] Ini akan buka form Add User (UserManagementPage)
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserManagementPage(username: widget.loggedInUsername))),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListStream() {
    Query query = FirebaseFirestore.instance.collection("users");
    if (_selectedRole.toLowerCase() != 'all') {
      query = query.where('role', isEqualTo: _selectedRole.toLowerCase());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error loading users. Check rules!"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final filteredUsers = snapshot.data!.docs.where((doc) => doc['username'] != widget.loggedInUsername).toList();

        if (filteredUsers.isEmpty) return const Center(child: Text("No users found in this category."));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            var data = filteredUsers[index].data() as Map<String, dynamic>;
            return _buildUserCard(data, filteredUsers[index].id);
          },
        );
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> data, String docId) {
    final bool isActive = data['status'] == 'Active';
    final Color statusColor = isActive ? Colors.green.shade600 : Colors.red.shade600;
    final String? img = data['profilePictureUrl'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primaryBlue.withValues(alpha: 0.1), width: 2)
            ),
            child: CircleAvatar(
              radius: 25,
              backgroundColor: Colors.white,
              backgroundImage: (img != null && img.isNotEmpty)
                  ? CachedNetworkImageProvider(img) : null,
              child: (img == null || img.isEmpty)
                  ? Icon(Icons.person_rounded, color: primaryBlue.withValues(alpha: 0.4), size: 30)
                  : null,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['username'] ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text(data['role']?.toString().toUpperCase() ?? 'STAFF',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(isActive ? "ACTIVE" : "INACTIVE",
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 9)),
              ),
              Row(
                children: [
                  IconButton(
                      icon: Icon(Icons.edit_note_rounded, color: primaryBlue, size: 24),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                          UserEditPage(userId: docId, loggedInUsername: widget.loggedInUsername, username: data['username'], userData: data)))
                  ),
                  IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 22),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                          UserDeletePage(userId: docId, loggedInUsername: widget.loggedInUsername, username: data['username'], userData: data)))
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}