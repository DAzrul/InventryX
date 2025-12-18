// File: product_edit_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../Features_app/barcode_scanner_page.dart';
import 'product_list_page.dart';

class ProductEditPage extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const ProductEditPage({
    super.key,
    required this.productId,
    required this.productData,
  });

  @override
  State<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();

  File? _pickedImage;
  String? _imageUrl;
  bool _loading = false;

  String? _category;
  String? _subCategory;
  String? _supplier;

  List<String> _suppliers = [];
  List<String> _subCategories = [];

  final Map<String, List<String>> _categoryMap = {
    'FOOD': ['Bakery', 'Dairy & Milk', 'Snacks & Chips'],
    'BEVERAGES': ['Soft Drink', 'Coffee & Tea', 'Water'],
    'PERSONAL CARE': ['Oral Care', 'Healthcare'],
  };

  @override
  void initState() {
    super.initState();
    final data = widget.productData;

    _nameController.text = data['productName'] ?? '';
    _priceController.text = (data['price'] ?? 0).toString();
    _barcodeController.text = (data['barcodeNo'] ?? '').toString();
    _barcodeController.selection = TextSelection.fromPosition(
        TextPosition(offset: _barcodeController.text.length));

    _category = data['category'] ?? 'FOOD';
    _subCategories = _categoryMap[_category] ?? [];
    _subCategory = data['subCategory'] ?? (_subCategories.isNotEmpty ? _subCategories.first : '');
    _supplier = data['supplier'];
    _imageUrl = data['imageUrl'];

    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    final snapshot =
    await FirebaseFirestore.instance.collection('supplier').get();

    setState(() {
      _suppliers = snapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['supplierName'] as String)
          .toList();
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<String?> _uploadImage(File file) async {
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref().child('products/$fileName');
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }

  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Select Image"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Camera"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProduct() async {
    if (_nameController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _category == null ||
        _subCategory == null ||
        _supplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all required fields.")));
      return;
    }

    setState(() => _loading = true);

    try {
      String? newImageUrl = _imageUrl;
      if (_pickedImage != null) {
        newImageUrl = await _uploadImage(_pickedImage!);
      }

      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .update({
        'productName': _nameController.text.trim(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0,
        'category': _category,
        'subCategory': _subCategory,
        'supplier': _supplier,
        'imageUrl': newImageUrl,
      });

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Success"),
          content: const Text("Product updated successfully."),
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Product"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Edit Product", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Image Picker
            GestureDetector(
              onTap: _showImagePickerDialog,
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300),
                  image: (_pickedImage != null)
                      ? DecorationImage(image: FileImage(_pickedImage!), fit: BoxFit.cover)
                      : (_imageUrl != null && _imageUrl!.isNotEmpty)
                      ? DecorationImage(image: NetworkImage(_imageUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: (_pickedImage == null && (_imageUrl == null || _imageUrl!.isEmpty))
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.image_outlined, size: 50, color: Colors.grey),
                    SizedBox(height: 8),
                    Text("Tap to add product image", style: TextStyle(color: Colors.grey)),
                  ],
                )
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            // Product Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: "Product Name",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 15),

            // Barcode (read-only)
            TextField(
              controller: _barcodeController,
              readOnly: true,
              decoration: InputDecoration(
                hintText: "Barcode",
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.qr_code, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 15),

            // Category
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                hintText: "Choose Category",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              value: _category,
              items: _categoryMap.keys.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _category = value;
                  _subCategories = _categoryMap[value]!;
                  _subCategory = _subCategories.first;
                });
              },
            ),
            const SizedBox(height: 15),

            // Subcategory
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                hintText: "Choose Subcategory",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              value: _subCategory,
              items: _subCategories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => _subCategory = v),
            ),
            const SizedBox(height: 15),

            // Supplier
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                hintText: "Choose Supplier",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              value: _supplier,
              items: _suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _supplier = v),
            ),
            const SizedBox(height: 15),

            // Price
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: "Price (RM)",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.attach_money_outlined, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 30),

            // Update button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF233E99),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _loading ? null : _updateProduct,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Update Product", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
