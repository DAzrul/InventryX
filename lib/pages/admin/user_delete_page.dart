import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'widgets/user_header_status.dart';
import 'widgets/user_info_fields.dart';

class UserDeletePage extends StatefulWidget {
  final String userId;
  final String loggedInUsername;
  final String username;

  const UserDeletePage({
    super.key,
    required this.userId,
    required this.loggedInUsername,
    required this.username,
    required Map<String, dynamic> userData,
  });

  @override
  State<UserDeletePage> createState() => _UserDeletePageState();
}

class _UserDeletePageState extends State<UserDeletePage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();

  String _currentStatus = 'Loading...';
  String? _profilePictureUrl;
  bool _isLoading = true;
  String _displayName = 'Loading...';
  final Color primaryBlue = const Color(0xFF233E99);

  @override
  void initState() {
    super.initState();
    _displayName = widget.username;
    _fetchUserData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _showAlertDialog(String title, String message, bool success) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: success ? Colors.green : Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: TextStyle(fontWeight: FontWeight.w900,
                  color: success ? Colors.green : Colors.red, fontSize: 18)),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w900))
          ),
        ],
      ),
    );
  }

  Future<bool> _isNetworkAvailable() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _fetchUserData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      if (doc.exists && mounted) {
        var data = doc.data() as Map<String, dynamic>;
        setState(() {
          _emailController.text = data['email'] ?? '';
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phoneNo'] ?? '';
          _positionController.text = data['position'] ?? '';
          _roleController.text = data['role'] ?? '';
          _displayName = data['username'] ?? widget.username;
          _currentStatus = data['status'] ?? 'Inactive';
          _profilePictureUrl = data['profilePictureUrl'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _activateUserStatus() async {
    if (!await _isNetworkAvailable()) {
      _showAlertDialog("Offline Mode", 'Please connect to internet to activate.', false);
      return;
    }

    bool confirm = await _showActionConfirmDialog(
      title: "Confirm Activation",
      message: "Restore access for $_displayName?",
      confirmText: "ACTIVATE",
      confirmColor: Colors.green,
    );

    if (!confirm) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({'status': 'Active'});
      if (mounted) {
        await _showAlertDialog("Success", 'User account activated successfully.', true);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _deleteUserPermanently() async {
    if (!await _isNetworkAvailable()) {
      _showAlertDialog("Offline Mode", 'Permanent deletion requires internet.', false);
      return;
    }

    bool confirm = await _showActionConfirmDialog(
      title: "Permanent Deletion",
      message: "Warning: All data for $_displayName will be wiped permanently. Proceed?",
      confirmText: "DELETE FOREVER",
      confirmColor: Colors.red,
    );

    if (!confirm) return;
    setState(() => _isLoading = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('deleteUserAndData');
      final result = await callable.call({'userIdToDelete': widget.userId});

      if (result.data['status'] == 'success' && mounted) {
        await _showAlertDialog("Deleted", 'User wiped from all services.', true);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showAlertDialog("Error", e.toString(), false);
      }
    }
  }

  Future<bool> _showActionConfirmDialog({required String title, required String message, required String confirmText, required Color confirmColor}) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(confirmText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Account Security', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)],
              ),
              child: UserHeaderStatus(
                username: _displayName,
                role: _roleController.text,
                currentStatus: _currentStatus,
                profilePictureUrl: _profilePictureUrl,
                onStatusChange: (v) {},
                isLoading: _isLoading,
              ),
            ),
            const SizedBox(height: 30),

            const Text("Identity Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 15),

            // 2. READ-ONLY FIELDS
            UserInfoFields(
              emailController: _emailController,
              nameController: _nameController,
              phoneController: _phoneController,
              positionController: _positionController,
              roleController: _roleController,
              isReadOnly: true,
            ),

            const SizedBox(height: 40),

            // 3. ACTIONS
            if (_currentStatus == 'Inactive')
              Column(
                children: [
                  _buildActionButton(label: "Re-Activate Account", color: Colors.green, icon: Icons.refresh_rounded, onTap: _activateUserStatus),
                  const SizedBox(height: 15),
                  _buildActionButton(label: "Delete Permanently", color: Colors.red, icon: Icons.delete_forever_rounded, onTap: _deleteUserPermanently),
                ],
              )
            else
              _buildActiveNotice(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required String label, required Color color, required IconData icon, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 22),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 5,
          shadowColor: color.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildActiveNotice() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_rounded, color: Colors.green),
          SizedBox(width: 15),
          Expanded(
            child: Text("This user is currently Active. To delete or suspend, please change status in the Edit Page first.",
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}