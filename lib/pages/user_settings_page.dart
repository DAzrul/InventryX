// File: lib/pages/user_settings_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart'; // [BARU] Import Hive

// Import dependencies (Path disesuaikan)
import '../main.dart'; // [BARU] Import themeNotifier dari main.dart
import 'login_page.dart'; // [BARU] Import clearLoginState dari login_page.dart
import 'admin/admin_features/dummy_pages.dart';
import 'admin/admin_features/profile_page.dart';
import 'admin/features_grid.dart'; // Perlu ganti dengan import sebenar untuk Page-page ini

// --- [BARU] Nama Box Hive yang Digunakan ---
const String SETTINGS_BOX = 'settingsBox'; // Box untuk menyimpan tetapan sistem

// Widget Reusable untuk Item Menu
class _SettingsMenuItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? destinationPage;
  final Widget? trailingWidget;
  final VoidCallback? onTap; // [UBAH] Tambah onTap untuk tindakan custom

  const _SettingsMenuItem({
    required this.title,
    required this.icon,
    this.destinationPage,
    this.trailingWidget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool hasArrow = destinationPage != null && trailingWidget == null;

    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey.shade700),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: trailingWidget ?? (hasArrow ? const Icon(Icons.arrow_forward_ios, size: 16) : null),
      onTap: onTap ?? (destinationPage != null
          ? () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => destinationPage!));
      }
          : null),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

// Widget Bantuan untuk Avatar Profil (Tidak diubah)
Widget _buildProfileAvatar(String? profilePictureUrl) {
  const double radius = 40;
  final bool isUrlValid = profilePictureUrl != null && profilePictureUrl.isNotEmpty;

  if (isUrlValid) {
    return CachedNetworkImage(
      imageUrl: profilePictureUrl!,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
        backgroundColor: Colors.transparent,
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade300,
        child: Icon(Icons.person, size: radius, color: Colors.grey),
      ),
      placeholder: (context, url) => CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade300,
        child: Icon(Icons.person, size: radius, color: Colors.grey),
      ),
    );
  } else {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade300,
      child: Icon(Icons.person, size: radius, color: Colors.grey),
    );
  }
}

// --- Fungsi Sign Out yang Dipindahkan ke Stateful Widget ---
// (Fungsi ini akan dipindahkan ke dalam _UserSettingsPageState)

// --- Fungsi untuk Membangun Konten Settings Utama (Diubah suai untuk menerima callback) ---
Widget _buildSettingsContent(
    BuildContext context,
    String username,
    Map<String, dynamic> userData,
    bool isDarkModeEnabled, // [BARU] Terima status Dark Mode
    ValueChanged<bool> onDarkModeToggle, // [BARU] Terima callback toggle
    VoidCallback onSignOut, // [BARU] Terima callback Sign Out
    ) {
  final String displayName = userData['displayName'] ?? username;
  final String email = userData['email'] ?? 'No email available';
  final String? profilePictureUrl = userData['profilePictureUrl'];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // --- 1. User Profile Header ---
      Center(
        child: Column(
          children: [
            _buildProfileAvatar(profilePictureUrl),
            const SizedBox(height: 8),
            Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(email, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 15),
            const SizedBox(height: 25),
          ],
        ),
      ),

      // --- 2. Account Management ---
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Text("Account Management", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF233E99))),
      ),
      _SettingsMenuItem(title: "My Account", icon: Icons.person_outline, destinationPage: ProfilePage(username: username)),
      const _SettingsMenuItem(title: "Privacy & Security", icon: Icons.lock_outline, destinationPage: PrivacySecurityPage()),
      const Divider(height: 20),

      // --- 3. System Settings (Integrasi HIVE) ---
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Text("System Settings", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF233E99))),
      ),
      _SettingsMenuItem(title: "Notification", icon: Icons.notifications_none, destinationPage: DummyPage()),
      _SettingsMenuItem(title: "Language", icon: Icons.language, destinationPage: DummyPage()),

      // ITEM DARK MODE DENGAN HIVE
      _SettingsMenuItem(
        title: "Dark Mode",
        icon: Icons.light_mode,
        trailingWidget: Switch(
          value: isDarkModeEnabled,
          onChanged: onDarkModeToggle, // Panggil callback toggle
          activeColor: const Color(0xFF233E99),
        ),
      ),
      const Divider(height: 20),

      // --- 4. Support ---
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Text("Support", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF233E99))),
      ),
      const _SettingsMenuItem(title: "Terms of Service", icon: Icons.description_outlined, destinationPage: TermsOfServicePage()),
      const _SettingsMenuItem(title: "InventoryX FAQ", icon: Icons.live_help_outlined, destinationPage: InventoryFAQPage()),
      const Divider(height: 20),

      // --- 5. Sign Out Button (Integrasi SharedPreferences) ---
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: OutlinedButton.icon(
              onPressed: onSignOut, // Panggil callback Sign Out
              icon: const Icon(Icons.logout, size: 20, color: Colors.red),
              label: const Text("Sign Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Colors.red, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
      ),

      // Versi Aplikasi
      Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 40),
          child: Text("InventoryX 1.0.0", style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ),
      ),
    ],
  );
}


