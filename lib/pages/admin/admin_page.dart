// File: admin/admin_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Import local pages
import 'user_list_page.dart';
import '../user_settings_page.dart';

// Import FeaturesGrid dari file terpisah
import 'features_grid.dart';
// Import Sales Page yang diperlukan
import 'admin_features/sales_page.dart';
// Import Modal dari folder utils BARU
import 'utils/features_modal.dart';


// --- 1. Widget MenuContainer (Header & Bingkai Putih) ---

class MenuContainer extends StatefulWidget {
  final Widget child;
  final String loggedInUsername;
  final VoidCallback onFeatureMenuPressed;

  const MenuContainer({
    super.key,
    required this.child,
    required this.loggedInUsername,
    required this.onFeatureMenuPressed,
  });

  @override
  State<MenuContainer> createState() => _MenuContainerState();
}

class _MenuContainerState extends State<MenuContainer> {
  String? _adminProfilePictureUrl;
  bool _isDataLoading = true;
  String _displayName = 'Administrator'; // Default display name
  static const double _avatarRadius = 18;

  @override
  void initState() {
    super.initState();
    _fetchAdminProfilePicture();
  }

  // FUNGSI MUATKAN GAMBAR ADMIN & DISPLAY NAME dari Firestore
  Future<void> _fetchAdminProfilePicture() async {
    // ... (Logika fetchAdminProfilePicture tetap sama)
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
            _displayName = userData['displayName'] ?? widget.loggedInUsername;
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
      if (mounted) {
        setState(() {
          _isDataLoading = false;
        });
      }
    }
  }

  // --- FUNGSI PEMBINA AVATAR YANG STABIL ---
  Widget buildAvatar() {
    if (_isDataLoading) {
      return const CircleAvatar(
        radius: _avatarRadius,
        backgroundColor: Colors.transparent,
        child: SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF233E99)),
        ),
      );
    }

    final bool isUrlValid = _adminProfilePictureUrl != null && _adminProfilePictureUrl!.isNotEmpty;

    if (isUrlValid) {
      return CachedNetworkImage(
        imageUrl: _adminProfilePictureUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: _avatarRadius,
          backgroundImage: imageProvider,
          backgroundColor: Colors.transparent,
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: _avatarRadius,
          backgroundColor: Colors.grey.shade300,
          child: const Icon(Icons.person, size: _avatarRadius, color: Colors.grey),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: _avatarRadius,
          backgroundColor: Colors.grey.shade300,
          child: const Icon(Icons.person, size: _avatarRadius, color: Colors.grey),
        ),
      );
    } else {
      return CircleAvatar(
        radius: _avatarRadius,
        backgroundColor: Colors.grey.shade300,
        child: const Icon(Icons.person, size: _avatarRadius, color: Colors.grey),
      );
    }
  }


  @override
  Widget build(BuildContext context) {

    return Column(
      children: [
        // Header Admin
        Padding(
          padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 8),
          child: Row(
            children: [
              // Avatar
              buildAvatar(),

              const SizedBox(width: 10),
              // Text Display Name yang sedang login
              Text(
                  _displayName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
              const Spacer(),
              // Ikon Search Dihapus untuk Konsistensi
              // IconButton(icon: const Icon(Icons.search), onPressed: () {}),
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
            child: widget.child,
          ),
        ),
      ],
    );
  }
}


// --- 2. DashboardCard (Dikekalkan) ---

