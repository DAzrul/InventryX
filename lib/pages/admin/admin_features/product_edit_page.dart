import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _reorderLevelController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();

  File? _pickedImage;
  String? _imageUrl;
  bool _loading = false;

  String? _category;
  String? _subCategory;

  // GUNA MAP SUPAYA KITA BOLEH TUKAR NAMA KEPADA ID
  Map<String, String> _supplierMap = {};
  String? _selectedSupplierId;

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
    _unitController.text = data['unit'] ?? 'pcs';
    _reorderLevelController.text = (data['reorderLevel'] ?? 0).toString();
    _stockController.text = (data['currentStock'] ?? 0).toString();

    _category = data['category'];
    _subCategories = _categoryMap[_category] ?? [];
    _subCategory = data['subCategory'];

    // Ambil supplierId sedia ada
    _selectedSupplierId = data['supplierId'];
    _imageUrl = data['imageUrl'];

    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('supplier').get();
      Map<String, String> tempMap = {};
      for (var doc in snapshot.docs) {
        tempMap[doc.id] = doc.data()['supplierName'] ?? 'Unknown';
      }
      setState(() {
        _supplierMap = tempMap;
      });
    } catch (e) {
      debugPrint("Error loading suppliers: $e");
    }
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
    if (_nameController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _category == null ||
        _subCategory == null ||
        _selectedSupplierId == null) {
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
        'unit': _unitController.text.trim(),
        'reorderLevel': int.tryParse(_reorderLevelController.text.trim()) ?? 0,
        'supplierId': _selectedSupplierId,
        'supplier': _supplierMap[_selectedSupplierId], // Simpan nama gak utk query senang
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
            const Text("Update Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Image Picker
            GestureDetector(
              onTap: _showImagePickerDialog,
              child: Container(
                width: double.infinity, height: 180,
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
                    Text("Tap to change image", style: TextStyle(color: Colors.grey)),
                  ],
                ) : null,
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel("Product Name"),
            _buildTextField(_nameController, "Coca Cola", Icons.inventory_2_outlined),

            const SizedBox(height: 15),
            _buildLabel("Barcode (Read Only)"),
            _buildTextField(_barcodeController, "123456", Icons.qr_code, isReadOnly: true),

            const SizedBox(height: 15),
            _buildLabel("Category"),
            _buildCategoryDropdown(),

            const SizedBox(height: 15),
            _buildLabel("Sub Category"),
            _buildSubCategoryDropdown(),

            const SizedBox(height: 15),
            _buildLabel("Supplier"),
            _buildSupplierDropdown(),

            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Unit"),
                      _buildTextField(_unitController, "pcs", Icons.straighten),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Price (RM)"),
                      _buildTextField(_priceController, "2.50", Icons.attach_money, isNumber: true),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Current Stock"),
                      _buildTextField(_stockController, "0", Icons.storage, isReadOnly: true),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Reorder Level"),
                      _buildTextField(_reorderLevelController, "10", Icons.warning_amber_rounded, isNumber: true),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF233E99),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _loading ? null : _updateProduct,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Changes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS UNTUK KEMAS ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5, left: 2),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isReadOnly = false, bool isNumber = false}) {
    return TextField(
      controller: controller,
      readOnly: isReadOnly,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: isReadOnly ? Colors.grey.shade200 : Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        prefixIcon: Icon(icon, color: Colors.grey),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        filled: true, fillColor: Colors.grey.shade100,
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
    );
  }

  Widget _buildSubCategoryDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        filled: true, fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
      value: _subCategory,
      items: _subCategories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (v) => setState(() => _subCategory = v),
    );
  }

  Widget _buildSupplierDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        filled: true, fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
      value: _selectedSupplierId,
      hint: const Text("Select Supplier"),
      items: _supplierMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
      onChanged: (v) => setState(() => _selectedSupplierId = v),
    );
  }
}