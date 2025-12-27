import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../login_page.dart';
import 'change_password_profile.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  final String username;
  const ProfilePage({super.key, required this.username});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Color primaryColor = const Color(0xFF233E99);
  String? currentUserId;
  String userRole = '';
  String? profilePictureUrl;
  Map<String, String> userData = {};

  // --- LOGIC: STREAM FOR LATEST ACTIVITY ---
  Stream<QuerySnapshot> _activityStream(String uid) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("activities")
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots();
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return 'Just now';
    return DateFormat('dd MMM, hh:mm a').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    // REAL-TIME STREAM: No more manual refresh lag mat!
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .where("username", isEqualTo: widget.username)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Scaffold(body: Center(child: Text("Connection Error!")));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Auto-update variables whenever database changes
        var doc = snapshot.data!.docs.first;
        var data = doc.data() as Map<String, dynamic>;
        currentUserId = doc.id;
        profilePictureUrl = data['profilePictureUrl'];
        userRole = data['role'] ?? 'STAFF';
        userData = {
          'username': data['username'] ?? 'N/A',
          'name': data['name'] ?? 'N/A',
          'email': data['email'] ?? 'N/A',
          'phoneNo': data['phoneNo'] ?? 'N/A',
        };

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FD),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text("User Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildProfileHeader(),
                const SizedBox(height: 25),

                _buildSectionTitle("Contact Information"),
                _buildInfoCard(),

                const SizedBox(height: 25),
                _buildSectionTitle("Account Settings"),

                _buildSettingsTile(
                  title: "Security & Safety",
                  icon: Icons.security_rounded,
                  children: [
                    _buildSubTile("Change Password", Icons.key_rounded, _showChangePasswordModal),
                    _buildSubTile("Two-Factor Authentication", Icons.vibration_rounded, null),
                  ],
                ),

                _buildSettingsTile(
                  title: "Latest Activity Logs",
                  icon: Icons.history_rounded,
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: _activityStream(currentUserId!),
                      builder: (context, activitySnap) {
                        if (!activitySnap.hasData || activitySnap.data!.docs.isEmpty) {
                          return const Padding(padding: EdgeInsets.all(20), child: Text("No recent activity.", style: TextStyle(color: Colors.grey)));
                        }
                        return Column(
                          children: activitySnap.data!.docs.map((doc) {
                            var d = doc.data() as Map<String, dynamic>;
                            return _buildActivityTile({
                              'icon': Icons.info_outline_rounded,
                              'description': d['description'] ?? 'Activity recorded.',
                              'time': _formatTimestamp(d['timestamp'] as Timestamp?),
                            });
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                _buildLogoutButton(),
                const SizedBox(height: 120),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- UI COMPONENTS (Kekal Consistent & Modern) ---

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryColor.withValues(alpha: 0.1), width: 4)
              ),
              child: CircleAvatar(
                radius: 50, backgroundColor: Colors.white,
                backgroundImage: (profilePictureUrl != null && profilePictureUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(profilePictureUrl!) : null,
                child: (profilePictureUrl == null || profilePictureUrl!.isEmpty)
                    ? Icon(Icons.person_rounded, size: 55, color: primaryColor.withValues(alpha: 0.4)) : null,
              ),
            ),
            GestureDetector(
              onTap: _editProfile,
              child: CircleAvatar(radius: 18, backgroundColor: primaryColor, child: const Icon(Icons.edit_rounded, size: 16, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Text(userData['name'] ?? 'N/A', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(userRole.toUpperCase(), style: TextStyle(fontSize: 12, color: Colors.grey[500], letterSpacing: 1.5, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]),
      child: Column(
        children: [
          _buildInfoRow(Icons.alternate_email_rounded, "Username", userData['username'] ?? 'N/A'),
          _buildInfoRow(Icons.email_outlined, "Email Address", userData['email'] ?? 'N/A'),
          _buildInfoRow(Icons.phone_android_rounded, "Phone Number", userData['phoneNo'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: primaryColor, size: 22),
          title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          children: children,
        ),
      ),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> act) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: primaryColor.withValues(alpha: 0.2), width: 2.5))),
      child: ListTile(
        dense: true,
        leading: Icon(act['icon'], size: 16, color: primaryColor),
        title: Text(act['description'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(act['time'], style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity, height: 55,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))]),
      child: ElevatedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text("Sign Out Account", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Align(alignment: Alignment.centerLeft, child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.grey[800]))),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 15),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTile(String title, IconData icon, VoidCallback? onTap) {
    return ListTile(
      leading: Icon(icon, size: 18, color: Colors.grey[700]),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
      onTap: onTap,
    );
  }

  // --- FUNCTIONS ---

  void _editProfile() {
    final Map<String, String> dataToEdit = {...userData, 'role': userRole, 'profilePictureUrl': profilePictureUrl ?? ''};
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        child: EditProfilePage(userId: currentUserId!, username: widget.username, initialData: dataToEdit),
      ),
    );
  }

  void _showChangePasswordModal() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (context) => SizedBox(height: MediaQuery.of(context).size.height * 0.7, child: ChangePasswordProfilePage(username: widget.username, userId: currentUserId!)),
    );
  }

  void _logout() async {
    try {
      if (currentUserId != null) {
        await FirebaseFirestore.instance.collection("users").doc(currentUserId).collection("activities").add({
          'description': 'User signed out.',
          'iconCode': Icons.logout.codePoint,
          'timestamp': FieldValue.serverTimestamp(),
          'action': 'Sign Out',
        });
      }
      await LoginPage.clearLoginState(context);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
    } catch (e) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
    }
  }
}