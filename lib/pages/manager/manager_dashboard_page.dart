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
<<<<<<< HEAD
          _TotalProductsCard(),
          SizedBox(height: 20),
=======

          // 2. Pie Chart Card (REAL DATA NOW)
          _TotalProductsCard(),
          SizedBox(height: 20),

          // 3. Bar Chart Card (Masih Dummy - Nanti kita fix kalau kau nak)
>>>>>>> 0016de6576aaee886269ef4056cfdfee76d3c978
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
<<<<<<< HEAD
=======

          // DATA DARI GAMBAR DATABASE ANDA:
>>>>>>> 0016de6576aaee886269ef4056cfdfee76d3c978
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
<<<<<<< HEAD

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
=======
            // Ikon Hiasan
            const Icon(Icons.notifications_none, size: 24, color: Colors.black87),
>>>>>>> 0016de6576aaee886269ef4056cfdfee76d3c978
          ],
        );
      },
    );
  }
}

<<<<<<< HEAD
// ───────────────────────────── PIE CHART ─────────────────────────────
=======
// --- WIDGET PIE CHART (FIXED COLORS) ---
>>>>>>> 0016de6576aaee886269ef4056cfdfee76d3c978
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
<<<<<<< HEAD
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
=======
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5))
>>>>>>> 0016de6576aaee886269ef4056cfdfee76d3c978
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
<<<<<<< HEAD
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
=======
          const Text("Total Products",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54)),
          const SizedBox(height: 20),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('products').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No products found."));
              }

              // 1. KIRA DATA
              Map<String, int> categoryCount = {};
              int totalProducts = snapshot.data!.docs.length;

              for (var doc in snapshot.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;
                String subCat = data['subCategory'] ?? 'Others';

                if (categoryCount.containsKey(subCat)) {
                  categoryCount[subCat] = categoryCount[subCat]! + 1;
                } else {
                  categoryCount[subCat] = 1;
                }
              }

              // 2. DEFINISI PALETTE WARNA (Fixed & Distinct)
              // Ni senarai warna yang confirm tak sama. Dia akan pusing balik ke atas kalau category terlalu banyak.
              final List<Color> distinctColors = [
                const Color(0xFF1E3A8A), // Biru Gelap
                const Color(0xFFEF5350), // Merah
                const Color(0xFF66BB6A), // Hijau Terang
                const Color(0xFFFFD54F), // Kuning
                const Color(0xFFAB47BC), // Purple
                const Color(0xFF26C6DA), // Cyan
                const Color(0xFFFF7043), // Oren
                const Color(0xFF8D6E63), // Coklat
                const Color(0xFF78909C), // Kelabu Biru
                const Color(0xFFEC407A), // Pink
              ];

              List<PieChartSectionData> chartSections = [];
              List<Widget> legendItems = [];

              int colorIndex = 0; // Kita pakai index ni untuk assign warna

              categoryCount.forEach((key, value) {
                final double percentage = (value / totalProducts) * 100;

                // Logic pick color ikut giliran, bukan random
                final Color sectionColor = distinctColors[colorIndex % distinctColors.length];

                chartSections.add(
                  PieChartSectionData(
                    color: sectionColor,
                    value: value.toDouble(),
                    title: "${percentage.toStringAsFixed(0)}%",
                    radius: 65,
                    titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                );

                legendItems.add(_LegendItem(color: sectionColor, text: key));

                colorIndex++; // Next category pakai next color
              });

              return Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: legendItems,
>>>>>>> 0016de6576aaee886269ef4056cfdfee76d3c978
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 140,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 0,
                          sections: chartSections,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
<<<<<<< HEAD

  static const TextStyle _pieText =
  TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white);
=======
>>>>>>> 0016de6576aaee886269ef4056cfdfee76d3c978
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

<<<<<<< HEAD
// ───────────────────────────── BAR CHART ─────────────────────────────
=======
// --- WIDGET BAR CHART (STATIC / DUMMY) ---
>>>>>>> 0016de6576aaee886269ef4056cfdfee76d3c978
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
<<<<<<< HEAD
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
=======
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5))
>>>>>>> 0016de6576aaee886269ef4056cfdfee76d3c978
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
<<<<<<< HEAD
          const Text(
            "Total Sales",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
=======
          const Text("Total Sales",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54)),
>>>>>>> 0016de6576aaee886269ef4056cfdfee76d3c978
          const SizedBox(height: 30),
          AspectRatio(
            aspectRatio: 1.4,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 3000,
                barTouchData: BarTouchData(enabled: false),
                gridData: FlGridData(
<<<<<<< HEAD
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
=======
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey[200],
                        strokeWidth: 1,
                        dashArray: [5, 5])),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 35,
                          interval: 1000,
                          getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 10)))),
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            switch (value.toInt()) {
                              case 0:
                                return const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text("21 Nov",
                                        style: TextStyle(fontSize: 10)));
                              case 1:
                                return const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text("22 Nov",
                                        style: TextStyle(fontSize: 10)));
                              case 2:
                                return const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text("23 Nov",
                                        style: TextStyle(fontSize: 10)));
                            }
                            return const Text("");
                          })),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [
                    BarChartRodData(
                        toY: 1875,
                        color: const Color(0xFF1E3A8A),
                        width: 40,
                        borderRadius: BorderRadius.circular(4))
                  ]),
                  BarChartGroupData(x: 1, barRods: [
                    BarChartRodData(
                        toY: 2500,
                        color: const Color(0xFF1E3A8A),
                        width: 40,
                        borderRadius: BorderRadius.circular(4))
                  ]),
                  BarChartGroupData(x: 2, barRods: [
                    BarChartRodData(
                        toY: 1250,
                        color: const Color(0xFF1E3A8A),
                        width: 40,
                        borderRadius: BorderRadius.circular(4))
                  ]),
>>>>>>> 0016de6576aaee886269ef4056cfdfee76d3c978
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
