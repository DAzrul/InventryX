// File: user_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Import komponen yang diperlukan
import 'utils/features_modal.dart'; // Pastikan path ni betul
import 'user_edit_page.dart';       // Pastikan path ni betul
import 'user_delete_page.dart';     // Pastikan path ni betul
import 'admin_features/user_management_page.dart'; // Pastikan path ni betul

// --- Widget Kustom untuk UserListItem (Kekal Sama) ---
class UserListItem extends StatelessWidget {
  final String username;
  final String role;
  final bool isActive;
  final String? profilePictureUrl;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const UserListItem({
    super.key,
    required this.username,
    required this.role,
    required this.isActive,
    this.profilePictureUrl,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUrlValid = profilePictureUrl != null && profilePictureUrl!.isNotEmpty;

    Widget buildAvatar() {
      if (isUrlValid) {
        return CachedNetworkImage(
          imageUrl: profilePictureUrl!,
          imageBuilder: (context, imageProvider) => CircleAvatar(
            radius: 20,
            backgroundImage: imageProvider,
          ),
          errorWidget: (context, url, error) => const CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, color: Colors.white),
          ),
        );
      } else {
        return const CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey,
          child: Icon(Icons.person, color: Colors.white),
        );
      }
    }

    final Color statusColor = isActive ? Colors.green.shade600 : Colors.red.shade600;
    final String statusText = isActive ? 'Active' : 'Inactive';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4),
          ],
        ),
        child: ListTile(
          leading: buildAvatar(),
          title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(role),
          trailing: SizedBox(
            width: 130, // Saiz fix untuk button
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                if (isActive)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey),
                    onPressed: onEdit,
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget untuk Tab Filter (Kekal Sama)
class RoleFilterTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const RoleFilterTab({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color selectedColor = const Color(0xFF233E99);
    final Color unselectedColor = Colors.grey.shade400;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : unselectedColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}


// --- UserListPage Utama ---
class UserListPage extends StatefulWidget {
  final String loggedInUsername;

  const UserListPage({super.key, required this.loggedInUsername});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  String _selectedRole = 'All';
  int _currentTabIndex = 0;

  final List<String> _roles = ['All', 'Admin', 'Staff', 'Manager'];

  // Stream untuk senarai pengguna
  Stream<QuerySnapshot> get _userStream {
    Query collection = FirebaseFirestore.instance.collection("users");
    final String filterKey = _selectedRole.toLowerCase();

    if (filterKey == 'all') {
      return collection.orderBy('username', descending: false).snapshots();
    } else {
      return collection
          .where('role', isEqualTo: filterKey)
          .snapshots();
    }
  }

  void _showFeaturesModal() {
    FeaturesModal.show(context, widget.loggedInUsername);
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      _showFeaturesModal();
      return;
    }
    // Logic Home & Profile
    if (index == 0 || index == 2) {
      // Sama macam back button, kita kill stack sampai jumpa dashboard
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Widget _buildAppBarAvatar(String? profilePictureUrl) {
    const double radius = 18;
    final bool isUrlValid = profilePictureUrl != null && profilePictureUrl.isNotEmpty;

    if (isUrlValid) {
      return CachedNetworkImage(
        imageUrl: profilePictureUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: radius,
          backgroundImage: imageProvider,
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey.shade300,
          child: const Icon(Icons.person, size: 20, color: Colors.grey),
        ),
      );
    } else {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade300,
        child: const Icon(Icons.person, size: 20, color: Colors.grey),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentLoggedInUsername = widget.loggedInUsername;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("users")
              .where('username', isEqualTo: widget.loggedInUsername)
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            String displayName = widget.loggedInUsername;
            String? profileUrl;

            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              var userData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
              displayName = userData['username'] ?? displayName;
              profileUrl = userData['profilePictureUrl'];
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAppBarAvatar(profileUrl),
                const SizedBox(width: 10),
                Text(
                  displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            );
          },
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          // --- [INI FIX DIA] ---
          // popUntil((route) => route.isFirst) akan buang semua page stack yang bertindih
          // dan terus balik ke page pertama (Admin Dashboard)
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        actions: const [],
      ),

      body: Column(
        children: [
          // 1. Dashboard Card
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF233E99),
                borderRadius: BorderRadius.circular(15),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection("users").snapshots(),
                builder: (context, snapshot) {
                  String displayCount = '...';
                  if (snapshot.hasData) {
                    displayCount = snapshot.data!.docs.length.toString();
                  }

                  return Row(
                    children: [
                      const Icon(Icons.people_alt, color: Colors.white, size: 30),
                      const SizedBox(width: 10),
                      Text(displayCount, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                      const Spacer(),
                      const Text("Total Users", style: TextStyle(fontSize: 16, color: Colors.white70)),
                    ],
                  );
                },
              ),
            ),
          ),

          // 2. Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._roles.map((role) => RoleFilterTab(
                    label: role,
                    isSelected: _selectedRole == role,
                    onTap: () {
                      setState(() {
                        _selectedRole = role;
                      });
                    },
                  )).toList(),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => UserManagementPage(
                            username: widget.loggedInUsername
                        )));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300)
                        ),
                        child: const Icon(Icons.person_add_alt_1, color: Color(0xFF233E99)),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),

          // 3. User List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _userStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error fetching data: ${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("No users found for role: $_selectedRole"));
                }

                final filteredUsers = snapshot.data!.docs.where((doc) {
                  final userData = doc.data() as Map<String, dynamic>;
                  final username = userData['username'];
                  return username != currentLoggedInUsername;
                }).toList();

                if (filteredUsers.isEmpty) {
                  return Center(child: Text("No other users found for role: $_selectedRole"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    var userDoc = filteredUsers[index];
                    var userData = userDoc.data() as Map<String, dynamic>;
                    final String docId = userDoc.id;
                    final String itemUsername = userData['username'] ?? 'N/A';
                    final String itemRole = userData['role'] ?? 'Unknown Role';

                    return UserListItem(
                      username: itemUsername,
                      role: itemRole,
                      isActive: userData['status'] == 'Active',
                      profilePictureUrl: userData['profilePictureUrl'],
                      onDelete: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => UserDeletePage(
                          userId: docId,
                          loggedInUsername: widget.loggedInUsername,
                          username: itemUsername, userData: {},
                        )));
                      },
                      onEdit: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => UserEditPage(
                          userId: docId,
                          loggedInUsername: widget.loggedInUsername, username: null, userData: {},
                        )));
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF233E99),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Features'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outlined), label: 'Profile'),
        ],
      ),
    );
  }
}