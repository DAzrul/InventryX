import 'package:flutter/material.dart';
import '../features_grid.dart';

class FeaturesModal {
  static void show(BuildContext context, String loggedInUsername) {
    // Kita kurangkan bottom padding supaya dia tak nampak "tergantung" sangat
    final double bottomMargin = MediaQuery.of(context).padding.bottom + 22.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent, // [PENTING] Supaya shadow nampak kemas
      builder: (BuildContext context) {
        return Container(
          // Gunakan margin yang simetri supaya nampak seimbang
          margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28), // Bulat habis mat
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12), // Shadow halus babi
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // DRAG HANDLE YANG LEBIH KEMAS
                const SizedBox(height: 12),
                Container(
                  width: 35,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                // TAJUK MODAL (OPTIONAL TAPI KEMAS)
                const Padding(
                  padding: EdgeInsets.only(top: 15, bottom: 5),
                  child: Text(
                    "Quick Features",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E3A8A),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // CONTENT: Staff Features Grid
                // Kita bungkus dlm padding supaya grid tu tak langgar dinding
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: const FeaturesGrid(loggedInUsername: '',),
                ),

                const SizedBox(height: 10), // Ruang bernafas kat bawah
              ],
            ),
          ),
        );
      },
    );
  }
}