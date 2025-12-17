import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierAddPage extends StatefulWidget {
  const SupplierAddPage({super.key});

  @override
  State<SupplierAddPage> createState() => _SupplierAddPageState();
}

class _SupplierAddPageState extends State<SupplierAddPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _address = TextEditingController();

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

  void _saveSupplier() async {
    await FirebaseFirestore.instance.collection("supplier").add({
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
        title: const Text("Add Supplier",
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
                onPressed: _saveSupplier,
                child: const Text("Save Supplier"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
