import 'package:flutter/material.dart';
import 'package:inventryx/pages/ProductPage/product_list_manager_view.dart';
import 'package:inventryx/pages/Supplier/supplier_list_manager_view.dart';

// [PENTING] Import ManagerReportPage dan Forecast
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
  final String loggedInUsername;
  final String userId;

  const ManagerFeaturesGrid({
    super.key,
    required this.loggedInUsername,
    required this.userId
  });

  @override
  Widget build(BuildContext context) {
    // Gunakan Padding supaya ada ruang kiri kanan sikit
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Row(
        // 'spaceEvenly' atau 'spaceBetween' supaya susunan nampak kemas dalam satu baris
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. PRODUCT
          _ManagerFeatureIcon(
            icon: Icons.inventory_2_outlined,
            label: "Product",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProductListViewPage()));
            },
          ),

          // 2. SUPPLIER
          _ManagerFeatureIcon(
            icon: Icons.local_shipping_outlined,
            label: "Supplier",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierListManagerView()));
            },
          ),

          // 3. FORECAST
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

          // 4. REPORT
          _ManagerFeatureIcon(
            icon: Icons.description_outlined,
            label: "Report",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
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
    );
  }
}