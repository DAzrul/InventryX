import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

// [PENTING] Pastikan path import ini betul ikut struktur folder anda
import '../../Features_app/barcode_scanner_page.dart';

class ProductAddPage extends StatefulWidget {
  const ProductAddPage({super.key});

  @override
  State<ProductAddPage> createState() => _ProductAddPageState();
}

class _ProductAddPageState extends State<ProductAddPage> {
  final _formKey = GlobalKey<FormState>();

  // --- CONTROLLERS ---
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  final TextEditingController unitController = TextEditingController(text: "pcs");
  final TextEditingController reorderLevelController = TextEditingController(text: "10");

  // --- STATE VARIABLES ---
  bool loading = false;
  File? pickedImage; // Gambar adalah optional

  // --- COLORS ---
  final Color primaryBlue = const Color(0xFF233E99);
  final Color bgSecondary = const Color(0xFFF8FAFF);

  // --- DATA ---
  final Map<String, List<String>> categoryMap = {
    'FOOD': ['Bakery', 'Dairy & Milk', 'Snacks & Chips', 'Ingredients'],
    'BEVERAGES': ['Soft Drink', 'Coffee & Tea', 'Water', 'Juice'],
    'PERSONAL CARE': ['Oral Care', 'Healthcare', 'Hair Care'],
    'HOUSEHOLD': ['Cleaning', 'Laundry', 'Kitchen'],
  };

