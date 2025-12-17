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
    final imageUrl = data['imageUrl']; // optional
    final barcodeNo = data['barcodeNo'];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// 🖼 PRODUCT IMAGE / PLACEHOLDER
            Container(
              height: 90,
              width: 90,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: imageUrl != null && imageUrl.toString().isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _barcodePlaceholder(barcodeNo),
                ),
              )
                  : _barcodePlaceholder(barcodeNo),
            ),

            const SizedBox(height: 12),

            const Text(
              'Delete Product',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              data['productName'] ?? 'Unnamed',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
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
                        : const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 🔳 BARCODE PLACEHOLDER (MATCHES EARLY UI)
  Widget _barcodePlaceholder(dynamic barcodeNo) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.qr_code, size: 40, color: Colors.black54),
        if (barcodeNo != null)
          Text(
            barcodeNo.toString(),
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
      ],
    );
  }
}
