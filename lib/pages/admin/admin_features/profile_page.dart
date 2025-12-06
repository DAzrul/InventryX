// profile_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // [BARU] Import untuk semakan rangkaian

import '../../../pages/login_page.dart';
import 'change_password_profile.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  final String username;

  const ProfilePage({super.key, required this.username});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneNoController = TextEditingController();
  final TextEditingController companyController = TextEditingController(); // Digunakan untuk Name Company

  String? currentUserId;
  String userRole = '';
  String userPosition = '';
  bool isLoading = true;
  String? profilePictureUrl;

  List<Map<String, dynamic>> realActivityData = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // --- [BARU] FUNGSI SEMAK RANGKAIAN ---
  Future<bool> _isNetworkAvailable() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  // FUNGSI PEMBANTU: Untuk format Firestore Timestamp ke "X time ago"
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';

    final duration = DateTime.now().difference(timestamp.toDate());
    if (duration.inMinutes < 1) return 'Just now';
    if (duration.inMinutes < 60) return '${duration.inMinutes} mins ago';
    if (duration.inHours < 24) return '${duration.inHours} hours ago';
    if (duration.inDays < 7) return '${duration.inDays} days ago';

    return '${timestamp.toDate().month}/${timestamp.toDate().day}/${timestamp.toDate().year}';
  }


  // --- Fungsi Mengambil Data Pengguna dan Aktiviti dari Firestore (DIPERBAIKI) ---
  Future<void> _loadUserProfile() async {
    // [LANGKAH 0: SEMAK RANGKAIAN]
    final isOnline = await _isNetworkAvailable();

    try {
      // Pilihan: Tambah 'source: Source.cache' jika offline di sini untuk memuatkan cache dahulu.
      // Walau bagaimanapun, kita bergantung pada caching automatik Firestore.

      QuerySnapshot userSnap = await FirebaseFirestore.instance
          .collection("users")
          .where("username", isEqualTo: widget.username)
          .limit(1)
          .get();

      if (userSnap.docs.isNotEmpty) {
        var userData = userSnap.docs.first.data() as Map<String, dynamic>;
        String userId = userSnap.docs.first.id;

        // FUNGSI 1: AMBIL DATA AKTIVITI SEBENAR
        QuerySnapshot activitySnap;
        if (isOnline) {
          // Hanya muatkan log aktiviti jika online
          activitySnap = await FirebaseFirestore.instance
              .collection("users").doc(userId)
              .collection("activities")
              .orderBy('timestamp', descending: true)
              .limit(4)
              .get();
        } else {
          // Jika offline, guna senarai kosong untuk mengelakkan ralat load
          activitySnap = await FirebaseFirestore.instance.collection("users").doc(userId).collection("activities").get(const GetOptions(source: Source.cache));
          // Jika cache aktiviti tidak wujud, biarkan kosong.
        }

        // Memproses aktiviti
        List<Map<String, dynamic>> tempActivities = [];
        for (var doc in activitySnap.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String timeAgo = _formatTimestamp(data['timestamp']);
          tempActivities.add({
            'icon': IconData(data['iconCode'] ?? Icons.info_outline.codePoint, fontFamily: 'MaterialIcons'),
            'text': data['description'] ?? 'Activity recorded.',
            'time': timeAgo,
          });
        }

        // ... (Logik set state untuk data profil) ...
        if(mounted) {
          setState(() {
            currentUserId = userId;
            nameController.text = userData['name'] ?? 'N/A';
            emailController.text = userData['email'] ?? 'N/A';
            phoneNoController.text = userData['phoneNo'] ?? 'N/A';
            userRole = userData['role'] ?? 'N/A';
            userPosition = userData['position'] ?? 'N/A';
            companyController.text = userData['nameCompany'] ?? 'N/A';
            profilePictureUrl = userData['profilePictureUrl'];
            realActivityData = tempActivities;
            isLoading = false;
          });
        }

        // BERI AMARAN JIKA OFFLINE
        if (!isOnline && mounted) {
          _showPopupMessage("Offline Mode", "Displaying cached data. Latest activity logs may be unavailable.");
        }

      } else {
        if(mounted) {
          setState(() {
            isLoading = false;
          });
        }
        if (isOnline) {
          _showPopupMessage("Warning", "User data not found. Displaying dummy data.");
        }
      }
    } catch (e) {
      if(mounted) {
        setState(() {
          isLoading = false;
        });
      }
      print("Error loading user data: $e");
      if (isOnline) {
        _showPopupMessage("Error Loading Data", e.toString());
      }
    }
  }

  // --- Fungsi Navigasi Edit Profile ---
  void _editProfile() async {
    // ... (Semakan ID dan Panggilan Navigasi kekal sama) ...
    if (currentUserId == null || isLoading) {
      _showPopupMessage("Error", "User data is still loading or ID not available.");
      return;
    }

    // [BARU] Semakan Rangkaian sebelum edit
    if (!await _isNetworkAvailable()) {
      _showPopupMessage("Offline Mode", "You must be online to edit your profile.");
      return;
    }

    final Map<String, String> dataToEdit = {
      'name': nameController.text,
      'email': emailController.text,
      'phoneNo': phoneNoController.text,
      'role': userRole,
      'profilePictureUrl': profilePictureUrl ?? '',
      'nameCompany': companyController.text,
      'position': userPosition,
    };

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(
          userId: currentUserId!,
          username: widget.username,
          initialData: dataToEdit,
        ),
      ),
    );

    if (result == true) {
      await _loadUserProfile();
      _showPopupMessage("Success! 🎉", "Profile updated successfully.");
    }
  }

  // --- Fungsi Logout (Memadam Sesi) (DIPERBAIKI) ---
  void _logout() async {
    final isOnline = await _isNetworkAvailable();

    // 1. Log Aktiviti (Hanya jika online)
    if (isOnline) {
      try {
        await FirebaseFirestore.instance
            .collection('users').doc(currentUserId!)
            .collection('activities').add({
          'timestamp': FieldValue.serverTimestamp(),
          'description': 'Signed out of account.',
          'iconCode': Icons.logout.codePoint,
        });
      } catch (e) {
        print('Failed to log logout activity: $e');
      }
    }

    // 2. Padamkan status 'Remember Me' (shared_preferences)
    await LoginPage.clearLoginState();

    // 3. Log keluar dari Firebase Authentication
    // Log keluar Auth adalah asynchronous, tetapi Auth SDK biasanya berfungsi dengan baik offline untuk clear credentials.
    await FirebaseAuth.instance.signOut();

    // 4. Semak mounted sebelum menggunakan context
    if (!mounted) return;

    // 5. Navigasi ke halaman Login dan kosongkan stack
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
    );
  }

  // --- FUNGSI BARU: Change Account ---
  void _changeAccount() {
    _confirmChangeAccount();
  }

  // Fungsi Popup Mesej
  void _showPopupMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }

  // --- FUNGSI BARU: Pengesahan Sebelum Log Keluar ---
  void _confirmChangeAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Session End ⚠️"),
        content: const Text("Are you sure you want to end the current session to change accounts? You will be taken back to the login screen."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Tutup dialog
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Tutup dialog pengesahan
              _logout(); // Teruskan log keluar yang selamat
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            child: const Text("Continue", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Widget untuk Item Maklumat Kenalan
  Widget _buildContactItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 15),
          Flexible(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  // Widget untuk Butang Aksi Pantas
  Widget _buildQuickActionButton({required IconData icon, required String label, required VoidCallback onPressed, Color? color}) {
    return Container(
      width: double.infinity,
      height: 55,
      margin: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color ?? const Color(0xFF233E99)),
        label: Text(label, style: TextStyle(color: color ?? Colors.black87, fontSize: 16)),
        style: OutlinedButton.styleFrom(
          backgroundColor: color != Colors.red[700] ? Colors.white : Colors.red[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: BorderSide(color: color == Colors.red[700] ? Colors.red[700]! : Colors.grey[300]!),
        ),
      ),
    );
  }

  // Widget Pembinaan ExpansionTile (Accordion)
  Widget _buildExpansionTile({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.grey[700]),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        children: children,
      ),
    );
  }

  // Widget Pembinaan Aktiviti (Di dalam accordion)
  Widget _buildActivityAccordion({required String title, required List<Map<String, dynamic>> activities, required bool showDropdownIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 16),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),

        // List of activities
        ...activities.map((activity) =>
            ListTile(
              contentPadding: EdgeInsets.zero,
              // Menggunakan IconData dari Firestore
              leading: Icon(activity['icon'], color: Colors.grey[700]),
              title: Text(activity['text'], style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              trailing: Text(activity['time'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
            )
        ).toList(),
        const SizedBox(height: 10),
      ],
    );
  }

  // Fungsi untuk memaparkan modal Change Password (Dikekalkan)
  void _showChangePasswordModal() async {
    // ... (Logik Semakan ID kekal sama) ...
    if (currentUserId == null) {
      _showPopupMessage("Error", "User ID not loaded yet.");
      return;
    }

    // [BARU] Semakan Rangkaian sebelum change password
    if (!await _isNetworkAvailable()) {
      _showPopupMessage("Offline Mode", "You must be online to change your password.");
      return;
    }

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: ChangePasswordProfilePage(
            username: widget.username,
            userId: currentUserId!,
          ),
        );
      },
    );

    // MENGENDALIKAN HASIL dari ChangePasswordProfilePage
    if (result != null) {
      if (result == 'success') {
        _showPopupMessage("Success! 🎉", "Password updated successfully.");
      } else if (result == 'fail') {
        _showPopupMessage("Update Failed ❌", "The old password was incorrect or a system error occurred. Please try again.");
      }
    }
  }

  // --- END WIDGET PEMBANTU ---


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        appBar: null,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("User Profile", style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- HEADER PROFIL (Gambar & Nama) ---
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    // Logik untuk memaparkan gambar
                    backgroundImage: profilePictureUrl != null && profilePictureUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(profilePictureUrl!) as ImageProvider
                        : const AssetImage('assets/profile.png'),
                    child: (profilePictureUrl == null || profilePictureUrl!.isEmpty) && !isLoading
                        ? const Icon(Icons.person, size: 40, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    nameController.text,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    userRole,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 1. CONTACT INFORMATION ---
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                // [PEMBETULAN KRITIKAL] Menggunakan parameter 'boxShadow' yang betul
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Contact Information", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 20),
                  _buildContactItem(icon: Icons.email_outlined, text: emailController.text),
                  _buildContactItem(icon: Icons.phone_outlined, text: phoneNoController.text),
                  _buildContactItem(icon: Icons.business_outlined, text: companyController.text),
                  _buildContactItem(icon: Icons.work_outline, text: userPosition),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- 2. QUICK ACTIONS ---
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Quick Action", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 20),
                  const SizedBox(height: 10),

                  // Change Password Button
                  _buildQuickActionButton(
                    icon: Icons.key_outlined,
                    label: "Change Password",
                    onPressed: _showChangePasswordModal,
                  ),

                  // Change Account Button -> Placeholder
                  _buildQuickActionButton(
                    icon: Icons.group_outlined,
                    label: "Change Account",
                    onPressed: _changeAccount, // Panggil fungsi _changeAccount yang kini memaparkan dialog
                  ),

                  // Logout Button (Merah)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _logout, // Panggil fungsi _logout yang telah diperbaiki
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text("Log Out", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 3. ACTIVITY & SETTINGS (Accordion/Expandable) ---
            _buildExpansionTile(
              title: "Profile",
              icon: Icons.person_outline,
              children: [
                _buildActivityAccordion(
                  title: "Latest Activity",
                  activities: realActivityData, // Guna data aktiviti sebenar dari Firestore
                  showDropdownIcon: false,
                ),
              ],
            ),
            _buildExpansionTile(
              title: "Safety",
              icon: Icons.security_outlined,
              children: const [
                ListTile(
                  dense: true,
                  title: Text("Two-Factor Authentication"),
                  trailing: Icon(Icons.chevron_right),
                )
              ],
            ),
            _buildExpansionTile(
              title: "Notification",
              icon: Icons.notifications_none,
              children: [
                ListTile(
                  dense: true,
                  title: const Text("Email Notifications"),
                  trailing: Switch(value: true, onChanged: (val){}),
                )
              ],
            ),

            const SizedBox(height: 100), // Padding bawah
          ],
        ),
      ),
    );
  }
}