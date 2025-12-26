import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../Features_app/barcode_scanner_page.dart';

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
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController reorderLevelController = TextEditingController();
  final TextEditingController stockController = TextEditingController();

  File? pickedImage;
  String? imageUrl;
  bool loading = false;

  String? selectedCategory;
  String? selectedSubCategory;

  Map<String, String> supplierMap = {};
  String? selectedSupplierId;
  List<String> subCategories = [];

  final Map<String, List<String>> categoryMap = {
    'FOOD': ['Bakery', 'Dairy & Milk', 'Snacks & Chips'],
    'BEVERAGES': ['Soft Drink', 'Coffee & Tea', 'Water'],
    'PERSONAL CARE': ['Oral Care', 'Healthcare'],
  };

  @override
  void initState() {
    super.initState();
    final data = widget.productData;

    productNameController.text = data['productName'] ?? '';
    priceController.text = (data['price'] ?? 0).toString();
    barcodeController.text = (data['barcodeNo'] ?? '').toString();
    unitController.text = data['unit'] ?? 'pcs';
    reorderLevelController.text = (data['reorderLevel'] ?? 0).toString();
    stockController.text = (data['currentStock'] ?? 0).toString();

    selectedCategory = data['category'];
    subCategories = categoryMap[selectedCategory] ?? [];
    selectedSubCategory = data['subCategory'];
    selectedSupplierId = data['supplierId'];
    imageUrl = data['imageUrl'];

    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('supplier').get();
      Map<String, String> tempMap = {};
      for (var doc in snapshot.docs) {
        tempMap[doc.id] = doc.data()['supplierName'] ?? 'Unknown';
      }
      setState(() => supplierMap = tempMap);
    } catch (e) {
      debugPrint("Error loading suppliers: $e");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked != null) setState(() => pickedImage = File(picked.path));
  }

  Future<String?> _uploadImage(File file) async {
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref().child('products/$fileName');
    await ref.putFile(file);
    return await ref.getDownloadURL();
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
    if (productNameController.text.isEmpty ||
        priceController.text.isEmpty ||
        selectedCategory == null ||
        selectedSubCategory == null ||
        selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all required fields.")));
      return;
    }

    setState(() => loading = true);

    try {
      String? newImageUrl = imageUrl;
      if (pickedImage != null) {
        newImageUrl = await _uploadImage(pickedImage!);
      }

      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .update({
        'productName': productNameController.text.trim(),
        'price': double.tryParse(priceController.text.trim()) ?? 0,
        'category': selectedCategory,
        'subCategory': selectedSubCategory,
        'unit': unitController.text.trim(),
        'reorderLevel': int.tryParse(reorderLevelController.text.trim()) ?? 0,
        'supplierId': selectedSupplierId,
        'supplier': supplierMap[selectedSupplierId],
        'imageUrl': newImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
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
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Edit Product", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _imagePickerCard(),
            const SizedBox(height: 20),
            _card(
              child: Column(
                children: [
                  _title("Product Info"),
                  const SizedBox(height: 15),
                  TextField(
                    controller: barcodeController,
                    readOnly: true,
                    decoration: _inputDecoration("Barcode (Read Only)", Icons.qr_code),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: productNameController,
                    decoration: _inputDecoration("Product Name", Icons.inventory_2_outlined),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    decoration: _dropdownDecoration("Category"),
                    value: selectedCategory,
                    items: categoryMap.keys
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value;
                        selectedSubCategory = null;
                        subCategories = value != null ? categoryMap[value]! : [];
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    decoration: _dropdownDecoration("Subcategory"),
                    value: selectedSubCategory,
                    items: subCategories
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (value) => setState(() => selectedSubCategory = value),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: unitController,
                    decoration: _inputDecoration("Unit (pcs, kg, etc.)", Icons.straighten),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
              child: Column(
                children: [
                  _title("Supplier & Inventory"),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    decoration: _dropdownDecoration("Supplier"),
                    value: selectedSupplierId,
                    items: supplierMap.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (value) => setState(() => selectedSupplierId = value),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration("Price (RM)", Icons.attach_money),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: reorderLevelController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration("Reorder Level", Icons.notifications_active_outlined),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: stockController,
                    readOnly: true,
                    decoration: _inputDecoration("Current Stock", Icons.storage),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF233E99),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: loading ? null : _updateProduct,
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

  Widget _imagePickerCard() {
    return GestureDetector(
      onTap: _showImagePickerDialog,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300),
          image: pickedImage != null
              ? DecorationImage(image: FileImage(pickedImage!), fit: BoxFit.cover)
              : (imageUrl != null && imageUrl!.isNotEmpty)
              ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
              : null,
        ),
        child: pickedImage == null && (imageUrl == null || imageUrl!.isEmpty)
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.image_outlined, size: 50, color: Colors.grey),
            SizedBox(height: 8),
            Text("Tap to change image", style: TextStyle(color: Colors.grey)),
          ],
        )
            : null,
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: child,
    );
  }

  Widget _title(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF233E99)),
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
