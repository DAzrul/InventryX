// File: lib/pages/admin/widgets/menu_container.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MenuContainer extends StatefulWidget {
  final Widget child;
  final String loggedInUsername;

  const MenuContainer({
    super.key,
    required this.child,
    required this.loggedInUsername,
  });

  @override
  State<MenuContainer> createState() => _MenuContainerState();
}

class _MenuContainerState extends State<MenuContainer> {
  String? _adminProfilePictureUrl;
  bool _isDataLoading = true;
  String _displayName = 'Administrator';
  static const double _avatarRadius = 18;

  @override
  void initState() {
    super.initState();
    _fetchAdminProfilePicture();
  }

  Future<void> _fetchAdminProfilePicture() async {
    try {
      QuerySnapshot adminSnap = await FirebaseFirestore.instance
          .collection("users")
          .where("username", isEqualTo: widget.loggedInUsername)
          .limit(1)
          .get();

      if (adminSnap.docs.isNotEmpty) {
        var userData = adminSnap.docs.first.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _adminProfilePictureUrl = userData['profilePictureUrl'];
            _displayName = userData['displayName'] ?? widget.loggedInUsername;
            _isDataLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isDataLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDataLoading = false;
        });
      }
    }
  }

  Widget buildAvatar() {
    if (_isDataLoading) {
      return const CircleAvatar(
        radius: _avatarRadius,
        backgroundColor: Colors.transparent,
        child: SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF233E99)),
        ),
      );
    }

    final bool isUrlValid = _adminProfilePictureUrl != null && _adminProfilePictureUrl!.isNotEmpty;

    if (isUrlValid) {
      return CachedNetworkImage(
        imageUrl: _adminProfilePictureUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: _avatarRadius,
          backgroundImage: imageProvider,
          backgroundColor: Colors.transparent,
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: _avatarRadius,
          backgroundColor: Colors.grey.shade300,
          child: const Icon(Icons.person, size: _avatarRadius, color: Colors.grey),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: _avatarRadius,
          backgroundColor: Colors.grey.shade300,
          child: const Icon(Icons.person, size: _avatarRadius, color: Colors.grey),
        ),
      );
    } else {
      return CircleAvatar(
        radius: _avatarRadius,
        backgroundColor: Colors.grey.shade300,

        child: const Icon(Icons.person, size: _avatarRadius, color: Colors.grey),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header Admin
        Padding(
          padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 8),
          child: Row(
            children: [
              // Avatar
              buildAvatar(),

              const SizedBox(width: 10),
              // Text Display Name yang sedang login
              Text(
                  _displayName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
              const Spacer(),
              // Aksi Tambahan
            ],
          ),
        ),
        // Kotak Putih Utama (Kandungan Halaman)
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 5),
              ],
            ),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}