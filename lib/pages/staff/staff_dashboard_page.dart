import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

class StaffDashboardPage extends StatelessWidget {
  final String username;

  const StaffDashboardPage({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    // Warna biru gelap tepat dari gambar
    final Color primaryBlue = const Color(0xFF203288);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER (Profile dari Firebase & Bell)
          _buildHeaderSection(),

          const SizedBox(height: 30),

          // 2. STATS CARDS
          Row(
            children: [
              _buildStatCard(
                icon: Icons.arrow_circle_down_outlined,
                count: "14 Items",
                label: "Low Stock",
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                icon: Icons.access_time,
                count: "5 Items",
                label: "Expiring Soon",
              ),
            ],
          ),

          const SizedBox(height: 30),

          // 3. QUICK ACTION TITLE
          const Text(
            "Quick Action",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 16),

          // BUTTON 1
          _buildQuickActionButton(
            title: "Scan Item/ Check Stock",
            subtitle: "Scan barcode to view details & qty",
            icon: Icons.qr_code_scanner,
            color: primaryBlue,
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // BUTTON 2
          _buildQuickActionButton(
            title: "Record Daily Sales",
            subtitle: "Key-in sales data to deduct inventory",
            icon: Icons.note_add_outlined,
            color: primaryBlue,
            onTap: () {},
          ),

          const SizedBox(height: 30),

          // 4. RECENT ACTIVITY
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Activity",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              TextButton(
                onPressed: () {},
                child: Text("View All", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600)),
              )
            ],
          ),

          const SizedBox(height: 10),

          _buildActivityItem(
            title: "Stock In: Coca cola",
            subtitle: "10:30 AM",
            trailingText: "+50 units",
            trailingColor: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildActivityItem(
            title: "Sales Deduction",
            subtitle: "09:15 AM",
            trailingText: "-20 units (Manual)",
            trailingColor: Colors.red,
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // --- WIDGET HEADER BARU (FIREBASE LINKED) ---
  Widget _buildHeaderSection() {
    return StreamBuilder<QuerySnapshot>(
      // Query Firebase cari user berdasarkan username
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        // Default values (semantara loading atau jika error)
        String displayName = username.isNotEmpty ? username : "Staff";
        String? photoUrl;

        // Jika data berjaya diambil
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          // Ambil nama sebenar jika ada, atau guna username
          displayName = data['username'] ?? displayName;
          // Ambil URL gambar
          photoUrl = data['profilePictureUrl'];
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                // LOGIK GAMBAR PROFIL
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                      ? NetworkImage(photoUrl) // Guna gambar dari Firebase
                      : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? const Icon(Icons.person, color: Colors.grey) // Default ikon jika tiada gambar
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded, size: 28, color: Colors.grey),
            ),
          ],
        );
      },
    );
  }

  // Widget: Stats Card
  Widget _buildStatCard({required IconData icon, required String count, required String label}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: Colors.black87),
            const SizedBox(height: 16),
            Text(
              count,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // Widget: Quick Action Button
  Widget _buildQuickActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  // Widget: Activity Item
  Widget _buildActivityItem({
    required String title,
    required String subtitle,
    required String trailingText,
    required Color trailingColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
            child: const Icon(Icons.history, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text(trailingText, style: TextStyle(color: trailingColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}