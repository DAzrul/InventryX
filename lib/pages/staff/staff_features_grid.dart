import 'package:flutter/material.dart';

import '../staff/add_incoming_stock.dart';
import '../staff/sales.dart';

// Import halaman-halaman destinasi Staff (pastikan fail ini wujud)
// import 'staff_features/scan_page.dart';
// import 'staff_features/stock_in_page.dart';
// dll...

class _StaffFeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StaffFeatureIcon({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ikon warna kelabu gelap ikut design gambar
          Icon(icon, color: const Color(0xFF233E99), size: 30),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF233E99)),
          ),
        ],
      ),
    );
  }
}

class StaffFeaturesGrid extends StatelessWidget {
  const StaffFeaturesGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min, // Penting: Hanya ambil ruang yang perlu
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround, // Jarak seimbang untuk 4 item
          children: [
            _StaffFeatureIcon(
              icon: Icons.inventory_2_outlined,
              label: "Product",
              onTap: () {
                Navigator.pop(context); // Tutup modal dulu
                // Navigator.push(context, MaterialPageRoute(builder: (_) => ProductPage()));
              },
            ),
            _StaffFeatureIcon(
              icon: Icons.local_shipping_outlined,
              label: "Supplier",
              onTap: () {
                Navigator.pop(context);
                // Navigate...
              },
            ),
            _StaffFeatureIcon(
              icon: Icons.store_mall_directory_outlined,
              label: "Stock",
              onTap: () {
                Navigator.pop(context); // close bottom sheet / modal

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddIncomingStockPage(),
                  ),
                );
              },
            ),
            _StaffFeatureIcon(
              icon: Icons.bar_chart_outlined,
              label: "Sales",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SalesPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}