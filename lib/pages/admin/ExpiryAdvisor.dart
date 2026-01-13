import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ExpiryAdvisor extends StatefulWidget {
  const ExpiryAdvisor({super.key});

  @override
  State<ExpiryAdvisor> createState() => _ExpiryAdvisorState();
}

class _ExpiryAdvisorState extends State<ExpiryAdvisor> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Data Structure: ProductID -> {avgDays, minDays, maxDays, totalBatches}
  Map<String, Map<String, int>> _shelfLifeStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _analyzeRealWorldExpiry();
  }

  // 🧠 ANALISIS REAL-WORLD EXPIRY DARI DATA SEJARAH
  void _analyzeRealWorldExpiry() {
    _db.collection('batches').snapshots().listen((snapshot) {
      Map<String, List<int>> tempDurations = {};

      for (var doc in snapshot.docs) {
        var data = doc.data();
        String pid = data['productId'] ?? '';
        Timestamp? received = data['receivedDate'];
        Timestamp? expiry = data['expiryDate'];

        if (pid.isNotEmpty && received != null && expiry != null) {
          // Kira beza hari sebenar (Expiry - Received)
          int days = expiry.toDate().difference(received.toDate()).inDays;
          if (days > 0) {
            tempDurations.putIfAbsent(pid, () => []).add(days);
          }
        }
      }

      // Proses Statistik
      Map<String, Map<String, int>> finalStats = {};
      tempDurations.forEach((pid, list) {
        list.sort(); // Susun rendah ke tinggi
        int sum = list.reduce((a, b) => a + b);
        int avg = (sum / list.length).round();
        int min = list.first;
        int max = list.last;

        finalStats[pid] = {
          'avg': avg,
          'min': min,
          'max': max,
          'count': list.length
        };
      });

      if (mounted) {
        setState(() {
          _shelfLifeStats = finalStats;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0), // Latar oren lembut
      appBar: AppBar(
        title: const Text("Shelf Life Predictor", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || _isLoading) return const Center(child: CircularProgressIndicator(color: Colors.orange));

          var docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 15),
            itemBuilder: (ctx, i) {
              var data = docs[i].data() as Map<String, dynamic>;
              String pid = docs[i].id;
              String name = data['productName'] ?? 'Unknown';
              String img = data['imageUrl'] ?? '';

              // Ambil data statistik expiry
              var stats = _shelfLifeStats[pid];

              return _buildShelfLifeCard(name, img, stats);
            },
          );
        },
      ),
    );
  }

  Widget _buildShelfLifeCard(String name, String img, Map<String, int>? stats) {
    bool hasData = stats != null;
    int avgDays = hasData ? stats['avg']! : 0;

    // --- LOGIK BARU: KIRA TARIKH MASA DEPAN ---
    DateTime today = DateTime.now();
    DateTime predictedExpiryDate = today.add(Duration(days: avgDays));

    // Format tarikh cantik sikit (Contoh: 20 Jan 2026)
    String expiryLabel = hasData
        ? DateFormat('dd MMM yyyy (EEEE)').format(predictedExpiryDate)
        : "-";

    // Tentukan Kategori Expiry
    Color statusColor = Colors.grey;
    String statusLabel = "No History";
    IconData statusIcon = Icons.help_outline;

    if (hasData) {
      if (avgDays <= 7) {
        statusColor = Colors.red;
        statusLabel = "Very Fresh (Short Life)"; // Roti
        statusIcon = Icons.warning_rounded;
      } else if (avgDays <= 30) {
        statusColor = Colors.orange;
        statusLabel = "Perishable"; // Susu
        statusIcon = Icons.access_time_rounded;
      } else {
        statusColor = Colors.green;
        statusLabel = "Long Lasting"; // Tin
        statusIcon = Icons.verified_user_rounded;
      }
    }

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
          border: hasData ? Border(left: BorderSide(color: statusColor, width: 5)) : null
      ),
      child: Column(
        children: [
          // BAHAGIAN ATAS: Info Produk & Stats
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: (img.isNotEmpty)
                      ? CachedNetworkImage(imageUrl: img, width: 60, height: 60, fit: BoxFit.cover, errorWidget: (_,__,___)=> Container(color: Colors.grey.shade100))
                      : Container(width: 60, height: 60, color: Colors.grey.shade100, child: const Icon(Icons.inventory_2, color: Colors.grey)),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 5),
                          Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (hasData)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem("Shelf Life", "$avgDays Days"),
                            _buildStatItem("History", "${stats['count']} Batches"),
                          ],
                        )
                      else
                        const Text("No past data yet.", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // BAHAGIAN BAWAH: Ramalan Tarikh (KALAU RESTOCK HARI INI)
          if (hasData)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("IF RESTOCK TODAY:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
                      Text("Valid until:", style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 18, color: Colors.black87),
                      const SizedBox(width: 6),
                      Text(expiryLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87)),
                    ],
                  )
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
        Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }
}