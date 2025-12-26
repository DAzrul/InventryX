import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'add_incoming_stock.dart';
import 'stock_out.dart';
import '../Features_app/barcode_scanner_page.dart';

class StockPage extends StatefulWidget {
  final String username;
  const StockPage({super.key, required this.username});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  String selectedCategory = 'All';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Color primaryBlue = const Color(0xFF1E3A8A); // Warna indigo premium

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final scannedResult = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );

    if (scannedResult != null && scannedResult.isNotEmpty) {
      setState(() {
        searchQuery = scannedResult;
        _searchController.text = scannedResult;
      });
    }
  }

  // ======================== MODAL DETAILS KEMAS ========================
  void _showProductDetails(Map<String, dynamic> data, String productId) {
    int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
    String imgUrl = data['imageUrl'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Product Header Premium
                  Row(
                    children: [
                      _buildProductImage(imgUrl, size: 80),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['productName'] ?? 'Unknown', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                            Text("SKU: ${data['barcodeNo'] ?? '-'}", style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  _buildQuickStats(data, stock),
                  const SizedBox(height: 30),
                  const Text("Active Batches", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 15),
                  _buildBatchStream(productId, data['unit'] ?? 'pcs'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text("Inventory Management", style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildCombinedSummary(), //
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildActionButtons(),
                const SizedBox(height: 20),
                _buildSearchBar(),
                const SizedBox(height: 15),
                _buildCategoryFilter(),
              ],
            ),
          ),
          Expanded(child: _buildProductStream()),
        ],
      ),
    );
  }

  // --- UI COMPONENTS PREMIUM ---

  Widget _buildCombinedSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('products').snapshots(),
      builder: (context, prodSnap) => StreamBuilder<QuerySnapshot>(
        stream: _db.collection('batches').snapshots(),
        builder: (context, batchSnap) {
          int total = prodSnap.hasData ? prodSnap.data!.docs.length : 0;
          int low = 0;
          int expired = 0;

          if (prodSnap.hasData) {
            for (var d in prodSnap.data!.docs) {
              int q = int.tryParse(d['currentStock']?.toString() ?? '0') ?? 0;
              if (q > 0 && q <= 10) low++;
            }
          }

          if (batchSnap.hasData) {
            DateTime now = DateTime.now();
            for (var d in batchSnap.data!.docs) {
              var b = d.data() as Map<String, dynamic>;
              if (b['expiryDate'] != null && (b['currentQuantity'] ?? 0) > 0) {
                if ((b['expiryDate'] as Timestamp).toDate().isBefore(now)) expired++;
              }
            }
          }

          return Container(
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SummaryItem(value: '$total', label: 'Total SKUs', color: primaryBlue),
                _SummaryItem(value: '$low', label: 'Low Stock', color: Colors.orange),
                _SummaryItem(value: '$expired', label: 'Expired', color: Colors.red),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(children: [
      Expanded(child: _actionBtn("Stock In", Icons.add_box_rounded, primaryBlue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddIncomingStockPage(username: widget.username))))),
      const SizedBox(width: 12),
      Expanded(child: _actionBtn("Stock Out", Icons.indeterminate_check_box_rounded, Colors.red.shade700, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockOutPage())))),
    ]);
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: Colors.white),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => searchQuery = v),
              decoration: const InputDecoration(hintText: "Search products...", border: InputBorder.none, hintStyle: TextStyle(fontSize: 14)),
            ),
          ),
          IconButton(icon: Icon(Icons.qr_code_scanner_rounded, color: primaryBlue), onPressed: _scanBarcode),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: ['All', 'FOOD', 'BEVERAGES', 'PERSONAL CARE'].map((cat) {
          final isSel = selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSel,
              onSelected: (_) => setState(() => selectedCategory = cat),
              selectedColor: primaryBlue,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(color: isSel ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSel ? primaryBlue : Colors.grey.shade100)),
              elevation: 0,
              pressElevation: 0,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProductStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final name = (d['productName'] ?? '').toString().toLowerCase();
          final barcode = (d['barcodeNo'] ?? '').toString().toLowerCase();
          return (selectedCategory == 'All' || d['category'] == selectedCategory) &&
              (name.contains(searchQuery.toLowerCase()) || barcode.contains(searchQuery.toLowerCase()));
        }).toList();

        if (docs.isEmpty) return Center(child: Text("No products found.", style: TextStyle(color: Colors.grey.shade400)));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
            return _buildProductCard(data, docs[index].id, stock);
          },
        );
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> data, String id, int stock) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: ListTile(
        onTap: () => _showProductDetails(data, id),
        contentPadding: const EdgeInsets.all(12),
        leading: _buildProductImage(data['imageUrl'], size: 55),
        title: Text(data['productName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        subtitle: Text("ID: ${data['barcodeNo'] ?? '-'}", style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: stock <= 10 ? Colors.red : primaryBlue)),
            Text(data['unit'] ?? 'pcs', style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(String? url, {double size = 50}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: const Color(0xFFF0F2F6), borderRadius: BorderRadius.circular(15)),
      child: (url != null && url.isNotEmpty)
          ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(url, fit: BoxFit.cover))
          : Icon(Icons.inventory_2_rounded, color: primaryBlue, size: size * 0.5),
    );
  }

  Widget _buildQuickStats(Map<String, dynamic> data, int stock) {
    String status = stock <= 0 ? "Out of Stock" : (stock <= 10 ? "Low Stock" : "Healthy");
    Color color = stock <= 0 ? Colors.red : (stock <= 10 ? Colors.orange : Colors.green);
    return Row(children: [
      _infoBox("Current Status", status, color),
      const SizedBox(width: 12),
      _infoBox("Main Supplier", data['supplier'] ?? 'N/A', primaryBlue),
    ]);
  }

  Widget _infoBox(String t, String v, Color c) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(18), border: Border.all(color: c.withValues(alpha: 0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: TextStyle(fontSize: 10, color: c.withValues(alpha: 0.6), fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: c)),
      ]),
    ));
  }

  Widget _buildBatchStream(String pid, String unit) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('batches').where('productId', isEqualTo: pid).where('currentQuantity', isGreaterThan: 0).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Center(child: Text("No active batches.", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)));
        return Column(children: docs.map((doc) {
          final b = doc.data() as Map<String, dynamic>;
          final exp = b['expiryDate'] != null ? (b['expiryDate'] as Timestamp).toDate() : null;
          final isExp = exp != null && exp.isBefore(DateTime.now());
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: isExp ? Colors.red.withValues(alpha: 0.2) : Colors.grey.shade100)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Batch #${b['batchNumber'] ?? '-'}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                if (exp != null) Text("Exp: ${DateFormat('dd/MM/yyyy').format(exp)}", style: TextStyle(fontSize: 11, color: isExp ? Colors.red : Colors.grey)),
              ]),
              Text("${b['currentQuantity']} $unit", style: TextStyle(fontWeight: FontWeight.w900, color: primaryBlue)),
            ]),
          );
        }).toList());
      },
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String value, label; final Color color;
  const _SummaryItem({required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w700)),
    ]);
  }
}