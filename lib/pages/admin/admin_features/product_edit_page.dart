import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _barcodeController;
  late TextEditingController _nameController;
  late TextEditingController _priceController;

  String _category = 'FOOD';
  String _subCategory = 'Bakery';
  String? _supplier;

  bool _loading = false;

  List<String> _suppliers = [];

  final Map<String, List<String>> _subCategoryMap = {
    'FOOD': ['Bakery', 'Dairy & Milk', 'Snacks & Chips'],
    'BEVERAGES': ['Soft Drink', 'Coffee & Tea', 'Water'],
    'PERSONAL CARE': ['Oral Care', 'Healthcare'],
  };

  @override
  void initState() {
    super.initState();
    final data = widget.productData;

    _barcodeController =
        TextEditingController(text: data['barcodeNo']?.toString() ?? '');
    _nameController =
        TextEditingController(text: data['productName'] ?? '');
    _priceController =
        TextEditingController(text: data['price']?.toString() ?? '');

    _category = data['category'] ?? 'FOOD';
    _supplier = data['supplier'];

    final possible = _subCategoryMap[_category];
    _subCategory = data['subCategory'] ??
        (possible != null && possible.isNotEmpty ? possible.first : '');

    _loadSuppliers();
  }

  /// 🔹 Load suppliers from Firestore
  Future<void> _loadSuppliers() async {
    final snapshot =
    await FirebaseFirestore.instance.collection('supplier').get();

    setState(() {
      _suppliers = snapshot.docs
          .map((doc) =>
      (doc.data() as Map<String, dynamic>)['supplierName'] as String)
          .toList();
    });
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate() || _supplier == null) return;

    setState(() => _loading = true);

    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .update({
        'barcodeNo': int.tryParse(_barcodeController.text.trim()) ?? 0,
        'productName': _nameController.text.trim(),
        'category': _category,
        'subCategory': _subCategory,
        'supplier': _supplier,
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating product: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF233E99);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Card(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [

                    /// Barcode
                    TextFormField(
                      controller: _barcodeController,
                      keyboardType: TextInputType.number,
                      decoration:
                      const InputDecoration(labelText: 'Barcode No'),
                      validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Barcode is required'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    /// Product Name
                    TextFormField(
                      controller: _nameController,
                      decoration:
                      const InputDecoration(labelText: 'Product Name'),
                      validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Product name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    /// Supplier Dropdown
                    DropdownButtonFormField<String>(
                      value: _supplier,
                      decoration:
                      const InputDecoration(labelText: 'Supplier'),
                      items: _suppliers
                          .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _supplier = v),
                      validator: (v) =>
                      v == null ? 'Supplier is required' : null,
                    ),
                    const SizedBox(height: 12),

                    /// Category & Subcategory
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _category,
                            items: _subCategoryMap.keys
                                .map((k) => DropdownMenuItem(
                                value: k, child: Text(k)))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _category = v;
                                _subCategory =
                                    _subCategoryMap[v]!.first;
                              });
                            },
                            decoration:
                            const InputDecoration(labelText: 'Category'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _subCategory,
                            items: _subCategoryMap[_category]!
                                .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _subCategory = v ?? ''),
                            decoration: const InputDecoration(
                                labelText: 'Subcategory'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    /// Price
                    TextFormField(
                      controller: _priceController,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                      const InputDecoration(labelText: 'Price (RM)'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Price required';
                        }
                        final p = double.tryParse(v.trim());
                        if (p == null) return 'Invalid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    /// Update Button
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
                            : const Text("Update Product", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
