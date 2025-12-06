// File: user_delete_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // [BARU] Import untuk semakan rangkaian

// Import komponen UI yang dipisah
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
    required this.username, required Map<String, dynamic> userData,
  });

  @override
  State<UserDeletePage> createState() => _UserDeletePageState();
}

class _UserDeletePageState extends State<UserDeletePage> {
  // Controllers untuk field display
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();

  // State untuk data yang dimuat
  String _currentStatus = 'Loading...';
  String? _profilePictureUrl;
  bool _isLoading = true;
  String _displayName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _displayName = widget.username;
    if (widget.userId.isNotEmpty) {
      _fetchUserData();
    } else {
      _isLoading = false;
      _displayName = 'Invalid User ID';
    }
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

  // --- FUNGSI POPUP ALERDIALOG ---
  Future<void> _showAlertDialog(String title, String message, bool success) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.error, color: success ? Colors.green : Colors.red),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: success ? Colors.green : Colors.red)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK", style: TextStyle(color: Color(0xFF233E99)))),
        ],
      ),
    );
  }

  // --- [BARU] FUNGSI SEMAK RANGKAIAN ---
  Future<bool> _isNetworkAvailable() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  // --- Fungsi Memuat Data Pengguna (Hanya Display) ---
  Future<void> _fetchUserData() async {
    if (!mounted) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists && mounted) {
        var data = doc.data() as Map<String, dynamic>;

        // Isi Controllers (Read-Only)
        _emailController.text = data['email'] ?? '';
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phoneNo'] ?? '';
        _positionController.text = data['position'] ?? '';
        _roleController.text = data['role'] ?? '';

        setState(() {
          _displayName = data['username'] ?? widget.username;
          _currentStatus = data['status'] ?? 'Inactive';
          _profilePictureUrl = data['profilePictureUrl'];
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _displayName = 'User Not Found';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _displayName = 'Error Loading Data';
        });
      }
      print("Error loading user data for deletion: $e");
    }
  }

  // --- FUNGSI BARU: Mengubah Status Inactive ke Active (DIPERBAIKI) ---
  void _activateUserStatus() async {
    if (_isLoading) return;

    // [LANGKAH 0: SEMAK RANGKAIAN]
    if (!await _isNetworkAvailable()) {
      await _showAlertDialog(
          "Offline Mode",
          'Cannot activate user status while offline. Please connect to the internet.',
          false
      );
      return;
    }

    // Konfirmasi sebelum aktivasi
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm User Activation"),
          content: Text("Are you sure you want to change the status of $_displayName to Active?"),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.of(context).pop(true),
                child: const Text("ACTIVATE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
          ],
        );
      },
    ) ?? false;

    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'status': 'Active'});

      if (mounted) {
        await _showAlertDialog(
            "Activation Success",
            'User ${widget.username} successfully activated.',
            true
        );
        // Kembali ke UserListPage (menutup UserDeletePage)
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showAlertDialog(
            "Activation Failed",
            'Failed to activate user account. Please check connection. Details: ${e.toString()}',
            false
        );
        setState(() => _isLoading = false);
      }
      print("Error activating user: $e");
    }
  }

  // --- Fungsi DELETE Permanen (Memanggil Cloud Function) (DIPERBAIKI) ---
  void _deleteUserPermanently() async {
    if (_isLoading) return;

    // [LANGKAH 0: SEMAK RANGKAIAN]
    if (!await _isNetworkAvailable()) {
      await _showAlertDialog(
          "Offline Mode",
          'Cannot delete user permanently while offline. Please connect to the internet.',
          false
      );
      return;
    }

    // 1. Tunjukkan dialog konfirmasi sebelum pemadaman
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Permanent Deletion"),
          content: Text("Are you sure you want to permanently delete the account for $_displayName? This action will remove data from Auth, Firestore, and Storage."),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.of(context).pop(true),
                child: const Text("DELETE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
          ],
        );
      },
    ) ?? false;

    if (confirm) {
      try {
        setState(() => _isLoading = true);

        final adminUid = FirebaseAuth.instance.currentUser?.uid;
        // Panggilan Cloud Function memerlukan sambungan yang stabil.
        final callable = FirebaseFunctions.instance.httpsCallable('deleteUserAndData');

        final result = await callable.call({
          'userIdToDelete': widget.userId,
          'adminUid': adminUid,
        });

        setState(() => _isLoading = false);

        if (result.data['status'] == 'success') {
          if (mounted) {
            await _showAlertDialog(
                "Deletion Success",
                'User ${widget.username} successfully deleted from all services.',
                true
            );
            // Kembali ke UserListPage (menutup UserDeletePage)
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            _showAlertDialog(
                "Deletion Failed",
                'Failed to delete account: ${result.data['message']}. Please check connection and try again.',
                false
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showAlertDialog(
              "Deletion Error",
              'An error occurred during deletion process. Please check connection. Details: ${e.toString()}',
              false
          );
        }
        print("Error calling delete function: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER & STATUS DISPLAY
            UserHeaderStatus(
              username: _displayName,
              role: _roleController.text,
              currentStatus: _currentStatus,
              profilePictureUrl: _profilePictureUrl,
              onStatusChange: (newStatus) {},
              isLoading: _isLoading,
            ),
            const SizedBox(height: 30),

            // 2. INPUT FIELDS (Read-Only)
            UserInfoFields(
              emailController: _emailController,
              nameController: _nameController,
              phoneController: _phoneController,
              positionController: _positionController,
              roleController: _roleController,
              isReadOnly: true,
            ),

            const SizedBox(height: 30),

            // 3. ACTION BUTTONS (Conditional)
            if (_currentStatus == 'Inactive')
              Column(
                children: [
                  // ACTIVATE BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _activateUserStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF233E99),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Activate User', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  // DELETE BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _deleteUserPermanently,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Delete Permanently', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            else // Jika status sudah Active, tampilkan info
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "User is currently Active. Use the Edit Page to manage their data.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                  )
              ),
          ],
        ),
      ),
    );
  }
}