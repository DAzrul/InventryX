import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserHeaderStatus extends StatelessWidget {
  final String username;
  final String role;
  final String currentStatus;
  final String? profilePictureUrl;
  final ValueChanged<String> onStatusChange;
  final bool isLoading;

  const UserHeaderStatus({
    super.key,
    required this.username,
    required this.role,
    required this.currentStatus,
    this.profilePictureUrl,
    required this.onStatusChange,
    required this.isLoading,
  });

  Widget _buildProfileAvatar() {
    const double radius = 40;
    final bool isUrlValid = profilePictureUrl != null && profilePictureUrl!.isNotEmpty;
    const Color primaryBlue = Color(0xFF233E99);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // [FIX] Guna withValues untuk elak amaran deprecated
        border: Border.all(color: primaryBlue.withValues(alpha: 0.1), width: 3),
      ),
      child: isLoading
          ? CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade100,
        child: const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(strokeWidth: 2.5)),
      )
          : isUrlValid
          ? CachedNetworkImage(
        imageUrl: profilePictureUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(radius: radius, backgroundImage: imageProvider),
        placeholder: (context, url) => CircleAvatar(radius: radius, backgroundColor: Colors.grey.shade100, child: const Icon(Icons.person_rounded, size: 40, color: Colors.grey)),
        errorWidget: (context, url, error) => CircleAvatar(radius: radius, backgroundColor: Colors.grey.shade100, child: const Icon(Icons.person_rounded, size: 40, color: Colors.grey)),
      )
          : CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade100,
        child: const Icon(Icons.person_rounded, size: 40, color: Colors.grey),
      ),
    );
  }

  Widget _buildStatusActionChip(String status, Color color, bool isSelected) {
    return Expanded( // [FIX] Tambah Expanded supaya chip ni tak tolak layout ke kanan
      child: GestureDetector(
        onTap: () => onStatusChange(status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 10), // Buang horizontal padding mat supaya muat
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : color.withValues(alpha: 0.15), width: 1.5),
            boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center kan icon & teks
            children: [
              Icon(status == 'Active' ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                  size: 14, color: isSelected ? Colors.white : color),
              const SizedBox(width: 4),
              Flexible( // [FIX] Elak teks terpotong kalau skrin sempit
                child: Text(
                  status,
                  style: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontWeight: FontWeight.w900,
                      fontSize: 10, // Kecilkan sikit font
                      letterSpacing: 0.5
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color activeColor = Colors.green.shade600;
    final Color inactiveColor = Colors.red.shade600;
    final bool isActive = currentStatus == 'Active';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildProfileAvatar(),
          const SizedBox(width: 15),
          Expanded( // [FIX] Penting gila mat untuk halang overflow dlm Row
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  username,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF233E99).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    role.isNotEmpty ? role.toUpperCase() : 'STAFF',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF233E99), fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatusActionChip('Active', activeColor, isActive),
                    _buildStatusActionChip('Inactive', inactiveColor, !isActive),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}