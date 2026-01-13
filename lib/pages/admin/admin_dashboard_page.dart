import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

// Imports Halaman
import 'user_list_page.dart';
import 'admin_features/product_list_page.dart';
import 'admin_features/supplier_list_page.dart';

// [PENTING] Pastikan file ni wujud
import 'cmd_page.dart';
import 'AI_advisor_page.dart';
import 'ExpiryAdvisor.dart';

class AdminDashboardPage extends StatelessWidget {
  final String loggedInUsername;
  final String userId;

  const AdminDashboardPage({
    super.key,
    required this.loggedInUsername,
    required this.userId
  });

  final Color primaryBlue = const Color(0xFF233E99);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          // 1. Header
          _buildHeader(context),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 25),

                  // --- SECTION 1: DATABASE OVERVIEW (STATISTIK SEBARIS) ---
                  const Text(
                      "Database Overview",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1C1E))
                  ),
                  const SizedBox(height: 5),
                  Text(
                      "Real-time system statistics",
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600)
                  ),
                  const SizedBox(height: 15),

                  // [UBAH DI SINI] Row untuk susun sebaris
                  Row(
                    children: [
                      _buildSquareStatCard("Users", "users", Icons.people_alt_rounded, Colors.blue),
                      const SizedBox(width: 12),
                      _buildSquareStatCard("Products", "products", Icons.inventory_2_rounded, Colors.orange),
                      const SizedBox(width: 12),
                      _buildSquareStatCard("Suppliers", "supplier", Icons.store_rounded, Colors.green),
                    ],
                  ),

                  const SizedBox(height: 35),

                  // --- SECTION 2: REGISTRATION MANAGEMENT ---
                  const Text(
                      "Registration Management",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1C1E))
                  ),
                  const SizedBox(height: 5),
                  Text(
                      "Manage access, master data & simulations",
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600)
                  ),

                  const SizedBox(height: 20),

                  _buildLargeButton(
                    context,
                    title: "Manage Users",
                    subtitle: "Register staff & administrators",
                    icon: Icons.people_outline_rounded,
                    page: UserListPage(loggedInUsername: loggedInUsername),
                  ),
                  const SizedBox(height: 15),
                  _buildLargeButton(
                    context,
                    title: "Inventory Products",
                    subtitle: "Register new products",
                    icon: Icons.inventory_2_outlined,
                    page: const ProductListPage(),
                  ),
                  const SizedBox(height: 15),
                  _buildLargeButton(
                    context,
                    title: "Supplier Directory",
                    subtitle: "Register & manage suppliers",
                    icon: Icons.local_shipping_outlined,
                    page: const SupplierListPage(),
                  ),

                  // --- [RESTRICTED ACCESS: CMD & ADVISOR] ---
                  const SizedBox(height: 15),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return const SizedBox.shrink();
                      }

                      var data = snapshot.data!.data() as Map<String, dynamic>;
                      String email = data['email'] ?? '';
                      String username = data['username'] ?? '';

                      // Check Boss
                      bool isTheBoss = email == 'datuazrul04@gmail.com' || username == 'D.AZRUL';

                      if (isTheBoss) {
                        return Column(
                          children: [
                            // 1. CMD Control (Simulasi Data)
                            _buildLargeButton(
                              context,
                              title: "CMD Control",
                              subtitle: "Simulation Data Generator",
                              icon: Icons.terminal_rounded,
                              page: const CmdPage(),
                              colorOverride: Colors.black87,
                            ),
                            const SizedBox(height: 15),

                            // 2. [NEW] Real Shelf Life Analytics
                            // Page ini hanya fokus analisa berapa lama barang tahan (Expiry)
                            _buildLargeButton(
                              context,
                              title: "Real Shelf Life",
                              subtitle: "Analyze Actual Product Expiry Trends",
                              icon: Icons.access_time_filled_rounded,
                              page: const ExpiryAdvisor(),
                              colorOverride: Colors.orange.shade800, // Warna oren utk Alert/Masa
                            ),

                            const SizedBox(height: 15),

                            // 3. [NEW] AI Restock Advisor
                            // Page ini yang buat suggestion order (Weekly/Monthly) tadi
                            _buildLargeButton(
                              context,
                              title: "AI Restock Advisor",
                              subtitle: "Smart Order Suggestions (Forecast)",
                              icon: Icons.psychology_rounded,
                              page: const AIAdvisorPage(),
                              colorOverride: Colors.indigo.shade700, // Warna biru utk AI/Otak
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildHeader(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        String name = loggedInUsername;
        String? img;
        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['username'] ?? loggedInUsername;
          img = data['profilePictureUrl'];
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 5)
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryBlue.withValues(alpha: 0.1), width: 2)
                ),
                child: CircleAvatar(
                  radius: 24, backgroundColor: Colors.grey.shade100,
                  backgroundImage: img != null && img.isNotEmpty ? CachedNetworkImageProvider(img) : null,
                  child: (img == null || img.isEmpty) ? Icon(Icons.person_rounded, color: primaryBlue.withValues(alpha: 0.4)) : null,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        DateFormat('EEEE, d MMM').format(DateTime.now()),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)
                    ),
                    Text(
                        "Hi, $name",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E)),
                        overflow: TextOverflow.ellipsis
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // [BARU] Widget Kad Statistik Segi Empat (Sebaris)
  Widget _buildSquareStatCard(String label, String collection, IconData icon, Color color) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(collection).snapshots(),
        builder: (context, snapshot) {
          int count = 0;
          if (snapshot.hasData) count = snapshot.data!.docs.length;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  "$count",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E)),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLargeButton(BuildContext context, {required String title, required String subtitle, required IconData icon, required Widget page, Color? colorOverride}) {
    final bgColor = colorOverride ?? primaryBlue;

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: bgColor.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 26),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }
}