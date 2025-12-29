import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// Pastikan import ni betul ikut folder kau
import 'notifications/manager_notification_page.dart';

class ManagerDashboardPage extends StatelessWidget {
  const ManagerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color bgBlue = Color(0xFFF4F7FF); // Warna background premium

    return Scaffold(
      backgroundColor: bgBlue,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HeaderSection(),
            const SizedBox(height: 30),

            // --- QUICK STATS ROW ---
            _buildSectionTitle("Business Overview"),
            const SizedBox(height: 12),
            const _QuickStatsRow(),

            const SizedBox(height: 30),

            // --- PIE CHART ---
            _buildSectionTitle("Inventory Insights"),
            const SizedBox(height: 10),
            const _TotalProductsCard(),

            const SizedBox(height: 30),

            // --- BAR CHART ---
            _buildSectionTitle("Revenue Performance"),
            const SizedBox(height: 10),
            const _TotalSalesCard(),

            const SizedBox(height: 30),

            // --- TOP SELLING PRODUCTS ---
            _buildSectionTitle("Hot Items Today"),
            const SizedBox(height: 12),
            const _TopProductsList(), // Modul yang kita dah repair

            const SizedBox(height: 120), // Spacing extra bawah
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.indigo,
          letterSpacing: 1.2
      ),
    );
  }
}

// ==========================================================
// 1. HEADER SECTION (REAL-TIME USER)
// ==========================================================
class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final Color primaryBlue = const Color(0xFF233E99);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
      builder: (context, snapshot) {
        String name = "Manager";
        String? img;

        if (snapshot.hasData && snapshot.data!.exists) {
          var d = snapshot.data!.data() as Map<String, dynamic>;
          name = d['username'] ?? "Manager";
          img = d['profilePictureUrl'];
        }

        return Row(
          children: [
            Container(
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryBlue.withValues(alpha: 0.1), width: 2)
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                backgroundImage: (img != null && img.isNotEmpty) ? CachedNetworkImageProvider(img) : null,
                child: (img == null || img.isEmpty)
                    ? Icon(Icons.person_rounded, color: primaryBlue.withValues(alpha: 0.4))
                    : null,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('EEEE, d MMM').format(DateTime.now()),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  Text("Hi, $name",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E)),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            _NotificationButton(),
          ],
        );
      },
    );
  }
}

// ==========================================================
// 2. QUICK STATS ROW
// ==========================================================
class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // SALES TODAY
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('sales')
              .where('status', isEqualTo: 'completed')
              .where('saleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)))
              .snapshots(),
          builder: (context, snapshot) {
            double total = 0;
            if (snapshot.hasData) {
              for (var doc in snapshot.data!.docs) {
                total += (doc['totalAmount'] ?? 0.0);
              }
            }
            return _StatItem(
              label: "Sales Today",
              value: "RM ${total.toStringAsFixed(0)}",
              icon: Icons.monetization_on_rounded,
              color: Colors.green,
            );
          },
        ),
        const SizedBox(width: 15),
        // LOW STOCK ALERTS
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('products').snapshots(),
          builder: (context, snapshot) {
            int lowCount = 0;
            if (snapshot.hasData) {
              lowCount = snapshot.data!.docs.where((d) => (d['currentStock'] ?? 0) <= (d['reorderLevel'] ?? 10)).length;
            }
            return _StatItem(
              label: "Low Stock",
              value: "$lowCount Items",
              icon: Icons.warning_amber_rounded,
              color: Colors.orange,
            );
          },
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _StatItem({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 15),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// 3. PIE CHART CARD
// ==========================================================
class _TotalProductsCard extends StatelessWidget {
  const _TotalProductsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.indigo.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));

          Map<String, int> catCount = {};
          for (var doc in snapshot.data!.docs) {
            String cat = doc['category'] ?? 'Others';
            catCount[cat] = (catCount[cat] ?? 0) + 1;
          }

          final colors = [const Color(0xFF2D54FF), const Color(0xFFFF5B5B), const Color(0xFF00C566), const Color(0xFFFFBB38), Colors.purpleAccent];
          List<PieChartSectionData> sections = [];
          List<Widget> legend = [];
          int i = 0;

          catCount.forEach((key, val) {
            final clr = colors[i % colors.length];
            sections.add(PieChartSectionData(color: clr, value: val.toDouble(), radius: 22, showTitle: false));
            legend.add(_LegendRow(color: clr, label: key, count: val.toString()));
            i++;
          });

          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Product Breakdown", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text("${snapshot.data!.docs.length} Total", style: TextStyle(color: Colors.indigo.shade400, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(flex: 5, child: SizedBox(height: 140, child: PieChart(PieChartData(sectionsSpace: 4, centerSpaceRadius: 40, sections: sections)))),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: legend)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================================
