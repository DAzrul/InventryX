import 'package:flutter/material.dart';

class UserInfoFields extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController roleController; // [DIKEMBALIKAN]
  final bool isReadOnly; // [DIKEMBALIKAN]

  const UserInfoFields({
    super.key,
    required this.emailController,
    required this.nameController,
    required this.phoneController,
    required this.roleController,
    this.isReadOnly = false, required TextEditingController positionController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Field: Full Name
        _buildTextField(
          label: "Full Name",
          controller: nameController,
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 20),

        // --- FIELD ROLE (DROPDOWN ATAU TEXT) ---
        isReadOnly
            ? _buildTextField( // Jika ReadOnly (Delete Page), guna Text biasa
          label: "Role / Position",
          controller: roleController,
          icon: Icons.work_outline,
        )
            : _buildRoleDropdown(), // Jika Edit Page, guna Dropdown

        const SizedBox(height: 20),

        // Field: Email Address
        _buildTextField(
          label: "Email Address",
          controller: emailController,
          icon: Icons.email_outlined,
          inputType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),

        // Field: Phone Number
        _buildTextField(
          label: "Phone Number",
          controller: phoneController,
          icon: Icons.phone_outlined,
          inputType: TextInputType.phone,
        ),
      ],
    );
  }

  // Widget Dropdown Khas untuk Role (Admin, Staff, Manager)
  Widget _buildRoleDropdown() {
    // Pastikan nilai controller ada dalam senarai, jika tidak default ke 'Staff'
    String currentValue = roleController.text;
    const List<String> roles = ['Admin', 'Staff', 'Manager'];

    if (!roles.contains(currentValue) && currentValue.isNotEmpty) {
      // Jika role dalam DB tiada dalam list (contoh: 'superadmin'), tambah sementara
      // atau biarkan kosong. Di sini kita biarkan dropdown handle logic update.
    }

    return DropdownButtonFormField<String>(
      value: roles.contains(currentValue) ? currentValue : null,
      decoration: InputDecoration(
        labelText: "Role / Position",
        prefixIcon: const Icon(Icons.work_outline, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
      items: roles.map((String role) {
        return DropdownMenuItem<String>(
          value: role,
          child: Text(role),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          roleController.text = newValue; // Update controller text
        }
      },
      validator: (value) => value == null ? 'Please select a role' : null,
      hint: const Text("Select Role"),
    );
  }

  // Widget Helper untuk Text Field Biasa
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: isReadOnly,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: isReadOnly ? Colors.grey[200] : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }
}