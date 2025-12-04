// File: user_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Import komponen yang diperlukan dari folder admin/
import 'utils/features_modal.dart';
// Import UserEdit/Delete pages 
import 'user_edit_page.dart';
import 'user_delete_page.dart';
// Import User Add Page
import 'admin_features/user_management_page.dart';


// FUNGSI BANTUAN UNTUK MEMUAT DATA PENGGUNA YANG SEDANG LOGIN (Diperlukan untuk Header)
Future<Map<String, dynamic>?> fetchLoggedInUserData(String username) async {
  try {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection("users")
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data() as Map<String, dynamic>;
    }
    return null;
  } catch (e) {
    print("Error fetching logged in user data: $e");
    return null;
  }
}


// --- Widget Kustom untuk UserListPage ---
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
            width: 130, // KOREKSI: Kurangkan lebar untuk menghindari overflow
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

                // KONDISI IKON AKSI
                if (isActive)
                // Ikon Pensel untuk Active user (Edit data/status)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey),
                    onPressed: onEdit,
                  )
                else
                // Ikon Sampah untuk Inactive user (Delete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onDelete, // Navigasi ke Delete Page
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget untuk Tab Filter (Dikekalkan)
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

  // FUNGSI KUNCI: Menangani Case-Sensitivity dan menghindari Indeks Komposit
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

  // FUNGSI untuk mendapatkan total user count (untuk Dashboard Card)
  Future<int> _fetchTotalUserCount() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection("users").get();
      return snapshot.docs.length;
    } catch (e) {
      print("Error fetching total user count: $e");
      return 0;
    }
  }


  // FUNGSI UNTUK MEMAPARKAN MODAL FEATURES
  void _showFeaturesModal() {
    FeaturesModal.show(context, widget.loggedInUsername);
  }

  // Navigasi BottomNavBar
  void _onItemTapped(int index) {
    if (index == 1) {
      // Index 1 (Features) sentiasa memaparkan modal
      _showFeaturesModal();
      return;
    }
    // Untuk navigasi Home dan Settings (0 dan 2), kita navigasi kembali ke AdminPage 
    // dan hantar index baru untuk memberitahu AdminPage untuk menukar tab.
    if (index == 0 || index == 2) {
      Navigator.pop(context, index);
    }
  }

  // Widget Bantuan untuk Avatar di AppBar
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
        // KOREKSI UTAMA: Header Dinamik
        title: FutureBuilder<Map<String, dynamic>?>(
          future: fetchLoggedInUserData(widget.loggedInUsername),
          builder: (context, snapshot) {
            String displayUsername = widget.loggedInUsername;
            String? profileUrl;
            String displayName = displayUsername;

            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data != null) {
              profileUrl = snapshot.data!['profilePictureUrl'];
              displayName = snapshot.data!['displayName'] ?? displayUsername;
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
        centerTitle: false, // Penting agar Row diletakkan di sebelah kiri
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [],
      ),

      body: Column(
        children: [
          // 1. Dashboard Card (Total Users - KINI DINAMIK)
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF233E99),
                borderRadius: BorderRadius.circular(15),
              ),
              child: FutureBuilder<int>(
                future: _fetchTotalUserCount(),
                builder: (context, snapshot) {
                  String displayCount = snapshot.data?.toString() ?? '...';

                  if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                    displayCount = snapshot.data!.toString();
                  } else if (snapshot.hasError) {
                    displayCount = '0';
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

          // 2. Filter Tabs (Kekal sama)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Role Filters
                  ..._roles.map((role) => RoleFilterTab(
                    label: role,
                    isSelected: _selectedRole == role,
                    onTap: () {
                      setState(() {
                        _selectedRole = role;
                      });
                    },
                  )).toList(),
                  // Icon tambah pengguna
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: GestureDetector( // <<< ACTION NAVIGASI TAMBAH PENGGUNA
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

          // 3. User List (Firebase Stream)
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

                // CLIENT-SIDE FILTERING (MENGEKECUALIKAN PENGGUNA LOGIN)
                final filteredUsers = snapshot.data!.docs.where((doc) {
                  final userData = doc.data() as Map<String, dynamic>;
                  final username = userData['username'];
                  return username != currentLoggedInUsername;
                }).toList();

                if (filteredUsers.isEmpty) {
                  return Center(child: Text("No other users found for role: $_selectedRole"));
                }

                return ListView.builder(
                  // KOREKSI 2: Kurangkan padding horizontal untuk mengelakkan overflow
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

                      // ON DELETE (ICON SAMPAH) -> Navigasi ke Delete Page
                      onDelete: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => UserDeletePage(
                          userId: docId,
                          loggedInUsername: widget.loggedInUsername,
                          username: itemUsername, userData: {},
                        )));
                      },

                      // ON EDIT (ICON PENSEL) -> Navigasi ke Edit Page
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

      // BOTTOM NAVIGATION BAR (Logika pop kembali ke AdminPage Index 2)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF233E99),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Features'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}