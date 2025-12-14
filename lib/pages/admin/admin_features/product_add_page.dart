// File: product_add_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'product_list_page.dart';

class ProductAddPage extends StatefulWidget {
  const ProductAddPage({super.key});

  @override
  State<ProductAddPage> createState() => _ProductAddPageState();
}

class _ProductAddPageState extends State<ProductAddPage> {
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();

  bool loading = false;

  // Categories and dynamic subcategories
  final Map<String, List<String>> categoryMap = {
    'FOOD': ['Bakery', 'Dairy & Milk', 'Snacks & Chips'],
    'BEVERAGES': ['Soft Drink', 'Coffee & Tea', 'Water'],
    'PERSONAL CARE': ['Oral Care', 'Healthcare'],
  };

  String? selectedCategory;
  String? selectedSubCategory;
  String? selectedSupplier;
  List<String> subCategories = [];
  List<String> suppliers = [];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  // Load suppliers from Firestore
  Future<void> _loadSuppliers() async {
    try {
      QuerySnapshot snapshot =
      await FirebaseFirestore.instance.collection("suppliers").get();

      final supplierNames = snapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String)
          .toList();

      setState(() {
        suppliers = supplierNames;
      });
    } catch (e) {
      print("Error loading suppliers: $e");
    }
  }

  // --- Popup Message Helper ---
  void showPopupMessage(String title, {String? message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message != null ? Text(message) : null,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }

  Future<void> addProduct() async {
    String productName = productNameController.text.trim();
    String category = selectedCategory ?? '';
    String subCategory = selectedSubCategory ?? '';
    String supplier = selectedSupplier ?? '';
    String barcode = barcodeController.text.trim();
    double price = double.tryParse(priceController.text.trim()) ?? 0;

    if (productName.isEmpty || category.isEmpty || subCategory.isEmpty || supplier.isEmpty || barcode.isEmpty || price <= 0) {
      showPopupMessage("Error", message: "Please fill all required fields correctly.");
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseFirestore.instance.collection("products").add({
        "productName": productName,
        "category": category,
        "subCategory": subCategory,
        "supplier": supplier,
        "barcode": barcode,
        "price": price,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Success"),
          content: Text("Product '$productName' added successfully."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const ProductListPage()),
                );
              },
              child: const Text("OK"),
            )
          ],
        ),
      );

      // Clear fields
      productNameController.clear();
      barcodeController.clear();
      priceController.clear();
      setState(() {
        selectedCategory = null;
        selectedSubCategory = null;
        selectedSupplier = null;
        subCategories = [];
      });
    } catch (e) {
      showPopupMessage("Error", message: "Failed to add product: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Product")),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Add New Product", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Product Name
            TextField(
              controller: productNameController,
              decoration: _inputDecoration("Product Name", Icons.inventory_2_outlined),
            ),
            const SizedBox(height: 15),

            // Category Dropdown
            DropdownButtonFormField<String>(
              decoration: _dropdownDecoration("Choose Category"),
              value: selectedCategory,
              items: categoryMap.keys.map((value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value;
                  selectedSubCategory = null;
                  subCategories = value != null ? categoryMap[value]! : [];
                });
              },
            ),
            const SizedBox(height: 15),

            // Subcategory Dropdown
            DropdownButtonFormField<String>(
              decoration: _dropdownDecoration("Choose Subcategory"),
              value: selectedSubCategory,
              items: subCategories.map((value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedSubCategory = value;
                });
              },
            ),
            const SizedBox(height: 15),

            // Supplier Dropdown
            DropdownButtonFormField<String>(
              decoration: _dropdownDecoration("Choose Supplier"),
              value: selectedSupplier,
              items: suppliers.map((value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedSupplier = value;
                });
              },
            ),
            const SizedBox(height: 15),

            // Price
            TextField(
              controller: priceController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration("Price (RM)", Icons.attach_money_outlined),
            ),
            const SizedBox(height: 15),

            // Barcode
            TextField(
              controller: barcodeController,
              decoration: _inputDecoration("Barcode", Icons.qr_code),
            ),
            const SizedBox(height: 30),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF233E99),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: loading ? null : addProduct,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Add Product", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: Colors.grey[600]),
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  InputDecoration _dropdownDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    );
  }
}
