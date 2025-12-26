import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierEditPage extends StatefulWidget {
  final String supplierId;
  final Map<String, dynamic> supplierData;

  const SupplierEditPage({
    super.key,
    required this.supplierId,
    required this.supplierData,
  });

  @override
  State<SupplierEditPage> createState() => _SupplierEditPageState();
}

class _SupplierEditPageState extends State<SupplierEditPage> {
  late TextEditingController nameController;
  late TextEditingController phoneController;
  late TextEditingController emailController;
  late TextEditingController addressController;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    final data = widget.supplierData;
    nameController = TextEditingController(text: data['supplierName'] ?? '');
    phoneController = TextEditingController(text: data['contactNo'] ?? '');
    emailController = TextEditingController(text: data['email'] ?? '');
    addressController = TextEditingController(text: data['address'] ?? '');
  }

  Future<void> _updateSupplier() async {
    if (nameController.text.isEmpty ||
        phoneController.text.isEmpty ||
        emailController.text.isEmpty ||
        addressController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please fill in all fields.")));
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseFirestore.instance
          .collection("supplier")
          .doc(widget.supplierId)
          .update({
        'supplierName': nameController.text.trim(),
        'contactNo': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'address': addressController.text.trim(),
      });

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Success"),
          content: const Text("Supplier updated successfully."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: child,
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      {IconData? icon, bool isNumber = false, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Edit Supplier", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Update Supplier", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildCard(
              child: Column(
                children: [
                  _buildTextField(nameController, "Supplier Name", icon: Icons.store),
                  const SizedBox(height: 15),
                  _buildTextField(phoneController, "Phone Number", icon: Icons.phone, isNumber: true),
                  const SizedBox(height: 15),
                  _buildTextField(emailController, "Email", icon: Icons.email),
                  const SizedBox(height: 15),
                  _buildTextField(addressController, "Address", icon: Icons.location_on, maxLines: 3),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF233E99),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: loading ? null : _updateSupplier,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Changes",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
