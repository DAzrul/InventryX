import 'package:flutter/material.dart';
import '../staff_features_grid.dart'; // Import Grid tadi

class StaffFeaturesModal {
  static void show(BuildContext context) {
    // Anggaran tinggi Bottom Navigation Bar supaya modal muncul DI ATASNYA
    // Anda boleh adjust nilai 80.0 ini ikut ketinggian sebenar nav bar anda
    final double bottomPadding = MediaQuery.of(context).padding.bottom + 80.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Membenarkan kawalan saiz penuh
      enableDrag: true,         // [PENTING] Ini membolehkan SWIPE KE BAWAH untuk tutup
      backgroundColor: Colors.transparent, // Transparent supaya nampak floating effect
      builder: (BuildContext context) {
        return Container(
          margin: EdgeInsets.only(bottom: bottomPadding), // Terapung atas Nav Bar
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)), // Bucu bulat atas
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Garis Drag Handle (Visual cue untuk user tahu boleh swipe)
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Panggil Grid Features
              const StaffFeaturesGrid(),
            ],
          ),
        );
      },
    );
  }
}