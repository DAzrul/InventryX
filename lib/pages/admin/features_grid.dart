import 'package:flutter/material.dart';
import 'package:inventryx/pages/admin/user_list_page.dart';

// [NOTE] Pastikan path import ni betul mat ikut folder kau!
// Ini page-page untuk ADMIN
import '../Features_app/report_page.dart';
import 'admin_features/product_list_page.dart';
import 'admin_features/supplier_list_page.dart';

class FeaturesGrid extends StatelessWidget {
  final String loggedInUsername;

  const FeaturesGrid({super.key, required this.loggedInUsername});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // --- USER ADMIN ---
            _FeatureIcon(
              icon: Icons.supervised_user_circle_outlined,
              label: "User",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const UserListPage(loggedInUsername: '',)));
              },
            ),

            // --- PRODUCT ADMIN ---
            _FeatureIcon(
              icon: Icons.inventory_2_outlined,
              label: "Product",
              onTap: () {
                Navigator.pop(context); // 1. Tutup modal
                // 2. Push page biasa je. Page tu nanti yang bertanggungjawab buat Reset Home.
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListPage()));
              },
            ),

            // --- SUPPLIER ADMIN ---
            _FeatureIcon(
              icon: Icons.local_shipping_outlined,
              label: "Supplier",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierListPage()));
              },
            ),

            // --- REPORT ---
            _FeatureIcon(
              icon: Icons.bar_chart_outlined,
              label: "Report",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportPage()));
              },
            ),
          ],
        ),
      ],
    );
  }
}

// Widget Icon Kecil (Internal use only)
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
        children: [
          Icon(icon, color: const Color(0xFF233E99), size: 30), // Size 30 biar sama standard
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF233E99))),
        ],
      ),
    );
  }
}