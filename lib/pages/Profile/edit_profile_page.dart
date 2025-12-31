import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfilePage extends StatefulWidget {
  final String userId;
  final String username;
  final Map<String, String> initialData;

  const EditProfilePage({
    super.key,
    required this.userId,
    required this.username,
    required this.initialData,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController nameController;
  late TextEditingController usernameController;
  late TextEditingController emailController;
  late TextEditingController phoneNoController;
  late TextEditingController roleController;

  File? _imageFile;
  String? _currentImageUrl;
  bool _isUploading = false;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  final Color primaryBlue = const Color(0xFF233E99);
  final Color successGreen = Colors.green; // Warna untuk Success
  final Color errorRed = Colors.red;     // Warna untuk Error
  final Color infoBlue = const Color(0xFF233E99);     // Warna untuk Info (No changes)

  @override
  void initState() {
    super.initState();
    // Initialize controllers dengan data sedia ada
    nameController = TextEditingController(text: widget.initialData['name']);
    usernameController = TextEditingController(text: widget.username);
    emailController = TextEditingController(text: widget.initialData['email']);
    phoneNoController = TextEditingController(text: widget.initialData['phoneNo']);
    roleController = TextEditingController(text: widget.initialData['role']);
    _currentImageUrl = widget.initialData['profilePictureUrl'];
  }

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    phoneNoController.dispose();
    roleController.dispose();
    super.dispose();
  }

  // --- VALIDATION LOGIC ---
  bool isValidUsername(String username) {
    // Hanya benarkan huruf, nombor, titik, dan underscore
    final RegExp usernameRegExp = RegExp(r'^[a-zA-Z0-9._]+$');
    return usernameRegExp.hasMatch(username);
  }

  // --- CHECK FOR CHANGES ---
  // Fungsi baru untuk check kalau user ada ubah apa-apa
  bool _checkForChanges() {
    // Check teks
    bool nameChanged = nameController.text.trim() != widget.initialData['name'];
    bool usernameChanged = usernameController.text.trim() != widget.username;
    bool emailChanged = emailController.text.trim() != widget.initialData['email'];
    bool phoneChanged = phoneNoController.text.trim() != widget.initialData['phoneNo'];

    // Check gambar (ada file baru dipilih tak?)
    bool imageChanged = _imageFile != null;

    return nameChanged || usernameChanged || emailChanged || phoneChanged || imageChanged;
  }

  // --- IMAGE PICKER ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
  }

  // --- UPLOAD IMAGE KE FIREBASE STORAGE ---
  Future<String?> _uploadImageAndGetUrl() async {
    if (_imageFile == null) return _currentImageUrl;
    setState(() => _isUploading = true);
    try {
      // Delete gambar lama kalau ada (untuk jimat storage)
      if (_currentImageUrl != null && _currentImageUrl!.contains('firebasestorage')) {
        try {
          await FirebaseStorage.instance.refFromURL(_currentImageUrl!).delete();
        } catch (e) {
          // Ignore error kalau file lama tak jumpa
        }
      }

      String fileName = 'profile_pictures/${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(_imageFile!);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // --- UPDATE PROFILE LOGIC ---
  Future<void> _updateProfile() async {
    // 1. Validate Form Format
    if (!_formKey.currentState!.validate()) return;

    // 2. [NEW LOGIC] Check kalau ada perubahan
    if (!_checkForChanges()) {
      _showSnack("No changes detected.", type: SnackType.info);
      return; // Stop execution, tak perlu kacau server
    }

    setState(() => _isLoading = true);

    try {
      String inputUsername = usernameController.text.trim();
      String oldUsername = widget.username;

      // 3. Check Username Uniqueness (Kalau berubah sahaja)
      if (inputUsername != oldUsername) {
        if (!isValidUsername(inputUsername)) {
          _showSnack("Invalid username format. Use only letters, numbers, dots, or underscores.", type: SnackType.error);
          setState(() => _isLoading = false);
          return;
        }

        final checkUser = await FirebaseFirestore.instance
            .collection("users")
            .where("username", isEqualTo: inputUsername)
            .get();

        if (checkUser.docs.isNotEmpty) {
          _showSnack("Username '$inputUsername' is already taken. Please choose another.", type: SnackType.error);
          setState(() => _isLoading = false);
          return;
        }
      }

      // 4. Upload Image (kalau ada baru)
      String? finalImageUrl = await _uploadImageAndGetUrl();

      // 5. Update Firestore Document
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'name': nameController.text.trim(),
        'username': inputUsername,
        'email': emailController.text.trim(),
        'phoneNo': phoneNoController.text.trim(),
        'profilePictureUrl': finalImageUrl,
      });

      // 6. Log Activity
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('activities')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'description': "Profile updated successfully.",
        'iconCode': Icons.manage_accounts_rounded.codePoint,
        'action': 'Profile Update',
      });

      // 7. Update Local Cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedUsername', inputUsername);

      if (mounted) {
        _showSnack("Profile updated successfully!", type: SnackType.success);
        // Delay sikit supaya user sempat baca success message sebelum page tutup
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.pop(context, true);
      }

    } catch (e) {
      _showSnack("Failed to update profile. Please try again later.", type: SnackType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- [UPDATED] CUSTOM SNACKBAR UI ---
  void _showSnack(String msg, {SnackType type = SnackType.info}) {
    Color bgColor;
    IconData icon;

    switch (type) {
      case SnackType.success:
        bgColor = successGreen;
        icon = Icons.check_circle_rounded;
        break;
      case SnackType.error:
        bgColor = errorRed;
        icon = Icons.error_outline_rounded;
        break;
      case SnackType.info:
      default:
        bgColor = infoBlue;
        icon = Icons.info_outline_rounded;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text("Edit Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildAvatarSection(),

              const SizedBox(height: 35),

              // Form Fields
              _buildTextField(label: "Current Role", controller: roleController, icon: Icons.verified_user_rounded, readOnly: true),
              _buildTextField(
                  label: "Username",
                  controller: usernameController,
                  icon: Icons.alternate_email_rounded,
                  validator: (v) => (v == null || v.isEmpty) ? "Username is required" : null
              ),
              _buildTextField(
                  label: "Full Name",
                  controller: nameController,
                  icon: Icons.person_rounded,
                  validator: (v) => (v == null || v.isEmpty) ? "Full name is required" : null
              ),
              _buildTextField(
                  label: "Email Address",
                  controller: emailController,
                  icon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? "Please enter a valid email" : null
              ),
              _buildTextField(
                  label: "Phone Number",
                  controller: phoneNoController,
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone
              ),

              const SizedBox(height: 40),

              _buildSaveButton(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildAvatarSection() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: primaryBlue.withOpacity(0.1), width: 4),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
            ),
            child: CircleAvatar(
              radius: 55,
              backgroundColor: Colors.white,
              backgroundImage: _imageFile != null
                  ? FileImage(_imageFile!) as ImageProvider
                  : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(_currentImageUrl!)
                  : null),
              child: (_currentImageUrl == null || _currentImageUrl!.isEmpty) && _imageFile == null
                  ? Icon(Icons.person_rounded, size: 60, color: primaryBlue.withOpacity(0.4))
                  : null,
            ),
          ),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: primaryBlue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 55,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 8,
          shadowColor: primaryBlue.withOpacity(0.4),
        ),
        onPressed: (_isLoading || _isUploading) ? null : _updateProfile,
        child: _isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text("Save Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
      ),
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, required IconData icon, bool readOnly = false, String? Function(String?)? validator, TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey[600])),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller, readOnly: readOnly, validator: validator, keyboardType: keyboardType,
          style: TextStyle(fontWeight: FontWeight.w700, color: readOnly ? Colors.grey : Colors.black87),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: readOnly ? Colors.grey : primaryBlue, size: 20),
            filled: true, fillColor: readOnly ? Colors.grey[100] : Colors.white,
            contentPadding: const EdgeInsets.all(18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade100)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryBlue.withOpacity(0.5), width: 2)),
            errorStyle: const TextStyle(fontWeight: FontWeight.w600), // Error text bold sikit
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// Helper Enum untuk jenis Snackbar
enum SnackType { success, error, info }