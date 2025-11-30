import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart'; // [PENTING] Untuk gambar rangkaian

// Import halaman-halaman dalaman
import 'admin_features/user_management_page.dart';
import 'admin_features/profile_page.dart';
import 'admin_features/sales_page.dart';
import 'admin_features/report_page.dart';
import 'admin_settings_page.dart';
import 'user_list_page.dart'; // Halaman Senarai Pengguna (User List)


// --- 1. Widget Reusable untuk Struktur Halaman & Icons (DIUBAH KE STATEFUL) ---

class MenuContainer extends StatefulWidget {
  final Widget child;
  final String loggedInUsername;

  MenuContainer({
    super.key,
    required this.child,
    required this.loggedInUsername,
  });

  @override
  State<MenuContainer> createState() => _MenuContainerState();
}

class _MenuContainerState extends State<MenuContainer> {
  String? _adminProfilePictureUrl;
  bool _isDataLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAdminProfilePicture(); // [BARU] Mula fetching data
  }

  // FUNGSI BARU: Mengambil URL Gambar Profil Admin
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
            _adminProfilePictureUrl = userData['profilePictureUrl'];
            _isDataLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isDataLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching admin profile picture: $e");
      if (mounted) {
        setState(() {
          _isDataLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Tentukan Image Provider
    ImageProvider avatarImage = _adminProfilePictureUrl != null && _adminProfilePictureUrl!.isNotEmpty
        ? CachedNetworkImageProvider(_adminProfilePictureUrl!) as ImageProvider
        : const AssetImage('assets/profile.png');

    return Column(
      children: [
        // Header Admin
        Padding(
          padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 8),
          child: Row(
            children: [
              // [DIUBAH] Menggunakan gambar rangkaian
              CircleAvatar(
                radius: 18,
                backgroundImage: avatarImage, // Gunakan URL Gambar
                // Tambah loading indicator jika data masih dimuat
                child: _isDataLoading ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)
                ) : null,
              ),
              const SizedBox(width: 10),
              // PERUBAHAN: Memaparkan loggedInUsername
              Text(
                  widget.loggedInUsername,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
              const Spacer(),
              IconButton(icon: const Icon(Icons.search), onPressed: () {}),
            ],
          ),
        ),

        // Kotak Putih Utama (Kandungan Halaman)
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 5),
              ],
            ),
            child: widget.child, // Kandungan sebenar
          ),
        ),
      ],
    );
  }
}

// Widget untuk setiap ikon Features
class _FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget page;

  _FeatureIcon({required this.icon, required this.label, required this.page});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigasi ke halaman penuh
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF233E99), size: 28), // Warna Ikon Features
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF233E99))),
        ],
      ),
    );
  }
}


// --- 2. Halaman Admin Utama (Dashboard) ---

class AdminDashboard extends StatefulWidget {
  final String loggedInUsername;

  AdminDashboard({super.key, required this.loggedInUsername});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int totalUsers = 0;
  bool isLoading = true;

  // Data dummy (kekal)
  final int productTypes = 2500;
  final double userGrowth = 3.2;
  final double productGrowth = 5.1;

  @override
  void initState() {
    super.initState();
    fetchTotalUsers();
  }

  // FUNGSI BARU: Mengambil kiraan pengguna dari Firestore
  Future<void> fetchTotalUsers() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection("users").get();

      setState(() {
        totalUsers = snapshot.docs.length;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching total users: $e");
      setState(() {
        totalUsers = 0;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MenuContainer(
      loggedInUsername: widget.loggedInUsername,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            // Card 1: Total Users
            DashboardCard(
              title: "Total Users",
              value: isLoading ? '...' : totalUsers.toString(),
              growth: "+${userGrowth.toStringAsFixed(1)}% vs last week",
              icon: Icons.people_alt,
              onViewPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // Navigasi ke halaman senarai pengguna
                    builder: (_) => UserListPage(loggedInUsername: widget.loggedInUsername),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Card 2: Product Types (Kekal Dummy)
            DashboardCard(
              title: "Product Types",
              value: productTypes.toString(),
              growth: "+${productGrowth.toStringAsFixed(1)}% vs last month",
              icon: Icons.inventory_2,
              onViewPressed: () { /* Tindakan untuk View Product Types */ },
            ),
          ],
        ),
      ),
    );
  }
}

// Widget Reusable untuk Kad Dashboard
class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final String growth;
  final IconData icon;
  final VoidCallback onViewPressed; // Parameter untuk butang View

  DashboardCard({
    required this.title,
    required this.value,
    required this.growth,
    required this.icon,
    required this.onViewPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF233E99), // Warna biru gelap
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(width: 10),
              // Value (Kiraan)
              Text(
                value,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                growth,
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                onPressed: onViewPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("View", style: TextStyle(color: Color(0xFF233E99))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// --- 3. Kelas AdminPage Utama (Pengawal BottomBar) ---

class AdminPage extends StatefulWidget {
  final String loggedInUsername;
  final int initialIndex;

  const AdminPage({super.key, required this.loggedInUsername, this.initialIndex = 0});

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late int _currentIndex;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    // Index 1 (Features) menggunakan Dashboard sebagai placeholder
    _pages = [
      AdminDashboard(loggedInUsername: widget.loggedInUsername),
      AdminDashboard(loggedInUsername: widget.loggedInUsername),
      AdminSettingsPage(loggedInUsername: widget.loggedInUsername),
    ];
  }

  // WIDGET BAR ICON SEKUNDER
  Widget _buildFeatureIconBar(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _FeatureIcon(
            icon: Icons.person_outline,
            label: "Profile",
            page: ProfilePage(username: widget.loggedInUsername),
          ),
          _FeatureIcon(
            icon: Icons.group_add_outlined,
            label: "User Management",
            page: UserManagementPage(username: widget.loggedInUsername),
          ),
          _FeatureIcon(
            icon: Icons.trending_up,
            label: "Sales",
            page: SalesPage(),
          ),
          _FeatureIcon(
            icon: Icons.bar_chart,
            label: "Report",
            page: ReportPage(),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Kandungan Utama (Body)
          Padding(
            padding: const EdgeInsets.only(bottom: 80 + 56.0),
            child: _pages[_currentIndex],
          ),

          // 2. Ikon Bar Sekunder (Bar Features)
          if (_currentIndex == 1) // HANYA dipaparkan apabila tab Features aktif
            Positioned(
              bottom: 56, // Letakkan di atas BottomNavBar (yang ketinggiannya default 56)
              left: 0,
              right: 0,
              child: _buildFeatureIconBar(context),
            ),

          // 3. Bottom Navigation Bar (BottomNavBar)
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomNavigationBar(
              currentIndex: _currentIndex == 1 ? 1 : _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
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
          ),
        ],
      ),
    );
  }
}


// --- 4. Halaman Settings (Container Sederhana) ---

class AdminSettingsPage extends StatelessWidget {
  final String loggedInUsername;

  AdminSettingsPage({required this.loggedInUsername});

  @override
  Widget build(BuildContext context) {
    return MenuContainer(
      loggedInUsername: loggedInUsername,
      child: const Center(child: Text("Halaman Settings Admin")),
    );
  }
}