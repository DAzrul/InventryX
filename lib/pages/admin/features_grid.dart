// File: admin/features_grid.dart
import 'package:flutter/material.dart';

// Import halaman-halaman destinasi
import '../Profile/User_profile_page.dart';
import 'admin_features/sales_page.dart';
import 'admin_features/report_page.dart';
import 'admin_features/dummy_pages.dart';


// Widget Reusable untuk setiap ikon Features
class _FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget page;

  const _FeatureIcon({required this.icon, required this.label, required this.page});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Tutup modal sebelum navigasi ke halaman baru jika dipanggil dari modal
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF233E99), size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF233E99))),
        ],
      ),
    );
  }
}

// Widget Utama untuk Features Grid (yang muncul sebagai modal pop-up)
class FeaturesGrid extends StatelessWidget {
  final String loggedInUsername;

  const FeaturesGrid({super.key, required this.loggedInUsername});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Baris 1
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const _FeatureIcon(icon: Icons.inventory_2_outlined, label: "Product", page: ProductPage()),
            const _FeatureIcon(icon: Icons.local_shipping_outlined, label: "Supplier", page: SupplierPage()),
            _FeatureIcon(icon: Icons.bar_chart, label: "Report", page: ReportPage()),
          ],
        ),
      ],
    );
  }
}