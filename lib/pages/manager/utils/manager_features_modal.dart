import 'package:flutter/material.dart';
import '../manager_features_grid.dart';

class ManagerFeaturesModal {
  static void show(BuildContext context) {
    // Selaraskan bottom margin supaya sama tinggi dlm apps
    final double bottomMargin = MediaQuery.of(context).padding.bottom + 22.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent, //
      builder: (BuildContext context) {
        return Container(
          margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin), // Floating effect
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12), // Shadow halus
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
                const SizedBox(height: 12),
                // DRAG HANDLE
                Container(
                  width: 35,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.only(top: 15, bottom: 5),
                  child: Text(
                    "Manager Features",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E3A8A),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // CONTENT: Grid Manager
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: ManagerFeaturesGrid(),
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