// File: admin/widgets/user_header_status.dart
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

  // --- Widget Avatar Konsisten ---
  Widget _buildProfileAvatar() {
    const double radius = 35;
    final bool isUrlValid = profilePictureUrl != null && profilePictureUrl!.isNotEmpty;

    if (isLoading) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade300,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (isUrlValid) {
      return CachedNetworkImage(
        imageUrl: profilePictureUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: radius,
          backgroundImage: imageProvider,
          backgroundColor: Colors.transparent,
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey.shade300,
          child: const Icon(Icons.person, size: radius, color: Colors.grey),
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey.shade300,
          child: const Icon(Icons.person, size: radius, color: Colors.grey),
        ),
      );
    } else {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade300,
        child: const Icon(Icons.person, size: radius, color: Colors.grey),
      );
    }
  }

  // --- Widget Badge Status ---
  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color activeColor = Colors.green.shade600;
    final Color inactiveColor = Colors.red.shade600;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileAvatar(),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 5),
              Text(
                username,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                role.isNotEmpty ? role : 'Unknown Role',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),

              // Status Badges & Toggle Buttons
              Row(
                children: [
                  // Inactive Badge (Display)
                  _buildStatusBadge('Inactive', inactiveColor),
                  // Active Badge (Display)
                  _buildStatusBadge('Active', activeColor),

                  // STATUS TOGGLE BUTTONS
                  const SizedBox(width: 15),
                  // Button: Set Inactive
                  IconButton(
                    icon: Icon(Icons.cloud_circle, color: inactiveColor),
                    onPressed: () => onStatusChange('Inactive'),
                    tooltip: 'Set Inactive',
                  ),
                  // Button: Set Active
                  IconButton(
                    icon: Icon(Icons.check_circle, color: activeColor),
                    onPressed: () => onStatusChange('Active'),
                    tooltip: 'Set Active',
                  ),
                ],
              ),
              const SizedBox(height: 5),
              // Display Status Saat Ini
              Text(
                "Current Status: $currentStatus",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: currentStatus == 'Active' ? activeColor : inactiveColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}