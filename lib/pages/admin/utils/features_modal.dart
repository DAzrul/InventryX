// File: lib/pages/admin/utils/features_modal.dart
import 'package:flutter/material.dart';
import '../features_grid.dart'; // Path disesuaikan

class FeaturesModal {
  // Fungsi statik untuk memanggil bottom sheet
  static void show(BuildContext context, String loggedInUsername) {
    final double bottomNavHeight = 60.0; // Anggaran tinggi BottomNavBar

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.all(16.0),

          // KOREKSI: Tambahkan tinggi Bottom Navigation Bar + Safe Area ke margin bawah.
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + bottomNavHeight,
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Garisan Penutup Modal (Opsional)
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 15),
              // Paparkan Features Grid
              FeaturesGrid(loggedInUsername: loggedInUsername),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}