  String? selectedCategory;
  String? selectedSubCategory;
  Map<String, String> supplierMap = {};
  String? selectedSupplierId;
  List<String> subCategories = [];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection("supplier").get();
      Map<String, String> tempMap = {};
      for (var doc in snapshot.docs) {
        tempMap[doc.id] = doc.data()['supplierName'] ?? 'Unknown';
      }
      setState(() => supplierMap = tempMap);
    } catch (e) {
      debugPrint("Error loading suppliers: $e");
    }
  }

  // --- A. LOGIC RESET FORM ---
  void _resetForm() {
    productNameController.clear();
    priceController.clear();
    barcodeController.clear();
    unitController.text = "pcs";
    reorderLevelController.text = "10";

    setState(() {
      pickedImage = null;
      selectedCategory = null;
      selectedSubCategory = null;
      selectedSupplierId = null;
      subCategories = [];
    });

    _showStyledSnackBar("Form cleared successfully!");
  }

  // --- B. LOGIC AUTO-GENERATE BARCODE ---
  void _generateBarcode() {
    // Guna timestamp (unik) untuk elak duplicate
    String uniqueCode = DateTime.now().millisecondsSinceEpoch.toString().substring(3);
    setState(() {
      barcodeController.text = uniqueCode;
    });
    _showStyledSnackBar("Generated Barcode: $uniqueCode");
  }

  // --- C. LOGIC ADD PRODUCT ---
  Future<void> addProduct() async {
    // 1. Validation Asas
    if (productNameController.text.isEmpty ||
        selectedCategory == null ||
        selectedSubCategory == null ||
        selectedSupplierId == null) {
      _showStyledSnackBar("Please fill in all required fields (Name, Category, Supplier)!", isError: true);
      return;
    }

    // 2. Validation Harga
    double price = double.tryParse(priceController.text.trim()) ?? 0;
    if (price <= 0) {
      _showStyledSnackBar("Price must be greater than RM 0.00", isError: true);
      return;
    }

    setState(() => loading = true);

    try {
      int? barcodeInt = int.tryParse(barcodeController.text.trim());

      // 3. Duplicate Barcode Check (Hanya kalau ada barcode)
      if (barcodeInt != null) {
        final check = await FirebaseFirestore.instance
            .collection("products")
            .where('barcodeNo', isEqualTo: barcodeInt)
            .limit(1)
            .get();

        if (check.docs.isNotEmpty) {
          _showStyledSnackBar("Barcode already exists in database!", isError: true);
          setState(() => loading = false);
          return;
        }
      }

      // 4. Upload Image (HANYA JIKA ADA GAMBAR)
      String imgUrl = "";
      if (pickedImage != null) {
        final fileName = DateTime.now().millisecondsSinceEpoch.toString();
        final ref = FirebaseStorage.instance.ref().child('products/$fileName');
        await ref.putFile(pickedImage!);
        imgUrl = await ref.getDownloadURL();
      }

      // 5. Save to Firestore
      DocumentReference newDoc = FirebaseFirestore.instance.collection("products").doc();
      await newDoc.set({
        "productId": newDoc.id,
        "productName": productNameController.text.trim(),
        "category": selectedCategory,
        "subCategory": selectedSubCategory,
        "supplierId": selectedSupplierId,
        "supplier": supplierMap[selectedSupplierId],
        "barcodeNo": barcodeInt, // Boleh jadi null jika kosong
        "price": price,
        "unit": unitController.text.trim(),
        "currentStock": 0, // Produk baru stok mesti 0
        "reorderLevel": int.tryParse(reorderLevelController.text.trim()) ?? 10,
        "imageUrl": imgUrl, // URL gambar atau string kosong
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // SUCCESS MESSAGE
      _showStyledSnackBar("Product '${productNameController.text}' added successfully!");

      // 6. Go Back
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context);

    } catch (e) {
      _showStyledSnackBar("Error adding product: $e", isError: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // --- PREMIUM SNACKBAR WIDGET ---
  void _showStyledSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isError ? "Oh Snap!" : "Success!",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(20),
        elevation: 10,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSecondary,
      appBar: AppBar(
        title: const Text("Add New Product", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        // [BARU] Tombol Reset di AppBar
        actions: [
          IconButton(
            onPressed: _resetForm,
            icon: const Icon(Icons.refresh_rounded, color: Colors.redAccent),
            tooltip: "Clear Form",
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildImageHeader(),
              const SizedBox(height: 10),
              const Text("(Optional Image)", style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 25),

              _buildSectionCard(
                title: "Product Identity",
                icon: Icons.qr_code_scanner_rounded,
                children: [
                  // [BARU] Barcode dengan butang Auto-Gen
                  _buildBarcodeSection(),
                  const SizedBox(height: 15),
                  _buildModernField(productNameController, "Product Name", Icons.inventory_2_outlined),
                  const SizedBox(height: 15),
                  _buildCategoryDropdown(),
                  const SizedBox(height: 15),
                  _buildSubCategoryDropdown(),
                ],
              ),
              const SizedBox(height: 20),

              _buildSectionCard(
                title: "Inventory & Price",
                icon: Icons.payments_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildModernField(priceController, "Price (RM)", Icons.attach_money, isNumber: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildModernField(unitController, "Unit", Icons.scale_outlined)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildSupplierDropdown(),
                  const SizedBox(height: 15),
                  _buildModernField(reorderLevelController, "Reorder Level", Icons.notifications_active_outlined, isNumber: true),
                ],
              ),
              const SizedBox(height: 40),
              _buildSubmitButton(),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildImageHeader() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            height: 140, width: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(35),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(31),
              child: pickedImage != null
                  ? Image.file(pickedImage!, fit: BoxFit.cover)
                  : Icon(Icons.add_photo_alternate_outlined, size: 50, color: Colors.grey[300]),
            ),
          ),
          GestureDetector(
            onTap: _showPickerOptions,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white, width: 3)),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // [BARU] Barcode Section dengan Scan & Auto-Generate
  Widget _buildBarcodeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildModernField(barcodeController, "Barcode (Optional)", Icons.qr_code, isNumber: true)),
            const SizedBox(width: 8),
            // Butang Scan
            _iconBtn(Icons.qr_code_scanner_rounded, primaryBlue, () async {
              final scanned = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const BarcodeScannerPage()));
              if (scanned != null) setState(() => barcodeController.text = scanned);
            }),
            const SizedBox(width: 8),
            // Butang Auto Generate
            _iconBtn(Icons.autorenew_rounded, Colors.orange, _generateBarcode),
          ],
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text(" *Tap orange icon to auto-generate code", style: TextStyle(fontSize: 11, color: Colors.grey)),
        ),
      ],
    );
  }

  // Helper butang kecil untuk barcode
  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 55, width: 50,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15)],
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

  Widget _buildModernField(TextEditingController controller, String hint, IconData icon, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: Icon(icon, size: 18, color: primaryBlue),
        filled: true, fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedCategory,
      decoration: _dropdownDecoration("Category", Icons.category_outlined),
      items: categoryMap.keys.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (v) => setState(() {
        selectedCategory = v;
        subCategories = v != null ? categoryMap[v]! : [];
        selectedSubCategory = null;
      }),
    );
  }

  Widget _buildSubCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedSubCategory,
      decoration: _dropdownDecoration("Subcategory", Icons.account_tree_outlined),
      items: subCategories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (v) => setState(() => selectedSubCategory = v),
    );
  }

  Widget _buildSupplierDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedSupplierId,
      decoration: _dropdownDecoration("Supplier", Icons.business_outlined),
      items: supplierMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
      onChanged: (v) => setState(() => selectedSupplierId = v),
    );
  }

  InputDecoration _dropdownDecoration(String hint, IconData icon) {
    return InputDecoration(
      labelText: hint,
      prefixIcon: Icon(icon, size: 18, color: primaryBlue),
      filled: true, fillColor: Colors.grey[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity, height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [primaryBlue, primaryBlue.withOpacity(0.8)]),
        boxShadow: [BoxShadow(color: primaryBlue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        onPressed: loading ? null : addProduct,
        child: const Text("SUBMIT PRODUCT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
      ),
    );
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Upload Product Photo", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _pickerTile(Icons.camera_alt_rounded, "Camera", ImageSource.camera),
                _pickerTile(Icons.photo_library_rounded, "Gallery", ImageSource.gallery),
              ],
            ),
            if (pickedImage != null) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => pickedImage = null);
                },
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text("Remove Photo", style: TextStyle(color: Colors.red)),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _pickerTile(IconData icon, String label, ImageSource src) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        final picked = await ImagePicker().pickImage(source: src, imageQuality: 80);
        if (picked != null) setState(() => pickedImage = File(picked.path));
      },
      child: Column(children: [CircleAvatar(radius: 30, backgroundColor: bgSecondary, child: Icon(icon, color: primaryBlue)), const SizedBox(height: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))]),
    );
  }
}