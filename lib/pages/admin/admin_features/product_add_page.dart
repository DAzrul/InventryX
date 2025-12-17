// File: product_add_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'barcode_scanner_page.dart'; // the scanner page we made earlier
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

  File? pickedImage;
  String? imageUrl;

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

  Future<void> _loadSuppliers() async {
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection("supplier").get();
      final supplierName = snapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['supplierName'] as String)
          .toList();
      setState(() => suppliers = supplierName);
    } catch (e) {
      debugPrint("Error loading suppliers: $e");
    }
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => pickedImage = File(picked.path));
    }
  }

  Future<String?> uploadImage(File file) async {
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref().child('products/$fileName');
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }

  Future<bool> _barcodeExists(int barcode) async {
    final query = await FirebaseFirestore.instance
        .collection("products")
        .where('barcodeNo', isEqualTo: barcode)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  void showPopupMessage(String title, {String? message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message != null ? Text(message) : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  Future<void> addProduct() async {
    String productName = productNameController.text.trim();
    String category = selectedCategory ?? '';
    String subCategory = selectedSubCategory ?? '';
    String supplier = selectedSupplier ?? '';
    int? barcode = int.tryParse(barcodeController.text.trim());
    double price = double.tryParse(priceController.text.trim()) ?? 0;

    if (productName.isEmpty ||
        category.isEmpty ||
        subCategory.isEmpty ||
        supplier.isEmpty ||
        barcode == null ||
        price <= 0 ||
        pickedImage == null) {
      showPopupMessage("Error", message: "Please fill all fields and select image.");
      return;
    }

    setState(() => loading = true);

    try {
      final exists = await _barcodeExists(barcode);
      if (exists) {
        setState(() => loading = false);
        showPopupMessage("Duplicate Barcode", message: "A product with this barcode already exists.");
        return;
      }

      imageUrl = await uploadImage(pickedImage!);

      await FirebaseFirestore.instance.collection("products").add({
        "productName": productName,
        "category": category,
        "subCategory": subCategory,
        "supplier": supplier,
        "barcodeNo": barcode,
        "price": price,
        "imageUrl": imageUrl,
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
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ProductListPage()),
                );
              },
              child: const Text("OK"),
            )
          ],
        ),
      );
    } catch (e) {
      showPopupMessage("Error", message: "Failed to add product: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> scanBarcode() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => BarcodeScannerPage()),
    );
    if (scanned != null) {
      setState(() => barcodeController.text = scanned);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Product"), backgroundColor: Colors.white, foregroundColor: Colors.black),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Add New Product", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Product Image
            GestureDetector(
              onTap: pickImage,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                  image: pickedImage != null ? DecorationImage(image: FileImage(pickedImage!), fit: BoxFit.cover) : null,
                ),
                child: pickedImage == null
                    ? const Center(child: Icon(Icons.image, size: 50, color: Colors.grey))
                    : null,
              ),
            ),
            const SizedBox(height: 15),

            // Product Name
            TextField(controller: productNameController, decoration: _inputDecoration("Product Name", Icons.inventory_2_outlined)),
            const SizedBox(height: 15),

            // Category
            DropdownButtonFormField<String>(
              decoration: _dropdownDecoration("Choose Category"),
              value: selectedCategory,
              items: categoryMap.keys.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value;
                  selectedSubCategory = null;
                  subCategories = value != null ? categoryMap[value]! : [];
                });
              },
            ),
            const SizedBox(height: 15),

            // Subcategory
            DropdownButtonFormField<String>(
              decoration: _dropdownDecoration("Choose Subcategory"),
              value: selectedSubCategory,
              items: subCategories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (value) => setState(() => selectedSubCategory = value),
            ),
            const SizedBox(height: 15),

            // Supplier
            DropdownButtonFormField<String>(
              decoration: _dropdownDecoration("Choose Supplier"),
              value: selectedSupplier,
              items: suppliers.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (value) => setState(() => selectedSupplier = value),
            ),
            const SizedBox(height: 15),

            // Price
            TextField(controller: priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _inputDecoration("Price (RM)", Icons.attach_money_outlined)),
            const SizedBox(height: 15),

            // Barcode
            Row(
              children: [
                Expanded(
                  child: TextField(controller: barcodeController, keyboardType: TextInputType.number, decoration: _inputDecoration("Barcode", Icons.qr_code)),
                ),
                IconButton(onPressed: scanBarcode, icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF233E99))),
              ],
            ),
            const SizedBox(height: 30),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF233E99),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: loading ? null : addProduct,
                child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Add Product", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    );
  }

  InputDecoration _dropdownDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    );
  }
}
