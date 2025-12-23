import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_incoming_stock.dart';
import 'stock_out.dart';

class StockDisplayPage extends StatefulWidget {
  @override
  _StockDisplayPageState createState() => _StockDisplayPageState();
}

class _StockDisplayPageState extends State<StockDisplayPage> {
  final Color mainBlue = const Color(0xFF00147C);

  List<DisplayProduct> products = [];
  int _selectedTab = 1;
  bool _isLoading = true;

  Map<int, bool> editingStates = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final fetchedProducts = await fetchProducts();
      setState(() {
        products = fetchedProducts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading products: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<List<DisplayProduct>> fetchProducts() async {
    final stockSnapshot =
    await FirebaseFirestore.instance.collection('stock').get();

    if (stockSnapshot.docs.isEmpty) return [];

    final Map<String, Map<String, dynamic>> stockData = {};

    for (var doc in stockSnapshot.docs) {
      final String productId = doc['productId'];
      final int quantity = (doc['quantity'] as num).toInt();
      final DateTime expiry =
      (doc['expiryDate'] as Timestamp).toDate();

      if (stockData.containsKey(productId)) {
        stockData[productId]!['total'] += quantity;
        if (expiry.isBefore(stockData[productId]!['expiry'])) {
          stockData[productId]!['expiry'] = expiry;
        }
      } else {
        stockData[productId] = {
          'total': quantity,
          'expiry': expiry,
        };
      }
    }

    List<DisplayProduct> result = [];

    for (final productId in stockData.keys) {
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

      if (!productDoc.exists) continue;

      final productData = productDoc.data()!;

      final displaySnapshot = await FirebaseFirestore.instance
          .collection('onDisplay')
          .where('productId', isEqualTo: productId)
          .limit(1)
          .get();

      final int onDisplay = displaySnapshot.docs.isNotEmpty
          ? (displaySnapshot.docs.first['onDisplayQuantity'] as num).toInt()
          : 0;

      final int total = stockData[productId]!['total'];
      final int balance = total - onDisplay;

      result.add(
        DisplayProduct(
          name: productData['productName'] ?? '',
          sku: productData['barcodeNo']?.toString() ?? '',
          total: total,
          onDisplay: onDisplay,
          balance: balance,
          expiry: (stockData[productId]!['expiry'] as DateTime)
              .toIso8601String()
              .split('T')[0],
          imageUrl: productData['imageUrl'],
        ),
      );
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: mainBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Stock Display",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _segmentedControl(),
          _buildSearchBar(),
          _buildProductHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                ? const Center(child: Text('No products found'))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                return _buildProductCard(
                    products[index], index);
              },
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ---------------- UI BELOW (UNCHANGED) ----------------

  Widget _segmentedControl() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('Stock In')),
          ButtonSegment(value: 1, label: Text('Stock Display')),
          ButtonSegment(value: 2, label: Text('Stock Out')),
        ],
        selected: {_selectedTab},
        onSelectionChanged: (value) {
          final selected = value.first;
          if (selected == _selectedTab) return;

          Widget page;
          switch (selected) {
            case 0:
              page = AddIncomingStockPage();
              break;
            case 2:
              page = StockOutPage();
              break;
            default:
              return;
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        },
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          selectedBackgroundColor: mainBlue,
          selectedForegroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search by name or SKU',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildProductHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Find Products',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildProductCard(DisplayProduct product, int index) {
    final isEditing = editingStates[index] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: product.imageUrl != null
                      ? Image.network(product.imageUrl!,
                      fit: BoxFit.cover)
                      : const Icon(Icons.shopping_bag),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      Text('SKU: ${product.sku}'),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                      isEditing ? Icons.check_circle : Icons.edit),
                  onPressed: () {
                    setState(() {
                      editingStates[index] = !isEditing;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStat('Total', product.total),
                _buildStat('On Display', product.onDisplay),
                _buildStat('Balance', product.balance),
              ],
            ),
            const SizedBox(height: 8),
            Text('Exp: ${product.expiry}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, int value) {
    return Expanded(
      child: Column(
        children: [
          Text(label),
          Text(value.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _showConfirmationDialog,
              child: const Text('Confirm & Update Inventory'),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Update'),
        content: const Text(
            'Update inventory with current display quantities?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

class DisplayProduct {
  final String name;
  final String sku;
  int total;
  int onDisplay;
  int balance;
  final String expiry;
  final String? imageUrl;

  DisplayProduct({
    required this.name,
    required this.sku,
    required this.total,
    required this.onDisplay,
    required this.balance,
    required this.expiry,
    this.imageUrl,
  });
}