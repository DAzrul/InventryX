import 'package:flutter/material.dart';

class UserInfoFields extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController roleController;
  final bool isReadOnly;

  const UserInfoFields({
    super.key,
    required this.emailController,
    required this.nameController,
    required this.phoneController,
    required this.roleController,
    this.isReadOnly = false, required TextEditingController positionController,
  });

  // Warna Tema Admin kau mat
  final Color primaryBlue = const Color(0xFF233E99);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Field: Full Name
        _buildTextField(
          label: "Full Name",
          controller: nameController,
          icon: Icons.person_rounded,
        ),
        const SizedBox(height: 16),

        // --- FIELD ROLE (DROPDOWN ATAU TEXT) ---
        isReadOnly
            ? _buildTextField(
          label: "Role / Position",
          controller: roleController,
          icon: Icons.work_rounded,
        )
            : _buildRoleDropdown(),

        const SizedBox(height: 16),

        // Field: Email Address
        _buildTextField(
          label: "Email Address",
          controller: emailController,
          icon: Icons.alternate_email_rounded,
          inputType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        // Field: Phone Number
        _buildTextField(
          label: "Phone Number",
          controller: phoneController,
          icon: Icons.phone_android_rounded,
          inputType: TextInputType.phone,
        ),
      ],
    );
  }

  // Widget Dropdown Khas untuk Role (Premium Design)
  Widget _buildRoleDropdown() {
    String currentValue = roleController.text;
    const List<String> roles = ['Admin', 'Staff', 'Manager'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: roles.contains(currentValue) ? currentValue : null,
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryBlue),
        decoration: InputDecoration(
          labelText: "Role / Position",
          labelStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 13),
          prefixIcon: Icon(Icons.work_rounded, color: primaryBlue, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(15),
        items: roles.map((String role) {
          return DropdownMenuItem<String>(
            value: role,
            child: Text(role, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            roleController.text = newValue;
          }
        },
        validator: (value) => value == null ? 'Please select a role' : null,
        hint: Text("Select Role", style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
      ),
    );
  }

  // Widget Helper untuk Text Field (Modern & Clean)
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isReadOnly ? const Color(0xFFF3F6FF) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: isReadOnly
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextFormField(
        controller: controller,
        readOnly: isReadOnly,
        keyboardType: inputType,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 13),
          prefixIcon: Icon(icon, color: isReadOnly ? Colors.grey : primaryBlue, size: 20),
          filled: false,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }
}