import 'package:flutter/material.dart';

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

class ManagerFeaturesGrid extends StatelessWidget {
  const ManagerFeaturesGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min, // Penting: Hanya ambil ruang yang perlu
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround, // Jarak seimbang untuk 4 item
          children: [
            _ManagerFeatureIcon(
              icon: Icons.inventory_2_outlined,
              label: "Product",
              onTap: () {
                Navigator.pop(context); // Tutup modal dulu
                // Navigator.push(context, MaterialPageRoute(builder: (_) => ProductPage()));
              },
            ),
            _ManagerFeatureIcon(
              icon: Icons.local_shipping_outlined,
              label: "Supplier",
              onTap: () {
                Navigator.pop(context);
                // Navigate...
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
        const SizedBox(height: 20), // Ruang tambahan di bawah
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround, // Jarak seimbang untuk 4 item
          children: [
            _ManagerFeatureIcon(
              icon: Icons.flag_outlined,
              label: "Forecast",
              onTap: () {
                Navigator.pop(context);
                // Navigate...
              },
            ),
            _ManagerFeatureIcon(
              icon: Icons.volunteer_activism_outlined,
              label: "Recomamend",
              onTap: () {
                Navigator.pop(context);
                // Navigate...
              },
            ),
            _ManagerFeatureIcon(
              icon: Icons.description_outlined,
              label: "Report",
              onTap: () {
                Navigator.pop(context);
                // Navigate...
              },
            ),
          ],
        ),
      ],
    );
  }
}