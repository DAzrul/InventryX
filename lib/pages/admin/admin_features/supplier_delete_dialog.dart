import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierDeleteDialog extends StatefulWidget {
  final String supplierId;
  final Map<String, dynamic> supplierData;

  const SupplierDeleteDialog({
    super.key,
    required this.supplierId,
    required this.supplierData,
  });

  @override
  State<SupplierDeleteDialog> createState() => _SupplierDeleteDialogState();
}

class _SupplierDeleteDialogState extends State<SupplierDeleteDialog> {
  bool _loading = false;

  get barcodeNo => null;

  Future<void> _deleteSupplier() async {
    setState(() => _loading = true);

    try {
      await FirebaseFirestore.instance
          .collection('supplier')
          .doc(widget.supplierId)
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
    final data = widget.supplierData;
    final imageUrl = data['imageUrl']; // optional

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                ),
              )
                  : _barcodePlaceholder(barcodeNo),
            ),

            const SizedBox(height: 12),

            const Text(
              'Delete Supplier',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              data['supplierName'] ?? 'Unnamed',
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
                    onPressed: _loading ? null : _deleteSupplier,
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
