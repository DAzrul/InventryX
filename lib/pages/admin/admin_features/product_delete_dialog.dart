import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  final Color dangerRed = const Color(0xFFE53935);

  Future<void> _deleteProduct() async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .delete();

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fucking delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.productData;
    final imageUrl = data['imageUrl'];

    // Convert data to readable types mat
    double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0.0;
    int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // WARNING ICON
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: dangerRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_amber_rounded, color: dangerRed, size: 40),
              ),
              const SizedBox(height: 16),

              const Text("Confirm Delete", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text(
                "Verify the details below before permanent deletion.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // ENHANCED PRODUCT DETAILS CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // Top Section: Image & Basic Info
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: SizedBox(
                            width: 70, height: 70,
                            child: (imageUrl != null && imageUrl.isNotEmpty)
                                ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => _placeholderIcon(),
                            )
                                : _placeholderIcon(),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['productName'] ?? 'Unnamed',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text("Barcode: ${data['barcodeNo'] ?? 'N/A'}", style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider()),

                    // Detailed Information Grid
                    _buildDetailInfo("Category", "${data['category']} / ${data['subCategory']}"),
                    _buildDetailInfo("Supplier", data['supplier'] ?? 'Unknown'),

                    const SizedBox(height: 12),

                    // Price & Stock Highlight
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatusChip("Price", "RM ${price.toStringAsFixed(2)}", Colors.blue),
                        _buildStatusChip("In Stock", "$stock ${data['unit'] ?? 'pcs'}", stock > 0 ? Colors.green : Colors.red),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      child: const Text("Cancel", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
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
                      onPressed: _loading ? null : _deleteProduct,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text("Confirm Delete", style: TextStyle(fontWeight: FontWeight.w900)),
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

  Widget _buildDetailInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label: ", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _placeholderIcon() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.inventory_2_rounded, color: Colors.black26, size: 24),
    );
  }
}