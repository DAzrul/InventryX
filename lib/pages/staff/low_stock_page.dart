import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LowStockPage extends StatefulWidget {
  const LowStockPage({super.key});

  @override
  State<LowStockPage> createState() => _LowStockPageState();
}

class _LowStockPageState extends State<LowStockPage> {
  final Color primaryBlue = const Color(0xFF1E3A8A);
  String selectedCategory = 'All';
  String sortBy = 'Urgency'; // Options: Urgency (Stock ASC), Price (DESC), Name (ASC)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("Low Stock Alerts",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.sort_rounded, color: primaryBlue),
            onSelected: (value) => setState(() => sortBy = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Urgency', child: Text("Sort by Urgency")),
              const PopupMenuItem(value: 'Price', child: Text("Sort by Price (High)")),
              const PopupMenuItem(value: 'Name', child: Text("Sort by Name")),
            ],
          )
        ],
      ),
      body: Column(
        children: [
          _buildCategoryFilter(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
              labelStyle: TextStyle(
                  color: isSel ? Colors.white : Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                  fontSize: 12
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        // 1. Filter Logic
        List<QueryDocumentSnapshot> list = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
          int reorderPoint = int.tryParse(data['reorderLevel']?.toString() ?? '10') ?? 10;

          bool isLow = stock <= reorderPoint;
          bool matchesCat = selectedCategory == 'All' || data['category'] == selectedCategory;

          return isLow && matchesCat;
        }).toList();

        // 2. Sort Logic
        list.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;

          if (sortBy == 'Urgency') {
            int stockA = int.tryParse(dataA['currentStock']?.toString() ?? '0') ?? 0;
            int stockB = int.tryParse(dataB['currentStock']?.toString() ?? '0') ?? 0;
            return stockA.compareTo(stockB); // Lowest first
          } else if (sortBy == 'Price') {
            double priceA = double.tryParse(dataA['price']?.toString() ?? '0.0') ?? 0.0;
            double priceB = double.tryParse(dataB['price']?.toString() ?? '0.0') ?? 0.0;
            return priceB.compareTo(priceA); // Highest first
          } else {
            return (dataA['productName'] ?? '').compareTo(dataB['productName'] ?? '');
          }
        });

        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text("No low stock items in $selectedCategory", style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final data = list[index].data() as Map<String, dynamic>;
            int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
            double price = double.tryParse(data['price']?.toString() ?? '0.0') ?? 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
              ),
              child: Row(
                children: [
                  _buildThumbnail(data['imageUrl']),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['productName'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text("RM ${price.toStringAsFixed(2)}",
                            style: TextStyle(color: primaryBlue.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  _buildStockBadge(stock, data['unit'] ?? 'pcs'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThumbnail(String? url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: (url != null && url.isNotEmpty)
          ? CachedNetworkImage(imageUrl: url, width: 55, height: 55, fit: BoxFit.cover)
          : Container(
        width: 55, height: 55,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: primaryBlue.withOpacity(0.1))),
        child: Icon(Icons.inventory_2_rounded, color: primaryBlue.withOpacity(0.3)),
      ),
    );
  }

  Widget _buildStockBadge(int stock, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$stock', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.red)),
        Text(unit, style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.bold))
      ],
    );
  }
}