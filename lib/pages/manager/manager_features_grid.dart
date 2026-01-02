import 'package:flutter/material.dart';
import 'package:inventryx/pages/ProductPage/product_list_manager_view.dart';
import 'package:inventryx/pages/Supplier/supplier_list_manager_view.dart';

// [PENTING] Import ManagerReportPage
import '../Features_app/manager_report_page.dart';
import '../manager/forecast/forecast.dart';

class _ManagerFeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ManagerFeatureIcon({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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

class ManagerFeaturesGrid extends StatelessWidget {
  // [FIX 1] Kena declare variable ni dalam class supaya boleh guna
  final String loggedInUsername;
  final String userId;

  const ManagerFeaturesGrid({
    super.key,
    required this.loggedInUsername, // Guna 'this.' untuk simpan data
    required this.userId
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ManagerFeatureIcon(
              icon: Icons.inventory_2_outlined,
              label: "Product",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ProductListViewPage()));
              },
            ),
            _ManagerFeatureIcon(
              icon: Icons.local_shipping_outlined,
              label: "Supplier",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierListManagerView()));
              },
            ),
            _ManagerFeatureIcon(
              icon: Icons.store_mall_directory_outlined,
              label: "Stock",
              onTap: () {
                Navigator.pop(context);
                // Navigate...
              },
            ),
          ],
        ),
        const SizedBox(height: 20),

        // --- SECOND ROW ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ManagerFeatureIcon(
              icon: Icons.flag_outlined,
              label: "Forecast",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ForecastingPage()),
                );
              },
            ),
            _ManagerFeatureIcon(
              icon: Icons.volunteer_activism_outlined,
              label: "Recommended",
              onTap: () {
                Navigator.pop(context);
                // Navigate...
              },
            ),

            // [FIX 2] TUKAR KE MANAGER REPORT PAGE
            _ManagerFeatureIcon(
              icon: Icons.description_outlined,
              label: "Report",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      // Panggil ManagerReportPage dan hantar data yg disimpan tadi
                        builder: (_) => ManagerReportPage(
                          loggedInUsername: loggedInUsername,
                          userId: userId,
                        )
                    )
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}