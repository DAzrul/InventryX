import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductDeleteDialog extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const ProductDeleteDialog({
    super.key,
    required this.productId,
    required this.productData,
  });

  @override
  State<ProductDeleteDialog> createState() => _ProductDeleteDialogState();
}

class _ProductDeleteDialogState extends State<ProductDeleteDialog> {
  bool _loading = false;

  Future<void> _deleteProduct() async {
    setState(() => _loading = true);

    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .delete();

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.productData;
    final imageUrl = data['imageUrl'];
    final barcodeNo = data['barcodeNo'];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // compact for small screens
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Product Image
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade100,
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _barcodePlaceholder(barcodeNo),
                  )
                      : _barcodePlaceholder(barcodeNo),
                ),
              ),
              const SizedBox(height: 12),

              // Product Name
              Text(
                data['productName'] ?? 'Unnamed Product',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Product Details
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Category', data['category']),
                  _detailRow('Subcategory', data['subCategory']),
                  _detailRow('Supplier', data['supplier']),
                  _detailRow('Barcode', barcodeNo?.toString()),
                  _detailRow('Stock', data['quantity']?.toString() ?? '0'),
                  _detailRow('Price', data['price'] != null
                      ? 'RM ${data['price'].toStringAsFixed(2)}'
                      : '-'),
                ],
              ),
              const SizedBox(height: 12),

              // Warning Text
              const Text(
                'Are you sure you want to delete this product? This action cannot be undone.',
                style: TextStyle(fontSize: 13, color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _loading ? null : _deleteProduct,
                      child: _loading
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        'Delete',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Product detail row
  Widget _detailRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text('$title:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Expanded(child: Text(value ?? '-', style: const TextStyle(color: Colors.black87, fontSize: 13))),
        ],
      ),
    );
  }

  // Barcode placeholder
  Widget _barcodePlaceholder(dynamic barcodeNo) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code, size: 40, color: Colors.black38),
            if (barcodeNo != null)
              Text(
                barcodeNo.toString(),
                style: const TextStyle(fontSize: 12, color: Colors.black38),
              ),
          ],
        ),
      ),
    );
  }
}

