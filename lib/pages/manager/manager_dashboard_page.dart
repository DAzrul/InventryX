import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// TODO: Create this page later
import 'notifications/manager_notification_page.dart';

class ManagerDashboardPage extends StatelessWidget {
  const ManagerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _HeaderSection(),
          SizedBox(height: 25),
          _TotalProductsCard(),
          SizedBox(height: 20),
          _TotalSalesCard(),
          SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ───────────────────────────────── HEADER ─────────────────────────────────
class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) return const Text("Sila Login");

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        String displayUsername = "User";
        String? photoUrl;

        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          displayUsername = data['username'] ?? user.email ?? "User";
          photoUrl = data['profilePictureUrl'];
        }

        return Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey[300],
              backgroundImage:
              (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              displayUsername,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Spacer(),

            /// 🔔 NOTIFICATION BUTTON
            IconButton(
              icon: const Icon(
                Icons.notifications_none,
                color: Colors.black87,
                size: 24,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                    const ManagerNotificationPage(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ───────────────────────────── PIE CHART ─────────────────────────────
class _TotalProductsCard extends StatelessWidget {
  const _TotalProductsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Total Products",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _LegendItem(color: Color(0xFF1E3A8A), text: "Breads"),
                    _LegendItem(color: Color(0xFFBFDBFE), text: "Meats"),
                    _LegendItem(color: Color(0xFFE0E0E0), text: "Fresh Drinks"),
                    _LegendItem(color: Color(0xFFFFD54F), text: "Milk & Yogurt"),
                    _LegendItem(color: Color(0xFFEF5350), text: "Grocery"),
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 0,
                      sections: [
                        PieChartSectionData(
                          color: Color(0xFF1E3A8A),
                          value: 36,
                          title: "36%",
                          radius: 65,
                          titleStyle: _pieText,
                        ),
                        PieChartSectionData(
                          color: Color(0xFFEF5350),
                          value: 9,
                          title: "9%",
                          radius: 65,
                          titleStyle: _pieText,
                        ),
                        PieChartSectionData(
                          color: Color(0xFFFFD54F),
                          value: 13,
                          title: "13%",
                          radius: 65,
                          titleStyle: _pieText,
                        ),
                        PieChartSectionData(
                          color: Color(0xFFE0E0E0),
                          value: 17,
                          title: "17%",
                          radius: 65,
                          titleStyle: _pieText,
                        ),
                        PieChartSectionData(
                          color: Color(0xFFBFDBFE),
                          value: 25,
                          title: "25%",
                          radius: 65,
                          titleStyle: _pieText,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const TextStyle _pieText =
  TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white);
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Container(width: 10, height: 10, color: color),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ───────────────────────────── BAR CHART ─────────────────────────────
class _TotalSalesCard extends StatelessWidget {
  const _TotalSalesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Total Sales",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 30),
          AspectRatio(
            aspectRatio: 1.4,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 3000,
                barTouchData: BarTouchData(enabled: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: 1875,
                        color: Color(0xFF1E3A8A),
                        width: 40,
                        borderRadius: BorderRadius.circular(4),
                      )
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: 2500,
                        color: Color(0xFF1E3A8A),
                        width: 40,
                        borderRadius: BorderRadius.circular(4),
                      )
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(
                        toY: 1250,
                        color: Color(0xFF1E3A8A),
                        width: 40,
                        borderRadius: BorderRadius.circular(4),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
