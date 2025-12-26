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

  final Color primaryBlue = const Color(0xFF233E99);
  final Color bgSecondary = const Color(0xFFF8FAFF);

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
      _showSnack("Fill in all the fucking fields, mat!");
      return;
    }

    setState(() => loading = true);

    try {
      // [FIXED] Changed widget.productId to widget.supplierId
      await FirebaseFirestore.instance
          .collection("supplier")
          .doc(widget.supplierId)
          .update({
        'supplierName': nameController.text.trim(),
        'contactNo': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'address': addressController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      _showSnack("Error: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSecondary,
      appBar: AppBar(
        title: const Text("Edit Partner Info", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          children: [
            _buildHeaderIcon(),
            const SizedBox(height: 25),
            _buildSectionCard(
              title: "Supplier Details",
              icon: Icons.business_rounded,
              children: [
                _buildModernField(nameController, "Supplier Name", Icons.store_rounded),
                const SizedBox(height: 15),
                _buildModernField(phoneController, "Contact Number", Icons.phone_rounded, isNumber: true),
                const SizedBox(height: 15),
                _buildModernField(emailController, "Email Address", Icons.email_rounded),
                const SizedBox(height: 15),
                _buildModernField(addressController, "Business Address", Icons.location_on_rounded, maxLines: 3),
              ],
            ),
            const SizedBox(height: 40),
            _buildSaveButton(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildHeaderIcon() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // [FIXED] Use withValues to avoid precision loss warnings
        color: primaryBlue.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.edit_location_alt_rounded, color: primaryBlue, size: 40),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: primaryBlue, size: 18), const SizedBox(width: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))]),
          const Divider(height: 30),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModernField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: primaryBlue),
        filled: true, fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryBlue, width: 1.5)),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity, height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [primaryBlue, primaryBlue.withValues(alpha: 0.8)]),
        boxShadow: [BoxShadow(color: primaryBlue.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 10))],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        onPressed: loading ? null : _updateSupplier,
        child: const Text("UPDATE SUPPLIER", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
      ),
    );
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Success", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Supplier info updated successfully."),
        actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context, true); }, child: const Text("OK"))],
      ),
    );
  }
}