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

  final Color primaryBlue = const Color(0xFF233E99);

  final Map<String, List<String>> categoryMap = {
    'FOOD': ['Bakery', 'Dairy & Milk', 'Snacks & Chips'],
    'BEVERAGES': ['Soft Drinks', 'Coffee & Tea', 'Water'],
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

    if (!subCategories.contains(selectedSubCategory)) {
      selectedSubCategory = null;
    }

    _loadSuppliers();
  }

  // --- SEMUA FUNCTION ASAL KAU (JANGAN USIK MAT) ---
  Future<void> _loadSuppliers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('supplier').get();
      Map<String, String> tempMap = {};
      for (var doc in snapshot.docs) {
        tempMap[doc.id] = doc.data()['supplierName'] ?? 'Unknown';
      }
      setState(() {
        supplierMap = tempMap;
        final productSupplierId = widget.productData['supplierId'];
        if (supplierMap.containsKey(productSupplierId)) {
          selectedSupplierId = productSupplierId;
        } else {
          selectedSupplierId = null;
        }
      });
    } catch (e) {
      debugPrint("Error loading suppliers: $e");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked != null) setState(() => pickedImage = File(picked.path));
  }

  Future<String?> _uploadImage(File file) async {
    // [FIXED] millisecondsSinceEpoch
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref().child('products/$fileName');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> _updateProduct() async {
    if (productNameController.text.isEmpty ||
        priceController.text.isEmpty ||
        selectedCategory == null ||
        selectedSubCategory == null ||
        selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fill in all the fucking fields, mat!")));
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
      _showSuccessDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // --- UI START KAT SINI MAT ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text("Edit Product", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            _buildImagePickerHeader(),
            const SizedBox(height: 25),
            _buildSectionCard(
              title: "Basic Information",
              icon: Icons.inventory_2_rounded,
              children: [
                _buildModernField(barcodeController, "Barcode", Icons.qr_code_rounded, readOnly: true),
                const SizedBox(height: 15),
                _buildModernField(productNameController, "Product Name", Icons.edit_note_rounded),
                const SizedBox(height: 15),
                _buildModernDropdown(
                  label: "Category",
                  value: categoryMap.keys.contains(selectedCategory) ? selectedCategory : null,
                  items: categoryMap.keys.toList(),
                  onChanged: (v) {
                    setState(() {
                      selectedCategory = v;
                      subCategories = v != null ? categoryMap[v]! : [];
                      selectedSubCategory = null;
                    });
                  },
                ),
                const SizedBox(height: 15),
                _buildModernDropdown(
                  label: "Sub Category",
                  value: subCategories.contains(selectedSubCategory) ? selectedSubCategory : null,
                  items: subCategories,
                  onChanged: (v) => setState(() => selectedSubCategory = v),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSectionCard(
              title: "Supplier & Pricing",
              icon: Icons.local_shipping_rounded,
              children: [
                _buildSupplierDropdown(),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: _buildModernField(priceController, "Price (RM)", Icons.payments_rounded, isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildModernField(unitController, "Unit", Icons.straighten_rounded)),
                  ],
                ),
                const SizedBox(height: 15),
                _buildModernField(reorderLevelController, "Reorder Level", Icons.notifications_active_rounded, isNumber: true),
                const SizedBox(height: 15),
                _buildModernField(stockController, "Current Stock", Icons.warehouse_rounded, readOnly: true),
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

  // --- UI WIDGETS ---

  Widget _buildImagePickerHeader() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            height: 130, width: 130,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(35),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
              image: pickedImage != null
                  ? DecorationImage(image: FileImage(pickedImage!), fit: BoxFit.cover)
                  : (imageUrl != null && imageUrl!.isNotEmpty)
                  ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: pickedImage == null && (imageUrl == null || imageUrl!.isEmpty)
                ? Icon(Icons.image_search_rounded, size: 40, color: Colors.grey[300])
                : null,
          ),
          GestureDetector(
            onTap: _showImagePickerDialog,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: primaryBlue,
              child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryBlue, size: 20),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(height: 1)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModernField(TextEditingController controller, String hint, IconData icon, {bool readOnly = false, bool isNumber = false}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
        prefixIcon: Icon(icon, size: 18, color: primaryBlue),
        filled: true,
        fillColor: readOnly ? Colors.grey[50] : Colors.white,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryBlue, width: 1.5)),
        contentPadding: const EdgeInsets.all(18),
      ),
    );
  }

  Widget _buildModernDropdown({required String label, required String? value, required List<String> items, required Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
        filled: true, fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryBlue, width: 1.5)),
      ),
    );
  }

  Widget _buildSupplierDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedSupplierId,
      items: supplierMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)))).toList(),
      onChanged: (v) => setState(() => selectedSupplierId = v),
      decoration: InputDecoration(
        labelText: "Supplier",
        labelStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
        prefixIcon: Icon(Icons.business_rounded, size: 18, color: primaryBlue),
        filled: true, fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 5, shadowColor: primaryBlue.withValues(alpha: 0.3),
        ),
        onPressed: loading ? null : _updateProduct,
        child: loading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("Save Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
      ),
    );
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Update Product Image", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPickerOption(Icons.camera_alt_rounded, "Camera", () => _pickImage(ImageSource.camera)),
                _buildPickerOption(Icons.image_rounded, "Gallery", () => _pickImage(ImageSource.gallery)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { Navigator.pop(context); onTap(); },
      child: Column(
        children: [
          CircleAvatar(radius: 28, backgroundColor: const Color(0xFFF1F4FF), child: Icon(icon, color: primaryBlue)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Success", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Product data has been updated!"),
        actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context, true); }, child: const Text("Awesome!"))],
      ),
    );
  }
}