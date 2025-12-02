import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Import untuk navigasi Features
import 'admin_features/profile_page.dart';
import 'admin_features/user_management_page.dart';
import 'admin_features/sales_page.dart';
import 'admin_features/report_page.dart';
import 'admin_page.dart';
import 'user_edit_page.dart';
import 'user_delete_page.dart';

class UserListPage extends StatefulWidget {
  final String loggedInUsername;

  const UserListPage({super.key, required this.loggedInUsername});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  String selectedRole = 'All';
  int totalUsersCount = 0;
  List<QueryDocumentSnapshot> users = [];
  String? adminProfilePictureUrl;

  @override
  void initState() {
    super.initState();
    fetchUsers();
    _fetchAdminProfilePicture();
  }

  // --- FUNGSI MUATKAN GAMBAR ADMIN (Dikekalkan) ---
  Future<void> _fetchAdminProfilePicture() async {
    try {
      QuerySnapshot adminSnap = await FirebaseFirestore.instance
          .collection("users")
          .where("username", isEqualTo: widget.loggedInUsername)
          .limit(1)
          .get();

      if (adminSnap.docs.isNotEmpty) {
        var userData = adminSnap.docs.first.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            adminProfilePictureUrl = userData['profilePictureUrl'];
          });
        }
      }
    } catch (e) {
      print("Error fetching admin profile picture: $e");
    }
  }

  // --- Fungsi Modal/Pop-up Features (Dikekalkan) ---
  void _showFeaturesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: 150,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _FeatureIcon(icon: Icons.person_outline, label: "Profile", page: ProfilePage(username: widget.loggedInUsername)),
                  _FeatureIcon(icon: Icons.group_add_outlined, label: "User Management", page: UserManagementPage(username: widget.loggedInUsername)),
                  _FeatureIcon(icon: Icons.trending_up, label: "Sales", page: SalesPage()),
                  _FeatureIcon(icon: Icons.bar_chart, label: "Report", page: ReportPage()),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Fungsi Mengambil Data dari Firestore ---
  Future<void> fetchUsers() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('users').get();

      setState(() {
        users = snapshot.docs;
        totalUsersCount = users.length;
      });
    } catch (e) {
      print("Error fetching users: $e");
    }
  }

  // --- Fungsi Filter Users ---
  List<QueryDocumentSnapshot> get filteredUsers {
    // 1. Tapis pengguna sedia ada untuk mengecualikan pengguna semasa (loggedInUsername)
    final List<QueryDocumentSnapshot> listWithoutCurrentUser = users.where((user) {
      final data = user.data() as Map<String, dynamic>;
      return data['username'] != widget.loggedInUsername;
    }).toList();

    // 2. Tapis berdasarkan Role yang dipilih
    if (selectedRole == 'All') {
      return listWithoutCurrentUser;
    }

    return listWithoutCurrentUser.where((user) {
      final data = user.data() as Map<String, dynamic>;
      return data['role'] == selectedRole.toLowerCase();
    }).toList();
  }

  // --- Widget Ikon Features Sekunder ---
  Widget _FeatureIcon({required IconData icon, required String label, required Widget page}) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF233E99), size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF233E99))),
        ],
      ),
    );
  }


  // --- Widget Item Pengguna dalam Senarai ---
  Widget _buildUserListItem(QueryDocumentSnapshot doc) {
    final userData = doc.data() as Map<String, dynamic>;
    final userId = doc.id;

    bool isActive = userData['status'] == 'Active';
    String role = userData['role'] ?? 'staff';
    String username = userData['username'] ?? 'Username Unknown';
    String statusLabel = isActive ? 'Active' : 'Disable';

    ImageProvider userAvatarImage = userData['profilePictureUrl'] != null && userData['profilePictureUrl']!.isNotEmpty
        ? CachedNetworkImageProvider(userData['profilePictureUrl']!) as ImageProvider
        : const AssetImage('assets/profile.png');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: userAvatarImage,
          backgroundColor: Colors.grey[200],
        ),
        title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(role.toUpperCase()),

        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Button
            ElevatedButton(
              onPressed: () { /* Tindakan Ubah Status */ },
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.green[600] : Colors.red[600],
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(statusLabel, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            const SizedBox(width: 8),

            // Ikon Aksi (Pensil / Tong Sampah)
            IconButton(
              icon: Icon(
                isActive ? Icons.edit_outlined : Icons.delete_outline,
                color: isActive ? Colors.grey : Colors.red,
              ),
              onPressed: () {
                if (isActive) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserEditPage(userData: userData, userId: userId, loggedInUsername: widget.loggedInUsername),
                    ),
                  ).then((_) => fetchUsers());
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserDeletePage(userData: userData, userId: userId, loggedInUsername: widget.loggedInUsername),
                    ),
                  ).then((_) => fetchUsers());
                }
              },
            ),
          ],
        ),
      ),
    );
  }


  // --- KANDUNGAN HEADER DAN FILTER ---
  Widget _buildHeader(ImageProvider adminAvatarImage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Penting untuk meletakkan butang +
      children: [
        // Header Manual (menggantikan AppBar) - BUANG ICON SEARCH
        Padding(
          padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 0),
          child: Row(
            children: [
              const BackButton(), // Butang Back (Anak Panah)

              // Avatar Admin
              CircleAvatar(radius: 18, backgroundImage: adminAvatarImage),
              const SizedBox(width: 8),
              Text(widget.loggedInUsername, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Spacer(),
              // IKON SEARCH & IKON FEATURES DIBUANG DARI SINI
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Card Total Users
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF233E99),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              const Icon(Icons.people_alt, color: Colors.white, size: 30),
              const SizedBox(width: 10),
              Text(
                totalUsersCount.toString(),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              const Text("Total Users", style: TextStyle(fontSize: 16, color: Colors.white70)),
            ],
          ),
        ),

        // Filter Buttons dan Butang Tambah Pengguna Baru
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter Buttons (Kekal)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['All', 'Admin', 'Staff', 'Manager'].map((role) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              selectedRole = role;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedRole == role ? const Color(0xFF233E99) : Colors.grey[200],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Text(
                            role,
                            style: TextStyle(
                              color: selectedRole == role ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // BUTANG TAMBAH PENGGUNA BARU (Ikon +)
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 1, blurRadius: 3),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF233E99)),
                  onPressed: () {
                    // Navigasi ke Halaman Pendaftaran Pengguna
                    Navigator.push(context, MaterialPageRoute(builder: (_) => UserManagementPage(username: widget.loggedInUsername)));
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    // Tentukan Image Provider berdasarkan URL gambar Admin
    ImageProvider adminAvatarImage = adminProfilePictureUrl != null && adminProfilePictureUrl!.isNotEmpty
        ? CachedNetworkImageProvider(adminProfilePictureUrl!) as ImageProvider
        : const AssetImage('assets/profile.png');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // PENTING: Gunakan Widget Header yang diperbaharui
          _buildHeader(adminAvatarImage),

          // Senarai Pengguna
          Expanded(
            child: ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                return _buildUserListItem(filteredUsers[index]);
              },
            ),
          ),
        ],
      ),

      // Bottom Navigation Bar (Dikekalkan)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          // Navigasi kembali ke AdminPage (Dashboard/Settings)
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => AdminPage(loggedInUsername: widget.loggedInUsername, initialIndex: index),
            ),
                (Route<dynamic> route) => false,
          );
        },
        selectedItemColor: const Color(0xFF233E99),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Features'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Setting'),
        ],
      ),
    );
  }
}