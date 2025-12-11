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
  // --- Controllers ---
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _deleteOldImage(String? oldUrl) async {
    if (oldUrl == null || oldUrl.isEmpty || !oldUrl.contains('firebasestorage')) return;
    try {
      await FirebaseStorage.instance.refFromURL(oldUrl).delete();
    } catch (e) {
      // Ignore errors
    }
  }

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
      setState(() {
        _isUploading = false;
        _currentImageUrl = downloadUrl;
      });
      return downloadUrl;
    } catch (e) {
      setState(() => _isUploading = false);
      _showPopupMessage("Error Upload", "Failed: ${e.toString()}");
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String activityDescription = "Profile data updated.";
      int iconCode = Icons.person_outline.codePoint;
      bool imageUpdated = (_imageFile != null);
      String newUsername = usernameController.text.trim();

      String? finalImageUrl = await _uploadImageAndGetUrl();

      if (imageUpdated) {
        activityDescription = "Profile picture updated.";
        iconCode = Icons.camera_alt_outlined.codePoint;
      }

      if (newUsername != widget.username) {
        final checkUser = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: newUsername)
            .get();
        if (checkUser.docs.isNotEmpty) {
          setState(() => _isLoading = false);
          _showPopupMessage("Error", "Username '$newUsername' is already taken.");
          return;
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'name': nameController.text.trim(),
        'username': newUsername,
        'email': emailController.text.trim(),
        'phoneNo': phoneNoController.text.trim(),
        'profilePictureUrl': finalImageUrl,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedUsername', newUsername);

      await FirebaseFirestore.instance
          .collection('users').doc(widget.userId)
          .collection('activities').add({
        'timestamp': FieldValue.serverTimestamp(),
        'description': activityDescription,
        'iconCode': iconCode,
      });

      if (mounted) Navigator.pop(context, true);

    } catch (e) {
      setState(() => _isLoading = false);
      _showPopupMessage("System Error", "Failed: ${e.toString()}");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold di dalam Modal untuk struktur UI yang kemas
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        // Butang ini membolehkan tutup manual, selain swipe
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 30, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- DRAG HANDLE (Garis Kelabu di Tengah) ---
              // Ini memberi hint visual bahawa user boleh swipe ke bawah
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // --- GAMBAR PROFIL ---
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!) as ImageProvider
                          : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(_currentImageUrl!)
                          : const AssetImage('assets/profile_placeholder.png')) as ImageProvider,
                      child: (_currentImageUrl == null && _imageFile == null)
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
                          : (_isUploading ? const CircularProgressIndicator(color: Colors.white) : null),
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

              // --- ROLE (LOCKED) ---
              const Text("User Role (Locked)", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              TextFormField(
                controller: roleController,
                readOnly: true,
                style: const TextStyle(color: Colors.grey),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              // --- USERNAME ---
              const Text("Username", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              TextFormField(
                controller: usernameController,
                decoration: InputDecoration(
                  hintText: "Enter Username",
                  prefixIcon: const Icon(Icons.account_circle_outlined, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Username required';
                  if (val.contains(' ')) return 'No spaces allowed';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // --- FULL NAME ---
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
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Name required' : null,
              ),
              const SizedBox(height: 20),

              // --- EMAIL ---
              const Text("Email Address", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: "Enter Email Address",
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                validator: (val) => (val == null || !val.contains('@')) ? 'Invalid email' : null,
              ),
              const SizedBox(height: 20),

              // --- PHONE ---
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

              // --- SAVE BUTTON ---
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
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}