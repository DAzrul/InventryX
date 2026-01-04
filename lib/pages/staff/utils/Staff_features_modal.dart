import 'package:flutter/material.dart';
import '../staff_features_grid.dart'; // Pastikan path ni betul

class StaffFeaturesModal {
  // [FIX] Betulkan typo: Terima context, username, dan userId
  static void show(BuildContext context, String loggedInUsername, String userId) {
    final double bottomMargin = MediaQuery.of(context).padding.bottom + 22.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 30, offset: const Offset(0, 10))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(width: 35, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                const Padding(
                  padding: EdgeInsets.only(top: 15, bottom: 5),
                  child: Text("Staff Features", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A))),
                ),

                // [PENTING] Hantar data ke StaffFeaturesGrid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: StaffFeaturesGrid(
                    loggedInUsername: loggedInUsername,
                    userId: userId,
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}