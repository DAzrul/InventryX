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
  bool loading = false;
  final Color dangerRed = const Color(0xFFE53935);

  Future<void> _deleteSupplier() async {
    setState(() => loading = true);

    try {
      await FirebaseFirestore.instance
          .collection('supplier')
          .doc(widget.supplierId)
          .delete();

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.supplierData;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // DANGER ICON HEADER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: dangerRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_forever_rounded, color: dangerRed, size: 40),
            ),
            const SizedBox(height: 16),

            // TITLE & WARNING
            const Text(
              "Delete Supplier?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              "This will permanently remove this partner from your database.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 20),

            // SUPPLIER PREVIEW CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    data['supplierName'] ?? 'Unnamed Supplier',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const Divider(height: 24),
                  _buildDetailRow(Icons.phone_rounded, data['contactNo']),
                  _buildDetailRow(Icons.email_rounded, data['email']),
                  _buildDetailRow(Icons.location_on_rounded, data['address']),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ACTION BUTTONS
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: loading ? null : () => Navigator.pop(context),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dangerRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: loading ? null : _deleteSupplier,
                    child: loading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      "Confirm Delete",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value ?? '-',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}