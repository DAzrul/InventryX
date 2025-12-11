import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';

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
  // --- Controllers dan Variables ---
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneNoController;
  late TextEditingController roleController;

  File? _imageFile;
  String? _currentImageUrl;
  bool _isUploading = false;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialData['name']);
    emailController = TextEditingController(text: widget.initialData['email']);
    phoneNoController = TextEditingController(text: widget.initialData['phoneNo']);
    roleController = TextEditingController(text: widget.initialData['role']);

    _currentImageUrl = widget.initialData['profilePictureUrl'];
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneNoController.dispose();
    roleController.dispose();
    super.dispose();
  }

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

  // --- 1. MEMILIH GAMBAR ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // --- FUNGSI: Padam Imej Lama di Storage ---
  Future<void> _deleteOldImage(String? oldUrl) async {
    if (oldUrl == null || oldUrl.isEmpty || !oldUrl.contains('firebasestorage')) return;
    try {
      Reference oldRef = FirebaseStorage.instance.refFromURL(oldUrl);
      await oldRef.delete();
      print("Old profile image deleted successfully.");
    } catch (e) {
      print("Failed to delete old image: $e");
    }
  }

  // --- 2. MUAT NAIK GAMBAR KE FIREBASE STORAGE ---
  Future<String?> _uploadImageAndGetUrl() async {
    if (_imageFile == null) return _currentImageUrl;

    setState(() => _isUploading = true);

    try {
      await _deleteOldImage(_currentImageUrl);

      String fileName = 'profile_pictures/${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask = ref.putFile(_imageFile!);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'profilePictureUrl': downloadUrl,
      });

      setState(() {
        _isUploading = false;
        _currentImageUrl = downloadUrl;
      });
      return downloadUrl;

    } catch (e) {
      setState(() => _isUploading = false);
      _showPopupMessage("Error Upload", "Failed to upload image: ${e.toString()}");
      return null;
    }
  }

  // --- 3. FUNGSI KEMAS KINI DATA PROFIL ---
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      String activityDescription = "Profile data updated.";
      int iconCode = Icons.person_outline.codePoint;
      bool imageUpdated = (_imageFile != null);

      // Muat naik imej jika ada
      await _uploadImageAndGetUrl();

      if (imageUpdated) {
        activityDescription = "Profile picture updated.";
        iconCode = Icons.camera_alt_outlined.codePoint;
      }

      // LANGKAH 2: Kemas kini SEMUA data (Termasuk Email dan Role) di Firestore
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(), // KINI BOLEH DISIMPAN
        'phoneNo': phoneNoController.text.trim(),
        'role': roleController.text.trim(),   // KINI BOLEH DISIMPAN
      });

      // 3. REKOD AKTIVITI KE FIRESTORE
      await FirebaseFirestore.instance
          .collection('users').doc(widget.userId)
          .collection('activities').add({
        'timestamp': FieldValue.serverTimestamp(),
        'description': activityDescription,
        'iconCode': iconCode,
      });

      // 4. Berjaya
      Navigator.pop(context, true);

    } catch (e) {
      setState(() => _isLoading = false);
      _showPopupMessage("System Error", "Failed to update profile: ${e.toString()}");
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Pemilih Gambar Profil ---
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!) as ImageProvider
                          : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(_currentImageUrl!)
                          : const AssetImage('assets/profile.png')) as ImageProvider,
                      child: _isUploading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF233E99),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Full Name
              const Text("Full Name", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: "Enter Full Name",
                  prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter your full name.';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // --- User Role (KINI BOLEH DIEDIT) ---
              const Text("User Role (Position)", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              TextFormField(
                controller: roleController,
                readOnly: false, // Ditukar kepada FALSE (Boleh edit)
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.work_outline, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[100], // Warna cerah (boleh edit)
                  hintText: "Enter Role (e.g. Manager)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              // --- Email Address (KINI BOLEH DIEDIT) ---
              const Text("Email Address", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                readOnly: false, // Ditukar kepada FALSE (Boleh edit)
                decoration: InputDecoration(
                  hintText: "Enter Email Address",
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[100], // Warna cerah (boleh edit)
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                validator: (value) {
                  if (value == null || !value.contains('@')) return 'Please enter a valid email.';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Phone Number
              const Text("Phone Number", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              TextFormField(
                controller: phoneNoController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: "Enter Phone Number",
                  prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 40),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF233E99),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: (_isLoading || _isUploading) ? null : _updateProfile,
                  icon: const Icon(Icons.save_outlined, color: Colors.white),
                  label: (_isLoading || _isUploading)
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Changes", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}