import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'widgets/bottom_nav_page.dart';
import 'user_edit_page.dart';
import 'user_delete_page.dart';
import 'admin_features/user_management_page.dart';
import '../Profile/User_profile_page.dart';

class UserListPage extends StatefulWidget {
  final String loggedInUsername;

  const UserListPage({super.key, required this.loggedInUsername});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  int _localIndex = 0;
  String _selectedRole = 'All';
  final List<String> _roles = ['All', 'Admin', 'Staff', 'Manager'];
  final Color primaryBlue = const Color(0xFF233E99);

  @override
  Widget build(BuildContext context) {
    return BottomNavPage(
      loggedInUsername: widget.loggedInUsername,
      currentIndex: _localIndex,
      onTap: (index) {
        if (index == 0) setState(() => _localIndex = 0);
        else if (index == 2) setState(() => _localIndex = 2);
      },
      child: IndexedStack(
        index: _localIndex,
        children: [
          _buildUserManagementUI(),
          const SizedBox.shrink(),
          ProfilePage(username: widget.loggedInUsername),
        ],
      ),
    );
  }

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
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
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

        // Filter out current logged in user mat
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
    final String? img = data['profilePictureUrl']; // Ambil URL gambar profil

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
          // --- REPAIRED PROFILE IMAGE SECTION --- sebiji macam AdminDashboard
          Container(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primaryBlue.withValues(alpha: 0.1), width: 2)
            ),
            child: CircleAvatar(
              radius: 25,
              backgroundColor: Colors.white,
              // Kalau ada URL gambar dlm Firestore, kita display guna CachedNetworkImage
              backgroundImage: (img != null && img.isNotEmpty)
                  ? CachedNetworkImageProvider(img) : null,
              // Kalau imej null atau kosong, kita bagi icon kacak warna biru muda
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