class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final String growth;
  final IconData icon;
  final VoidCallback onViewPressed;

  const DashboardCard({
    super.key,
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
        color: const Color(0xFF233E99),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(width: 10),
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


// --- 3. AdminPageBody (Dikekalkan) ---

class AdminPageBody extends StatefulWidget {
  final String loggedInUsername;
  final bool showFeatureGrid;
  final VoidCallback onNavigateToUserList; // NEW: Callback untuk navigasi

  const AdminPageBody({
    super.key,
    required this.loggedInUsername,
    required this.showFeatureGrid,
    required this.onNavigateToUserList, // NEW
  });

  @override
  State<AdminPageBody> createState() => _AdminPageBodyState();
}

class _AdminPageBodyState extends State<AdminPageBody> {
  int totalUsers = 0;
  bool isLoading = true;

  // Nilai berdasarkan UI Gambar
  final int productTypes = 31;
  final int totalSuppliers = 19;
  final double userGrowth = 3.2;
  final double productGrowth = 5.1;
  final double supplierGrowth = 5.1;
  final String salesValue = "22,109";
  final String salesGrowth = "Last 3 days";

  @override
  void initState() {
    super.initState();
    fetchTotalUsers();
  }

  Future<void> fetchTotalUsers() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection("users").get();
      if (mounted) {
        setState(() {
          totalUsers = snapshot.docs.length;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          totalUsers = 0;
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MenuContainer(
      loggedInUsername: widget.loggedInUsername,
      onFeatureMenuPressed: () {
        FeaturesModal.show(context, widget.loggedInUsername);
      },
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
              // PERUBAHAN: Memanggil callback yang menunggu hasil
              onViewPressed: widget.onNavigateToUserList,
            ),
            const SizedBox(height: 20),

            // Card 2: Product Types
            DashboardCard(
              title: "Product Types",
              value: productTypes.toString(),
              growth: "+${productGrowth.toStringAsFixed(1)}% vs last month",
              icon: Icons.inventory_2,
              onViewPressed: () { /* Tindakan ke Product Page */ },
            ),
            const SizedBox(height: 20),

            // Card 3: Supplier
            DashboardCard(
              title: "Supplier",
              value: totalSuppliers.toString(),
              growth: "+${supplierGrowth.toStringAsFixed(1)}% vs last month",
              icon: Icons.local_shipping_outlined,
              onViewPressed: () { /* Tindakan ke Supplier Page */ },
            ),

            const SizedBox(height: 20),

            // KONDISIONAL: Paparkan Feature Grid atau Sales Card
            if (widget.showFeatureGrid)
              FeaturesGrid(loggedInUsername: widget.loggedInUsername)
            else
              DashboardCard(
                title: "Sales",
                value: "\$${salesValue}",
                growth: salesGrowth,
                icon: Icons.monetization_on_outlined,
                onViewPressed: () {
                  // Navigator.push(context, MaterialPageRoute(builder: (_) => SalesPage()));
                },
              ),
          ],
        ),
      ),
    );
  }
}


// --- 4. Kelas AdminPage Utama (Pengawal BottomBar) ---

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
    _currentIndex = widget.initialIndex == 1 ? 0 : widget.initialIndex;

    // Pages akan didefinisikan dalam build
  }

  // FUNGSI UTAMA: Navigasi dan Tunggu Hasil dari UserListPage
  void _navigateToUserListPage() async {
    // Tunggu hasil (iaitu, index baru dari UserListPage)
    final newIndex = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserListPage(
          loggedInUsername: widget.loggedInUsername,
        ),
      ),
    );

    // Jika hasil (newIndex) diterima, tukar tab di AdminPage
    if (newIndex != null && newIndex is int) {
      if (mounted && newIndex != _currentIndex) {
        setState(() {
          _currentIndex = newIndex; // Tukar tab (cth: dari 0 ke 2)
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Definisikan halaman dengan callback yang betul
    _pages = [
      AdminPageBody(
        loggedInUsername: widget.loggedInUsername,
        showFeatureGrid: false,
        onNavigateToUserList: _navigateToUserListPage, // Pass callback di sini
      ),
      AdminPageBody(loggedInUsername: widget.loggedInUsername, showFeatureGrid: false, onNavigateToUserList: () {}), // Index 1: Placeholder
      UserSettingsPage(username: widget.loggedInUsername, displayFullNavBar: false),  // Index 2: Setting
    ];


    const List<BottomNavigationBarItem> currentBottomNavItems = [
      BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Features'), // Index 1: Tombol Aksi Modal
      BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
    ];

    final int currentSelectedIndex = _currentIndex;


    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_currentIndex],

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentSelectedIndex,
        onTap: (index) {
          if (index == 1) {
            // JIKA FEATURES DIKLIK, SENTIASA PAPARKAN MODAL
            FeaturesModal.show(context, widget.loggedInUsername);
          } else {
            // NAVIGASI STANDARD untuk Home (0) dan Settings (2)
            setState(() {
              _currentIndex = index;
            });
          }
        },
        selectedItemColor: const Color(0xFF233E99),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: currentBottomNavItems,
      ),
    );
  }
}