// File: user_edit_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Import komponen UI yang dipisah (Pastikan path ke widgets betul)
import 'widgets/user_header_status.dart';
import 'widgets/user_info_fields.dart';

class UserEditPage extends StatefulWidget {
  final String userId;
  final String loggedInUsername;

  const UserEditPage({
    super.key,
    required this.userId,
    required this.loggedInUsername, required username, required Map<dynamic, dynamic> userData,
  });

  get username => null;

  @override
  State<UserEditPage> createState() => _UserEditPageState();
}

class _UserEditPageState extends State<UserEditPage> {
  // Controllers untuk field yang boleh diedit
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();

  // State untuk data dan kemaskini
  String _currentStatus = 'Active';
  String? _profilePictureUrl;
  bool _isLoading = true;
  String _displayName = 'Loading...';

  // Data asal untuk perbandingan
  String _initialRole = '';
  String _initialStatus = '';
  String _initialName = '';
  String _initialPhone = '';
  String _initialPosition = '';


  @override
  void initState() {
    super.initState();
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

  // --- FUNGSI POPUP ALERDIALOG (DIUBAH: Mengembalikan Future<void>) ---
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
          // Tombol OK akan menutup dialog, dan kita menunggu hasil pop ini
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK", style: TextStyle(color: Color(0xFF233E99)))),
        ],
      ),
    );
  }


  // --- Fungsi Memuat Data Pengguna ---
  Future<void> _fetchUserData() async {
    if (!mounted) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists && mounted) {
        var data = doc.data() as Map<String, dynamic>;

        // Isi Controllers 
        _emailController.text = data['email'] ?? '';
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phoneNo'] ?? '';
        _positionController.text = data['position'] ?? '';
        _roleController.text = data['role'] ?? '';

        setState(() {
          _displayName = data['username'] ?? 'User';
          _currentStatus = data['status'] ?? 'Active';
          _profilePictureUrl = data['profilePictureUrl'];

          // Simpan state awal
          _initialRole = _roleController.text;
          _initialStatus = _currentStatus;
          _initialName = _nameController.text;
          _initialPhone = _phoneController.text;
          _initialPosition = _positionController.text;

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
      print("Error loading user data: $e");
    }
  }

  // --- Fungsi untuk Menyimpan Perubahan (Status dan Field) ---
  void _saveChanges() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    Map<String, dynamic> updateData = {};

    // 1. Kemaskini Status
    if (_currentStatus != _initialStatus) {
      updateData['status'] = _currentStatus;
    }

    // 2. Kemaskini Field Editable Lain 
    if (_nameController.text != _initialName) {
      updateData['name'] = _nameController.text;
    }
    if (_phoneController.text != _initialPhone) {
      updateData['phoneNo'] = _phoneController.text;
    }
    if (_positionController.text != _initialPosition) {
      updateData['position'] = _positionController.text;
    }
    // Role perlu disimpan dalam lowercase di Firebase
    if (_roleController.text != _initialRole) {
      updateData['role'] = _roleController.text.toLowerCase();
    }

    if (updateData.isEmpty) {
      if (mounted) {
        await _showAlertDialog(
            "No Changes",
            'No changes detected. Nothing to save.',
            false
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update(updateData);

      if (mounted) {
        // PERBAIKAN: AWAIT DIHADAPAN _showAlertDialog untuk menyelesaikan konflik navigasi
        await _showAlertDialog(
            "Update Success",
            'User ${widget.username} successfully updated.',
            true
        );

        // BARU SELEPAS POPUP DITUTUP, kita kembali ke UserListPage
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showAlertDialog(
            "Update Failed",
            'Failed to update user data. Details: ${e.toString()}',
            false
        );
        setState(() => _isLoading = false);
      }
      print("Error saving changes: $e");
    }
  }

  // --- Fungsi untuk Menukar Status (Dipanggil dari UserHeaderStatus) ---
  void _onStatusChange(String newStatus) {
    if (mounted) {
      setState(() {
        _currentStatus = newStatus;
      });
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
            // 1. HEADER & STATUS TOGGLE
            UserHeaderStatus(
              username: _displayName,
              role: _roleController.text,
              currentStatus: _currentStatus,
              profilePictureUrl: _profilePictureUrl,
              onStatusChange: _onStatusChange, // Panggil fungsi tukar status di sini
              isLoading: _isLoading,
            ),
            const SizedBox(height: 30),

            // 2. INPUT FIELDS 
            UserInfoFields(
              emailController: _emailController,
              nameController: _nameController,
              phoneController: _phoneController,
              positionController: _positionController,
              roleController: _roleController,
              isReadOnly: false, // Membenarkan editing
            ),

            const SizedBox(height: 30),

            // 3. SAVE CHANGES BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF233E99),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}