class UserSettingsPage extends StatefulWidget {
  final String username;
  final bool displayFullNavBar;
  final String userId;

  const UserSettingsPage({
    super.key,
    required this.username,
    required this.displayFullNavBar,
    required this.userId,
  });

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  bool _isDarkModeEnabled = false; // [BARU] State untuk Dark Mode

  // --- HIVE BOX ---
  late final Box _settingsBox;

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box(SETTINGS_BOX); // Buka box yang telah diinisialisasi di main.dart
    _loadSettings();
    _fetchUserData();
  }

  // --- HIVE: Muatkan status Dark Mode ---
  void _loadSettings() {
    _isDarkModeEnabled = _settingsBox.get('darkMode', defaultValue: false);
  }

  // --- HIVE: Fungsi untuk toggle Dark Mode ---
  void _toggleDarkMode(bool value) async {
    setState(() {
      _isDarkModeEnabled = value;
    });

    // 1. Simpan status ke Hive
    await _settingsBox.put('darkMode', value);

    // 2. Kemaskini tema global (themeNotifier dari main.dart)
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;

    // 3. (Pilihan) Kemaskini SharedPreferences juga, jika anda menggunakan SP untuk theme awal di main.dart
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setBool('darkMode', value);
  }

  // --- Logik Sign Out ---
  void _handleSignOut() async {
    // 1. Bersihkan status sesi (dari LoginPage)
    await LoginPage.clearLoginState();

    // 2. Navigasi kembali ke LaunchPage (atau LoginPage)
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()), // Kembali ke Login
            (Route<dynamic> route) => false, // Buang semua route di stack
      );
    }
  }


  // Mengambil data pengguna dari Firestore berdasarkan username yang login
  Future<void> _fetchUserData() async {
    try {
      // Pilihan: Guna widget.userId untuk dokumen lookup yang lebih pantas, jika userId adalah Doc ID
      QuerySnapshot userSnap = await FirebaseFirestore.instance
          .collection("users")
          .where("username", isEqualTo: widget.username)
          .limit(1)
          .get();

      if (userSnap.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _userData = userSnap.docs.first.data() as Map<String, dynamic>;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user data for settings: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              // Hantar data pengguna sebenar dan callbacks ke widget konten
              child: _buildSettingsContent(
                context,
                widget.username,
                _userData,
                _isDarkModeEnabled, // Hantar status Dark Mode semasa
                _toggleDarkMode, // Hantar fungsi toggle Dark Mode
                _handleSignOut, // Hantar fungsi Sign Out
              ),
            ),
          ],
        ),
      ),
    );
  }
}