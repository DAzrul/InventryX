import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Import dependencies
import '../../../pages/login_page.dart';
import 'change_password_profile.dart';
import 'edit_profile_page.dart';

// ==========================================================
// KELAS WIDGET PEMBANTU
// ==========================================================

// --- 1. USER PROFILE HEADER WIDGET ---
class UserProfileHeader extends StatelessWidget {
  final String username;
  final String role;
  final String? profilePictureUrl;

  const UserProfileHeader({
    super.key,
    required this.username,
    required this.role,
    this.profilePictureUrl
  });

  @override
  Widget build(BuildContext context) {
    final ImageProvider? imageProvider = profilePictureUrl != null && profilePictureUrl!.isNotEmpty
        ? CachedNetworkImageProvider(profilePictureUrl!)
        : null;

    final bool isPlaceholder = profilePictureUrl == null || profilePictureUrl!.isEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey[300],
            backgroundImage: imageProvider,
            child: isPlaceholder
                ? Icon(Icons.person, size: 40, color: Colors.grey[600])
                : null,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: Text(
              username.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            role,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// --- 2. CONTACT INFORMATION WIDGET ---
class ContactInformationSection extends StatelessWidget {
  final String name;
  final String email;
  final String phoneNo;

  const ContactInformationSection({
    super.key,
    required this.name,
    required this.email,
    required this.phoneNo,
  });

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Contact Information", style: TextStyle(fontWeight: FontWeight.bold)),
          const Divider(height: 20),
          _buildContactItem(icon: Icons.account_circle_outlined, text: name),
          _buildContactItem(icon: Icons.email_outlined, text: email),
          _buildContactItem(icon: Icons.phone_outlined, text: phoneNo),
        ],
      ),
    );
  }
}

// --- 3. QUICK ACTIONS WIDGET (Dikemaskini: Buang Switch Account) ---
class QuickActionsSection extends StatelessWidget {
  final VoidCallback onChangePassword;
  final VoidCallback onLogout; // Kekalkan Logout sahaja

  const QuickActionsSection({
    super.key,
    required this.onChangePassword,
    required this.onLogout
  });

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Quick Action", style: TextStyle(fontWeight: FontWeight.bold)),
          const Divider(height: 20),
          const SizedBox(height: 10),

          // Butang Change Password
          _buildQuickActionButton(
            icon: Icons.key_outlined,
            label: "Change Password",
            onPressed: onChangePassword,
          ),

          // Butang Log Out
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: onLogout,
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
    );
  }
}

// ==========================================================
// KELAS UTAMA PROFILE PAGE
// ==========================================================

class ProfilePage extends StatefulWidget {
  final String username;

  const ProfilePage({super.key, required this.username});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Controllers
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneNoController = TextEditingController();

  String? currentUserId;
  String userRole = '';
  bool isLoading = true;
  String? profilePictureUrl;

