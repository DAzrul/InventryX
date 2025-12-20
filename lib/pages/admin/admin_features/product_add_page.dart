// File: product_add_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../Features_app/barcode_scanner_page.dart'; // Ensure this file exists!
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Select Image Source",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF233E99)),
                title: const Text("Take Photo"),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await ImagePicker().pickImage(
                      source: ImageSource.camera, imageQuality: 80);
                  if (picked != null) {
                    setState(() => pickedImage = File(picked.path));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF233E99)),
                title: const Text("Choose from Gallery"),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery, imageQuality: 80);
                  if (picked != null) {
                    setState(() => pickedImage = File(picked.path));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
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

    if (scanned == null) return;

    final barcode = int.tryParse(scanned);

    if (barcode == null) {
      showPopupMessage(
        "Invalid Barcode",
        message: "Scanned barcode is not valid.",
      );
      return;
    }

    final exists = await _barcodeExists(barcode);

    if (exists) {
      showPopupMessage(
        "Barcode Already Exists",
        message: "This barcode is already registered in the database.",
      );
      return;
    }

    // ✅ Barcode is new → fill the textfield
    setState(() {
      barcodeController.text = scanned;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text(
          "Add Product",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// ===== IMAGE CARD =====
            GestureDetector(
              onTap: pickImage,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300),
                  image: pickedImage != null
                      ? DecorationImage(
                    image: FileImage(pickedImage!),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: pickedImage != null && File(pickedImage!.path).existsSync()
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.file(
                    pickedImage!,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover, // fill the container nicely
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Text(
                          "Failed to load image",
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    },
                  ),
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.image_outlined, size: 50, color: Colors.grey),
                    SizedBox(height: 8),
                    Text("Tap to add product image",
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// ===== BARCODE CARD =====
            _card(
              child: Column(
                children: [
                  _title("Barcode"),

                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: barcodeController,
                          keyboardType: TextInputType.number,
                          decoration:
                          _inputDecoration("Barcode", Icons.qr_code),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner,
                            color: Color(0xFF233E99), size: 30),
                        onPressed: scanBarcode,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// ===== DETAILS CARD =====
            _card(
              child: Column(
                children: [
                  _title("Product Details"),

                  const SizedBox(height: 15),
                  TextField(
                    controller: productNameController,
                    decoration: _inputDecoration(
                        "Product Name", Icons.inventory_2_outlined),
                  ),

                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    decoration: _dropdownDecoration("Category"),
                    value: selectedCategory,
                    items: categoryMap.keys
                        .map((v) =>
                        DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value;
                        selectedSubCategory = null;
                        subCategories =
                        value != null ? categoryMap[value]! : [];
                      });
                    },
                  ),

                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    decoration: _dropdownDecoration("Subcategory"),
                    value: selectedSubCategory,
                    items: subCategories
                        .map((v) =>
                        DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selectedSubCategory = value),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /// ===== SUPPLIER & PRICE CARD =====
            _card(
              child: Column(
                children: [
                  _title("Supplier & Price"),

                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    decoration: _dropdownDecoration("Supplier"),
                    value: selectedSupplier,
                    items: suppliers
                        .map((v) =>
                        DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selectedSupplier = value),
                  ),

                  const SizedBox(height: 15),
                  TextField(
                    controller: priceController,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                    _inputDecoration("Price (RM)", Icons.attach_money),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            /// ===== SUBMIT BUTTON =====
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
                : const Text("Submit Product", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4),
        ],
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
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF233E99),
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
