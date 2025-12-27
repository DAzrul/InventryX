import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'widgets/user_header_status.dart';
import 'widgets/user_info_fields.dart';

class UserEditPage extends StatefulWidget {
  final String userId;
  final String loggedInUsername;

  const UserEditPage({
    super.key,
    required this.userId,
    required this.loggedInUsername,
    required username,
    required Map<dynamic, dynamic> userData,
  });

  @override
  State<UserEditPage> createState() => _UserEditPageState();
}

class _UserEditPageState extends State<UserEditPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();

  String _currentStatus = 'Active';
  String? _profilePictureUrl;
  bool _isLoading = true;
  String _displayName = 'Loading...';

  final Color primaryBlue = const Color(0xFF233E99);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // --- [FIX] REPAIR COLOR ERROR & OVERFLOW ---
  Future<void> _showAlertDialog(String title, String message, bool success) async {
    // Pakai Colors.green/red standard supaya tak error mat
    final Color themeColor = success ? Colors.green : Colors.red;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(success ? Icons.check_circle_rounded : Icons.error_rounded, color: themeColor),
            const SizedBox(width: 10),
            // Expanded halang overflow kalau title panjang
            Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: themeColor))),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("OK", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold))),
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
          _displayName = data['username'] ?? 'User';
          _currentStatus = data['status'] ?? 'Active';
          _profilePictureUrl = data['profilePictureUrl'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _saveChanges() async {
    if (_isLoading) return;
    if (!await _isNetworkAvailable()) {
      _showAlertDialog("Offline", "Please connect to the internet to update data.", false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'name': _nameController.text,
        'phoneNo': _phoneController.text,
        'position': _positionController.text,
        'status': _currentStatus,
        'role': _roleController.text.toLowerCase(),
      });

      if (mounted) {
        await _showAlertDialog("Success", "User details updated successfully.", true);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showAlertDialog("Failed", e.toString(), false);
        setState(() => _isLoading = false);
      }
    }
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
        // Expanded dlm title Row (jika ada) halang overflow
        title: const Text('Edit Account', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          children: [
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
                onStatusChange: (v) => setState(() => _currentStatus = v),
                isLoading: _isLoading,
              ),
            ),
            const SizedBox(height: 30),
            UserInfoFields(
              emailController: _emailController,
              nameController: _nameController,
              phoneController: _phoneController,
              positionController: _positionController,
              roleController: _roleController,
              isReadOnly: false,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 8,
                  shadowColor: primaryBlue.withOpacity(0.3),
                ),
                child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}