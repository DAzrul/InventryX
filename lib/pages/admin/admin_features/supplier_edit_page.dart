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
  late TextEditingController _name;
  late TextEditingController _phone;
  late TextEditingController _email;
  late TextEditingController _address;

  @override
  void initState() {
    super.initState();
    _name =
        TextEditingController(text: widget.supplierData['supplierName']);
    _phone =
        TextEditingController(text: widget.supplierData['contactNo']);
    _email =
        TextEditingController(text: widget.supplierData['email']);
    _address = TextEditingController(
        text: widget.supplierData['address'] ?? '');
  }

  Widget _field(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  void _updateSupplier() async {
    await FirebaseFirestore.instance
        .collection("supplier")
        .doc(widget.supplierId)
        .update({
      'supplierName': _name.text.trim(),
      'contactNo': _phone.text.trim(),
      'email': _email.text.trim(),
      'address': _address.text.trim(), // ✅ NEW
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Edit Supplier",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _field("Supplier Name", _name),
            _field("Phone Number", _phone),
            _field("Email", _email),
            _field("Address", _address, maxLines: 3), // ✅ NEW
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF233E99),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _updateSupplier,
                child: const Text("Update Supplier"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
