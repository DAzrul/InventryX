// File: admin/widgets/user_info_fields.dart
import 'package:flutter/material.dart';

class UserInfoFields extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController positionController;
  final TextEditingController roleController;

  const UserInfoFields({
    super.key,
    required this.emailController,
    required this.nameController,
    required this.phoneController,
    required this.positionController,
    required this.roleController, required bool isReadOnly,
  });

  // --- Widget Input Field Reusable (Read-Only) ---
  Widget _buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool readOnly = true, // Selalu readOnly
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(
              color: readOnly ? Colors.grey.shade100 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              decoration: InputDecoration(
                icon: Icon(icon, color: Colors.grey.shade500),
                border: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputField(label: 'Email', icon: Icons.email_outlined, controller: emailController),
        _buildInputField(label: 'Name', icon: Icons.person_outline, controller: nameController),
        _buildInputField(label: 'Phone Number', icon: Icons.phone_outlined, controller: phoneController),
        _buildInputField(label: 'Position', icon: Icons.work_outline, controller: positionController),
        _buildInputField(label: 'Role', icon: Icons.person_pin_outlined, controller: roleController),
      ],
    );
  }
}