  List<Map<String, dynamic>> realActivityData = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<bool> _isNetworkAvailable() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final duration = DateTime.now().difference(timestamp.toDate());
    if (duration.inMinutes < 1) return 'Just now';
    if (duration.inMinutes < 60) return '${duration.inMinutes} mins ago';
    if (duration.inHours < 24) return '${duration.inHours} hours ago';
    if (duration.inDays < 7) return '${duration.inDays} days ago';
    return '${timestamp.toDate().month}/${timestamp.toDate().day}/${timestamp.toDate().year}';
  }

  Future<void> _loadUserProfile() async {
    final isOnline = await _isNetworkAvailable();

    try {
      QuerySnapshot userSnap = await FirebaseFirestore.instance
          .collection("users")
          .where("username", isEqualTo: widget.username)
          .limit(1)
          .get();

      if (userSnap.docs.isNotEmpty) {
        var userData = userSnap.docs.first.data() as Map<String, dynamic>;
        String userId = userSnap.docs.first.id;

        QuerySnapshot activitySnap;
        if (isOnline) {
          activitySnap = await FirebaseFirestore.instance
              .collection("users").doc(userId)
              .collection("activities")
              .orderBy('timestamp', descending: true)
              .limit(4)
              .get();
        } else {
          activitySnap = await FirebaseFirestore.instance.collection("users").doc(userId).collection("activities").get(const GetOptions(source: Source.cache));
        }

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

        if(mounted) {
          setState(() {
            currentUserId = userId;
            usernameController.text = userData['username'] ?? 'N/A';
            nameController.text = userData['name'] ?? 'N/A';
            emailController.text = userData['email'] ?? 'N/A';
            phoneNoController.text = userData['phoneNo'] ?? 'N/A';
            userRole = userData['role'] ?? 'N/A';
            profilePictureUrl = userData['profilePictureUrl'];
            realActivityData = tempActivities;
            isLoading = false;
          });
        }

      } else {
        if(mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      if(mounted) setState(() => isLoading = false);
      print("Error loading user data: $e");
    }
  }

  void _editProfile() async {
    if (currentUserId == null || isLoading) return;

    if (!await _isNetworkAvailable()) {
      _showPopupMessage("Offline Mode", "You must be online to edit your profile.");
      return;
    }

    final Map<String, String> dataToEdit = {
      'username': usernameController.text,
      'name': nameController.text,
      'email': emailController.text,
      'phoneNo': phoneNoController.text,
      'role': userRole,
      'profilePictureUrl': profilePictureUrl ?? '',
    };

    // [PENTING] Guna showModalBottomSheet untuk effect Popup & Swipe Down
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: EditProfilePage(
              userId: currentUserId!,
              username: widget.username,
              initialData: dataToEdit,
            ),
          ),
        );
      },
    );

    // Refresh data jika edit berjaya
    if (result == true) {
      await _loadUserProfile();
      _showPopupMessage("Success! 🎉", "Profile updated successfully.");
    }
  }

  void _logout() async {
    final isOnline = await _isNetworkAvailable();
    if (isOnline && currentUserId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users').doc(currentUserId!)
            .collection('activities').add({
          'timestamp': FieldValue.serverTimestamp(),
          'description': 'Signed out of account.',
          'iconCode': Icons.logout.codePoint,
        });
      } catch (e) {}
    }

    await LoginPage.clearLoginState();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
    );
  }

  // [DIHAPUS] Fungsi _changeAccount dan _showAccountSwitcherDialog telah dibuang kerana tidak digunakan

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

  Widget _buildActivityAccordion({required String title, required List<Map<String, dynamic>> activities, required bool showDropdownIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 16),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ...activities.map((activity) =>
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(activity['icon'], color: Colors.grey[700]),
              title: Text(activity['text'], style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              trailing: Text(activity['time'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
            )
        ).toList(),
        const SizedBox(height: 10),
      ],
    );
  }

  void _showChangePasswordModal() async {
    if (currentUserId == null) return;
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

    if (result != null) {
      if (result == 'success') {
        _showPopupMessage("Success! 🎉", "Password updated successfully.");
      } else if (result == 'fail') {
        _showPopupMessage("Update Failed ❌", "Incorrect password or system error.");
      }
    }
  }

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
        automaticallyImplyLeading: false,
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
            UserProfileHeader(
              username: usernameController.text,
              role: userRole,
              profilePictureUrl: profilePictureUrl,
            ),
            const SizedBox(height: 20),
            ContactInformationSection(
              name: nameController.text,
              email: emailController.text,
              phoneNo: phoneNoController.text,
            ),
            const SizedBox(height: 20),
            QuickActionsSection(
              onChangePassword: _showChangePasswordModal,
              // onChangeAccount telah dibuang
              onLogout: _logout,
            ),
            const SizedBox(height: 20),
            _buildExpansionTile(
              title: "Profile",
              icon: Icons.person_outline,
              children: [
                _buildActivityAccordion(
                  title: "Latest Activity",
                  activities: realActivityData,
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
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}