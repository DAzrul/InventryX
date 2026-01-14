import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AIAdvisorPage extends StatefulWidget {
  const AIAdvisorPage({super.key});

  @override
  State<AIAdvisorPage> createState() => _AIAdvisorPageState();
}

class _AIAdvisorPageState extends State<AIAdvisorPage> {
  final Color primaryBlue = const Color(0xFF1E3A8A);
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _searchQuery = '';

  // TOGGLE: False = Weekly (7 Days), True = Monthly (30 Days)
  bool _isMonthlyPlan = false;

  // --- MEMORY OTAK AI ---
  Map<String, int> _forecastMap = {};
  Map<String, int> _historyExpiryDays = {};
  Map<String, double> _realSalesVelocity = {};

  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _trainAiWithHistory();
  }

  // ============================================================
  // 🧠 FASA 1: TRAIN AI (DATA COLLECTION - REAL TIME)
  // ============================================================
  void _trainAiWithHistory() {

    // 1. BATCHES (Belajar Jangka Hayat Sebenar)
    _db.collection('batches').snapshots().listen((snapshot) {
      Map<String, List<int>> tempExpiry = {};
      for (var doc in snapshot.docs) {
        var data = doc.data();
        String pid = data['productId'] ?? '';
        Timestamp? received = data['receivedDate'];
        Timestamp? expiry = data['expiryDate'];

        if (pid.isNotEmpty && received != null && expiry != null) {
          int days = expiry.toDate().difference(received.toDate()).inDays;
          if (days > 0) tempExpiry.putIfAbsent(pid, () => []).add(days);
        }
      }
      if (mounted) {
        setState(() {
          tempExpiry.forEach((key, list) {
            _historyExpiryDays[key] = (list.reduce((a, b) => a + b) / list.length).round();
          });
        });
      }
    });

    // 2. STOCK MOVEMENTS (Belajar Kelajuan Jualan Sebenar)
    _db.collection('stockMovements').snapshots().listen((snapshot) {
      Map<String, int> tempTotalSold = {};
      Map<String, DateTime> firstSaleDate = {};
      Map<String, DateTime> lastSaleDate = {};

      for (var doc in snapshot.docs) {
        var data = doc.data();
        String pid = data['productId'] ?? '';
        String type = (data['type'] ?? '').toString().toUpperCase();
        int qty = int.tryParse(data['quantity']?.toString() ?? '0') ?? 0;
        Timestamp? ts = data['timestamp'];

        if (pid.isNotEmpty && (type == 'SOLD' || type == 'SALES ORDER') && qty < 0) {
          tempTotalSold[pid] = (tempTotalSold[pid] ?? 0) + qty.abs();

          if (ts != null) {
            DateTime date = ts.toDate();
            if (!firstSaleDate.containsKey(pid) || date.isBefore(firstSaleDate[pid]!)) firstSaleDate[pid] = date;
            if (!lastSaleDate.containsKey(pid) || date.isAfter(lastSaleDate[pid]!)) lastSaleDate[pid] = date;
          }
        }
      }

      if (mounted) {
        setState(() {
          tempTotalSold.forEach((pid, totalSold) {
            double daysActive = 1.0;
            if (firstSaleDate.containsKey(pid) && lastSaleDate.containsKey(pid)) {
              int daysDiff = lastSaleDate[pid]!.difference(firstSaleDate[pid]!).inDays;
              daysActive = daysDiff < 1 ? 1.0 : daysDiff.toDouble();
            }
            _realSalesVelocity[pid] = totalSold / daysActive;
          });
        });
      }
    });

    // 3. FORECASTS (Ambil data forecast terkini)
    _db.collection('forecasts')
        .orderBy('forecastDate', descending: true) // Paling baru di atas
        .snapshots()
        .listen((snapshot) {

      Map<String, int> tempForecast = {};

      for (var doc in snapshot.docs) {
        var data = doc.data();
        String pid = data['productId'] ?? data['productID'] ?? '';
        int demand = int.tryParse(data['predictedDemand']?.toString() ?? '0') ?? 0;

        // Ambil yang paling baru sahaja (top of the list)
        if (pid.isNotEmpty && !tempForecast.containsKey(pid)) {
          tempForecast[pid] = demand;
        }
      }

      if(mounted) {
        setState(() {
          _forecastMap = tempForecast;
          _isLoadingData = false;
        });
      }
    });
  }

  // ============================================================
  // 🧠 LOGIK 2: ANALISIS EXPIRY
  // ============================================================
  Map<String, dynamic> _analyzeExpiry(String pid, String productName, String? category) {
    DateTime today = DateTime.now();

    if (_historyExpiryDays.containsKey(pid)) {
      int avgDays = _historyExpiryDays[pid]!;
      return {'date': today.add(Duration(days: avgDays)), 'days': avgDays, 'label': '', 'color': Colors.indigo};
    }

    String pName = productName.toUpperCase();
    String cat = (category ?? '').toUpperCase();

    if (pName.contains('ROTI') || pName.contains('GARDENIA') || (pName.contains('KEK') && !cat.contains('FROZEN'))) {
      return {'date': today.add(const Duration(days: 5)), 'days': 5, 'label': 'Fresh Bakery', 'color': Colors.red};
    } else if ((pName.contains('MILK') || pName.contains('SUSU')) && !pName.contains('UHT')) {
      return {'date': today.add(const Duration(days: 21)), 'days': 21, 'label': 'Fresh Dairy', 'color': Colors.orange};
    } else if (cat.contains('FROZEN') || pName.contains('ICE CREAM')) {
      return {'date': today.add(const Duration(days: 270)), 'days': 270, 'label': 'Frozen Food', 'color': Colors.blue};
    } else if (cat.contains('CANNED') || cat.contains('DRY') || pName.contains('UHT')) {
      return {'date': today.add(const Duration(days: 540)), 'days': 540, 'label': 'Long Life', 'color': Colors.green};
    } else {
      return {'date': today.add(const Duration(days: 180)), 'days': 180, 'label': 'Estimated', 'color': Colors.grey};
    }
  }

  // ============================================================
  // 🧠 LOGIK 3: RESTOCK (FIXED MATH & DYNAMIC CAP)
  // ============================================================
  Map<String, dynamic> _analyzeRestock(String pid, int currentStock, int unitsPerCarton, int? forecastValue, int shelfLifeDays, bool isMonthlyMode) {

    int upc = unitsPerCarton > 0 ? unitsPerCarton : 1;
    bool isSingleUnit = upc == 1; // Jika 1 unit per carton, anggap barang loose

    // 1. TENTUKAN VELOCITY (JUALAN HARIAN)
    double dailyVelocity = 0.0;

    // [FIXED] Bahagi 7.0 sebab data forecast adalah Mingguan!
    double forecastDaily = (forecastValue ?? 0) / 7.0;

    double historyDaily = _realSalesVelocity[pid] ?? 0.0;

    // Ambil nilai tertinggi antara Forecast vs History (Safety Stock)
    dailyVelocity = forecastDaily > historyDaily ? forecastDaily : historyDaily;

    if (dailyVelocity <= 0.1) {
      return {'qty': 0, 'status': 'IDLE', 'color': Colors.grey, 'msg': 'Tiada data jualan aktif.', 'info': 'N/A', 'isSingle': isSingleUnit};
    }

    // 2. TENTUKAN TARGET HARI
    int targetDays = isMonthlyMode ? 30 : 7;
    String modeLabel = isMonthlyMode ? "Monthly" : "Weekly";

    // 3. SAFEGUARD PINTAR (DYNAMIC CAP - EXPIRY CHECK)
    int maxSafeDays = shelfLifeDays - 1; // Buffer 1 hari sebelum expired
    if (maxSafeDays < 1) maxSafeDays = 1;

    String warningMsg = "";
    Color statusColor = isMonthlyMode ? Colors.purple : Colors.blue;

    // Jika Target Plan (cth: 30 hari) MELEBIHI Jangka Hayat (cth: Roti 5 hari)
    // Kita potong target jadi 4 hari.
    if (targetDays > maxSafeDays) {
      targetDays = maxSafeDays;
      warningMsg = " (Capped at Shelf Life)";
      statusColor = Colors.orange; // Tanda amaran sikit
    }

    // 4. KIRA ORDER
    // Target Stock = Jualan Sehari * Hari Sasaran (yang dah di-adjust)
    int idealStockLevel = (dailyVelocity * targetDays).ceil();

    int shortage = idealStockLevel - currentStock;

    // Kiraan order dalam Carton (atau Unit jika UPC=1)
    int orderQty = (shortage > 0) ? (shortage / upc).ceil() : 0;

    if (orderQty > 0) {
      return {
        'qty': orderQty,
        'status': '$modeLabel Restock',
        'color': statusColor,
        'msg': 'Shortage: $shortage units.$warningMsg',
        'isSingle': isSingleUnit
      };
    } else {
      return {
        'qty': 0,
        'status': 'OPTIMAL',
        'color': Colors.green,
        'msg': 'Stock sufficient for $targetDays days.',
        'isSingle': isSingleUnit
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("AI Inventory Analyst", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_isLoadingData)
            const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)))
        ],
      ),
      body: Column(
        children: [
          // HEADER DASHBOARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Column(
              children: [
                // Toggle Weekly / Monthly
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(25)),
                  child: Row(
                    children: [
                      Expanded(child: _buildToggleBtn("Weekly (7 Days)", !_isMonthlyPlan)),
                      Expanded(child: _buildToggleBtn("Monthly (30 Days)", _isMonthlyPlan)),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  _isMonthlyPlan
                      ? "Planning Mode: BULK ORDER (Max 30 days stock)"
                      : "Planning Mode: FAST ROTATION (Max 7 days stock)",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: "Search product...",
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true, fillColor: const Color(0xFFF0F4F8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),

          // LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs.where((d) {
                  var data = d.data() as Map<String, dynamic>;
                  String name = (data['productName'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                if (docs.isEmpty) return const Center(child: Text("No products found.", style: TextStyle(color: Colors.grey)));

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                  itemBuilder: (ctx, i) {
                    var data = docs[i].data() as Map<String, dynamic>;
                    String pid = docs[i].id;
                    String name = data['productName'] ?? 'Unknown';
                    String cat = data['category'] ?? '-';
                    String img = data['imageUrl'] ?? '';
                    int currentStock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
                    int upc = int.tryParse(data['unitsPerCarton']?.toString() ?? '1') ?? 1;

                    // AI ANALYTICS
                    var expiryResult = _analyzeExpiry(pid, name, cat);
                    int shelfLife = expiryResult['days'];

                    var restockResult = _analyzeRestock(pid, currentStock, upc, _forecastMap[pid], shelfLife, _isMonthlyPlan);

                    return _buildAiCard(name, img, currentStock, upc, expiryResult, restockResult);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => _isMonthlyPlan = label.contains("Monthly")),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)] : []
        ),
        child: Text(label, style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.blue.shade900 : Colors.grey)
        ),
      ),
    );
  }

  Widget _buildAiCard(String name, String img, int stock, int upc, Map expiry, Map restock) {
    bool isSingle = restock['isSingle'] ?? false;
    String subLabel = isSingle ? "Units" : "Cartons";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          // INFO
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: (img.isNotEmpty)
                      ? CachedNetworkImage(imageUrl: img, width: 60, height: 60, fit: BoxFit.cover, errorWidget: (_,__,___)=> Container(color: Colors.grey.shade100))
                      : Container(width: 60, height: 60, color: Colors.grey.shade100, child: const Icon(Icons.inventory_2_rounded, color: Colors.grey)),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                        isSingle ? "Stock: $stock units" : "Stock: $stock units | 1 Ctn = $upc units",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600)
                    ),
                  ]),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade100),

          // GRID AI
          IntrinsicHeight(
            child: Row(
              children: [
                // EXPIRY SIDE
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (expiry['color'] as Color).withOpacity(0.05),
                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.history_toggle_off, size: 16, color: expiry['color']),
                        const SizedBox(width: 6),
                        Text("SHELF LIFE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: expiry['color']))
                      ]),
                      const SizedBox(height: 8),
                      Text("${expiry['days']} Days", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: expiry['color'])),
                      Text(expiry['label'], style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
                    ]),
                  ),
                ),

                VerticalDivider(width: 1, color: Colors.grey.shade200),

                // RESTOCK SIDE (ADAPTIVE UI)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (restock['color'] as Color).withOpacity(0.05),
                      borderRadius: const BorderRadius.only(bottomRight: Radius.circular(20)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(isSingle ? Icons.shopping_bag_outlined : Icons.shopping_cart, size: 16, color: restock['color']),
                        const SizedBox(width: 6),
                        Text("SUGGESTION", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: restock['color']))
                      ]),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("+${restock['qty']}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: restock['color'])),
                          Padding(padding: const EdgeInsets.only(bottom: 3, left: 2), child: Text(subLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      Text(restock['info'], style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey.shade700)),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          // MESSAGE BAR
          if (restock['qty'] > 0 || restock['status'].contains('Restock'))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: (restock['color'] as Color).withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, size: 14, color: restock['color']),
                  const SizedBox(width: 8),
                  Expanded(child: Text(restock['msg'], style: TextStyle(fontSize: 11, color: restock['color'], fontWeight: FontWeight.w600))),
                ],
              ),
            )
        ],
      ),
    );
  }
}