import 'package:flutter/material.dart';
// Import page kau
import '../ProductPage/product_list_page_view.dart';
import '../Supplier/supplier_list_page_view.dart';
import '../staff/sales.dart';
import '../staff/stock.dart';

class StaffFeaturesGrid extends StatelessWidget {
  // [REVERT] Tak payah constructor pelik-pelik
  const StaffFeaturesGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _FeatureIcon(
              icon: Icons.inventory_2_outlined,
              label: "Product",
              onTap: () {
                Navigator.pop(context); // Tutup modal
                // Push page product biasa je
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListViewPage()));
              },
            ),
            _FeatureIcon(
              icon: Icons.local_shipping_outlined,
              label: "Supplier",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierListPageView()));
              },
            ),
            _FeatureIcon(
              icon: Icons.store_mall_directory_outlined,
              label: "Stock",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => StockPage(username: '')));
              },
            ),
            _FeatureIcon(
              icon: Icons.bar_chart_outlined,
              label: "Sales",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesPage()));
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FeatureIcon({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF233E99), size: 30),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF233E99))),
        ],
      ),
    );
  }
}