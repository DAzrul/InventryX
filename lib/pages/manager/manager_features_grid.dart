import 'package:flutter/material.dart';
import '../Features_app/report_page.dart'; // [FIX] Pastikan import ni betul mat

class _ManagerFeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ManagerFeatureIcon({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF1E3A8A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Bersih tanpa kotak ikut selera kau
          Icon(icon, color: primaryColor, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }
}

class ManagerFeaturesGrid extends StatelessWidget {
  const ManagerFeaturesGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> features = [
      {'icon': Icons.inventory_2_outlined, 'label': 'Product', 'onTap': () {}},
      {'icon': Icons.local_shipping_outlined, 'label': 'Supplier', 'onTap': () {}},
      {'icon': Icons.warehouse_outlined, 'label': 'Stock', 'onTap': () {}},
      {'icon': Icons.auto_graph_outlined, 'label': 'Forecast', 'onTap': () {}},
      {'icon': Icons.tips_and_updates_outlined, 'label': 'Recommend', 'onTap': () {}},
      {
        'icon': Icons.summarize_outlined,
        'label': 'Report',
        // [FIX] Ini logic untuk lompat ke page report mat!
        'onTap': (BuildContext ctx) => Navigator.push(
            ctx,
            MaterialPageRoute(builder: (context) => const ReportPage())
        )
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: features.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        final f = features[index];
        return _ManagerFeatureIcon(
          icon: f['icon'],
          label: f['label'],
          onTap: () {
            // Tutup modal dulu baru pergi page baru supaya tak serabut
            Navigator.pop(context);
            if (f['label'] == 'Report') {
              f['onTap'](context);
            } else {
              // Untuk butang lain yang belum ada page
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("${f['label']} coming soon!"))
              );
            }
          },
        );
      },
    );
  }
}