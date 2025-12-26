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

  @override
  void initState() {
    super.initState();
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

  // --- UI COMPONENTS ---

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool readOnly = false,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[600])),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          validator: validator,
          keyboardType: keyboardType,
          style: TextStyle(fontWeight: FontWeight.w600, color: readOnly ? Colors.grey : Colors.black87),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: readOnly ? Colors.grey : primaryBlue, size: 20),
            filled: true,
            fillColor: readOnly ? Colors.grey[100] : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey.shade100),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: primaryBlue.withValues(alpha: 0.5), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text("Update Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // --- AVATAR SECTION ---
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20)],
                          ),
                          child: CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.white,
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!) as ImageProvider
                                : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty
                                ? CachedNetworkImageProvider(_currentImageUrl!)
                                : null),
                            child: (_currentImageUrl == null && _imageFile == null)
                                ? Icon(Icons.person, size: 55, color: Colors.grey[300])
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryBlue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                        if (_isUploading)
                          const Positioned.fill(child: Center(child: CircularProgressIndicator())),
                      ],
                    ),
                  ),
                  const SizedBox(height: 35),

                  // --- FORM FIELDS ---
                  _buildTextField(
                    label: "Current Role",
                    controller: roleController,
                    icon: Icons.verified_user_rounded,
                    readOnly: true,
                  ),
                  _buildTextField(
                    label: "Username",
                    controller: usernameController,
                    icon: Icons.alternate_email_rounded,
                    validator: (val) => (val == null || val.isEmpty) ? "Field required" : null,
                  ),
                  _buildTextField(
                    label: "Full Name",
                    controller: nameController,
                    icon: Icons.person_rounded,
                    validator: (val) => (val == null || val.isEmpty) ? "Field required" : null,
                  ),
                  _buildTextField(
                    label: "Email Address",
                    controller: emailController,
                    icon: Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) => (val == null || !val.contains('@')) ? "Invalid email" : null,
                  ),
                  _buildTextField(
                    label: "Phone Number",
                    controller: phoneNoController,
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 100), // Spacing for floating button
                ],
              ),
            ),
          ),

          // --- FLOATING SAVE BUTTON ---
          Positioned(
            bottom: 30,
            left: 24,
            right: 24,
            child: SizedBox(
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 8,
                  shadowColor: primaryBlue.withValues(alpha: 0.4),
                ),
                onPressed: (_isLoading || _isUploading) ? null : _updateProfile,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Save Profile Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- LOGIC FUNCTIONS (Kekal sama bos, cuma update popup sikit) ---

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
  }

  Future<String?> _uploadImageAndGetUrl() async {
    if (_imageFile == null) return _currentImageUrl;
    setState(() => _isUploading = true);
    try {
      if (_currentImageUrl != null && _currentImageUrl!.contains('firebasestorage')) {
        await FirebaseStorage.instance.refFromURL(_currentImageUrl!).delete();
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

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? finalImageUrl = await _uploadImageAndGetUrl();
      String newUsername = usernameController.text.trim();

      // 1. Tentukan description aktiviti mat
      String activityMsg = "Updated profile information.";
      int activityIcon = Icons.edit.codePoint;

      if (_imageFile != null) {
        activityMsg = "Updated profile picture.";
        activityIcon = Icons.camera_alt_rounded.codePoint;
      }

      // 2. Update Master Data User
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'name': nameController.text.trim(),
        'username': newUsername,
        'email': emailController.text.trim(),
        'phoneNo': phoneNoController.text.trim(),
        'profilePictureUrl': finalImageUrl,
      });

      // 3. SIMPAN AKTIVITI (Sub-collection)
      // Wajib buat sebelum pop supaya data gerenti masuk mat!
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('activities')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'description': activityMsg,
        'iconCode': activityIcon,
      });

      // 4. Update Local Storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedUsername', newUsername);

      if (mounted) {
        // Hantar 'true' supaya page sebelum ni tahu kena refresh data
        Navigator.pop(context, true);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}