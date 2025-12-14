// File: admin_features/product_edit_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProductEditPage extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const ProductEditPage({super.key, required this.productId, required this.productData});

  @override
  State<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _barcodeController;
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;

  String _category = 'FOOD';
  String _subCategory = 'Bakery';
  bool _loading = false;

  final Map<String, List<String>> _subCategoryMap = {
    'FOOD': ['Bakery', 'Dairy & Milk', 'Snacks & Chips'],
    'BEVERAGES': ['Soft Drink', 'Coffee & Tea', 'Water'],
    'PERSONAL CARE': ['Oral Care', 'Healthcare'],
  };

  @override
  void initState() {
    super.initState();
    final data = widget.productData;
    _barcodeController = TextEditingController(text: data['BarcodeNo'] ?? '');
    _nameController = TextEditingController(text: data['ProductName'] ?? '');
    _priceController = TextEditingController(text: (data['Price'] != null) ? data['Price'].toString() : '');
    _quantityController = TextEditingController(text: (data['Quantity'] != null) ? data['Quantity'].toString() : '');
    _category = data['Category'] ?? 'FOOD';
    final possible = _subCategoryMap[_category];
    _subCategory = data['subCategory'] ?? (possible != null && possible.isNotEmpty ? possible.first : '');
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final updated = {
        'BarcodeNo': _barcodeController.text.trim(),
        'ProductName': _nameController.text.trim(),
        'Category': _category,
        'subCategory': _subCategory,
        'Price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'Quantity': int.tryParse(_quantityController.text.trim()) ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('product').doc(widget.productId).update(updated);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating product: $e')));
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
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = const Color(0xFF233E99);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Barcode
                    TextFormField(
                      controller: _barcodeController,
                      decoration: const InputDecoration(labelText: 'Barcode No'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Barcode is required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Product Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Product Name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Product name is required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Category & Subcategory
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _category,
                            items: _subCategoryMap.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _category = v;
                                final possible = _subCategoryMap[_category];
                                _subCategory = (possible != null && possible.isNotEmpty) ? possible.first : '';
                              });
                            },
                            decoration: const InputDecoration(labelText: 'Category'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _subCategory,
                            items: (_subCategoryMap[_category] ?? ['Other']).map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setState(() => _subCategory = v ?? ''),
                            decoration: const InputDecoration(labelText: 'Subcategory'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Price & Quantity
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Price (RM)'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Price required';
                              final parsed = double.tryParse(v.trim());
                              if (parsed == null) return 'Enter a valid number';
                              if (parsed < 0) return 'Cannot be negative';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Quantity'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Quantity required';
                              final parsed = int.tryParse(v.trim());
                              if (parsed == null) return 'Enter a valid integer';
                              if (parsed < 0) return 'Cannot be negative';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _loading ? null : _updateProduct,
                        child: _loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Update Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