// 4. BAR CHART CARD
// ==========================================================
class _TotalSalesCard extends StatelessWidget {
  const _TotalSalesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.indigo.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sales').where('status', isEqualTo: 'completed').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));

          Map<String, double> daily = {};
          List<String> labels = [];
          for (int i = 6; i >= 0; i--) {
            String d = DateFormat('EEE').format(DateTime.now().subtract(Duration(days: i)));
            labels.add(d); daily[d] = 0.0;
          }

          for (var doc in snapshot.data!.docs) {
            DateTime date = (doc['saleDate'] as Timestamp).toDate();
            String label = DateFormat('EEE').format(date);
            if (daily.containsKey(label)) daily[label] = daily[label]! + (doc['totalAmount'] ?? 0.0);
          }

          List<BarChartGroupData> groups = [];
          double maxVal = 100;
          for (int i = 0; i < labels.length; i++) {
            double v = daily[labels[i]]!;
            if (v > maxVal) maxVal = v;
            groups.add(BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: v, width: 14, borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(colors: [const Color(0xFF2D54FF), const Color(0xFF2D54FF).withValues(alpha: 0.6)], begin: Alignment.bottomCenter, end: Alignment.topCenter))
            ]));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("Weekly Revenue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Icon(Icons.trending_up, color: Colors.green, size: 20),
              ]),
              const SizedBox(height: 30),
              AspectRatio(
                aspectRatio: 1.7,
                child: BarChart(BarChartData(
                  maxY: maxVal * 1.3,
                  gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Padding(padding: const EdgeInsets.only(top: 10), child: Text(labels[v.toInt()], style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600))))),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, m) => Text(v >= 1000 ? "${(v/1000).toStringAsFixed(1)}k" : v.toInt().toString(), style: TextStyle(fontSize: 9, color: Colors.grey.shade400)))),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: groups,
                )),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================================
// 5. TOP SELLING PRODUCTS (HOT ITEMS) - REPAIRED LOGIC
// ==========================================================
// ==========================================================
// 5. TOP SELLING PRODUCTS (HOT ITEMS)
// ==========================================================
class _TopProductsList extends StatelessWidget {
  const _TopProductsList();

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Trending Now",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "Today",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 15),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sales')
                .where('saleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      "No sales recorded today.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              // Aggregation Logic: Summing up quantities by product name
              Map<String, int> productSales = {};

              for (var doc in snapshot.data!.docs) {
                Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

                // [FIXED] Using 'snapshotName' from the database screenshot
                String pName = data['snapshotName'] ?? 'Unknown Item';
                int qty = (data['quantitySold'] ?? 0) as int;

                if (productSales.containsKey(pName)) {
                  productSales[pName] = productSales[pName]! + qty;
                } else {
                  productSales[pName] = qty;
                }
              }

              // Sorting: Highest quantity first
              var sortedKeys = productSales.keys.toList(growable: false)
                ..sort((k1, k2) => productSales[k2]!.compareTo(productSales[k1]!));

              // Take top 3 items
              var top3 = sortedKeys.take(3).toList();

              return Column(
                children: top3.map((key) {
                  return _ProductListRow(
                    name: key,
                    count: "${productSales[key]} Sold",
                    // Highlight the top item with a distinct color
                    color: key == top3.first
                        ? const Color(0xFFFF5B5B)
                        : Colors.indigo.shade400,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- SMALL HELPER COMPONENTS ---

class _LegendRow extends StatelessWidget {
  final Color color; final String label; final String count;
  const _LegendRow({required this.color, required this.label, required this.count});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87), overflow: TextOverflow.ellipsis)),
        Text(count, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade400)),
      ]),
    );
  }
}

class _ProductListRow extends StatelessWidget {
  final String name, count; final Color color;
  const _ProductListRow({required this.name, required this.count, required this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: color.withValues(alpha: 0.1), child: Icon(Icons.star_rounded, color: color, size: 18)),
        const SizedBox(width: 15),
        Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        Text(count, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]),
      child: IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.black87, size: 22), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagerNotificationPage()))),
    );
  }
}