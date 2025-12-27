import 'package:flutter/material.dart';

// [NOTE] Pastikan path import ni betul mat ikut folder kau!
import '../Features_app/report_page.dart';
import '../ProductPage/product_list_admin_page.dart';
import '../Supplier/supplier_list_admin_page.dart';

class _FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget page;

  const _FeatureIcon({required this.icon, required this.label, required this.page});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Tutup modal dlu baru push page baru mat!
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

class FeaturesGrid extends StatelessWidget {
  final String loggedInUsername;

  const FeaturesGrid({super.key, required this.loggedInUsername});

  // --- REPAIR: STATIC SHOW METHOD ---
  static void show(BuildContext context, String username) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 35, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text("Quick Features", style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A))),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 25),
              child: FeaturesGrid(loggedInUsername: username),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // [FIX] Panggil Page/Skrin, bukan widget item babi!
            const _FeatureIcon(
              icon: Icons.inventory_2_outlined,
              label: "Product",
              page: ProductListAdminPage(),
            ),
            const _FeatureIcon(
              icon: Icons.local_shipping_outlined,
              label: "Supplier",
              page: SupplierListPageView(),
            ),
            _FeatureIcon(
              icon: Icons.bar_chart,
              label: "Report",
              page: ReportPage(),
            ),
          ],
        ),
      ],
    );
  }
}