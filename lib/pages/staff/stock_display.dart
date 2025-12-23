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

  Map<int, bool> editingStates = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() async {
    List<DisplayProduct> fetchedProducts = await fetchProducts();
    setState(() {
      products = fetchedProducts;
    });
  }

  Future<List<DisplayProduct>> fetchProducts() async {
    QuerySnapshot stockSnapshot =
    await FirebaseFirestore.instance.collection('stock').get();

    Map<String, Map<String, dynamic>> stockData = {};

    for (var doc in stockSnapshot.docs) {
      String productId = doc['productId']; // <-- use correct field
      int quantity = doc['quantity'] as int;
      Timestamp expiryTs = doc['expiryDate'] as Timestamp;
      DateTime expiry = expiryTs.toDate();

      if (stockData.containsKey(productId)) {
        stockData[productId]!['total'] += quantity;
        if (expiry.isBefore(stockData[productId]!['expiry'])) {
          stockData[productId]!['expiry'] = expiry;
        }
      } else {
        stockData[productId] = {'total': quantity, 'expiry': expiry};
      }
    }

    List<DisplayProduct> products = [];

    await Future.wait(stockData.keys.map((productId) async {
      DocumentSnapshot productDoc =
      await FirebaseFirestore.instance.collection('products').doc(productId).get();
      if (!productDoc.exists) return;

      final productData = productDoc.data() as Map<String, dynamic>?;

      // Get onDisplay quantity
      DocumentSnapshot displayDoc =
      await FirebaseFirestore.instance.collection('onDisplay').doc(productId).get();
      int onDisplay = displayDoc.exists ? displayDoc['onDisplayQuantity'] as int : 0;

      int total = stockData[productId]!['total'] as int;
      int balance = total - onDisplay;

      products.add(DisplayProduct(
        name: productData?['productName'] ?? '',
        sku: productData?['barcodeNo'] ?? '',
        total: total,
        onDisplay: onDisplay,
        balance: balance,
        expiry: (stockData[productId]!['expiryDate'] as DateTime)
            .toIso8601String()
            .split('T')[0],
        imageUrl: productData?['imageUrl'],
      ));
    }));

    return products;
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
            child: products.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                return _buildProductCard(products[index], index);
              },
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

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
          if (selected == _selectedTab) return; // avoid reloading same page

          Widget page;
          switch (selected) {
            case 0:
              page = AddIncomingStockPage();
              break;
            case 1:
              page = StockDisplayPage();
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
          selectedBackgroundColor: const Color(0xFF00147C),
          selectedForegroundColor: Colors.white,
        ),
      ),
    );
  }


  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search by name or SKU',
            prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
            suffixIcon: IconButton(
              icon: Icon(Icons.tune, color: Colors.grey[600]),
              onPressed: () {},
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (value) {
            // Optional: implement search filter
          },
        ),
      ),
    );
  }

  Widget _buildProductHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Find Products',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(DisplayProduct product, int index) {
    bool isEditing = editingStates[index] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Product Image
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: product.imageUrl != null
                        ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                        : Icon(Icons.shopping_bag, color: Colors.grey[600], size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SKU: ${product.sku}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isEditing ? Icons.check_circle : Icons.edit,
                    color: isEditing ? Colors.green : mainBlue,
                  ),
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
                _buildStatColumn('Total', product.total.toString()),
                const SizedBox(width: 24),
                _buildStatColumn('On Display', product.onDisplay.toString()),
                const SizedBox(width: 24),
                _buildStatColumn('Balance', product.balance.toString()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Exp: ${product.expiry}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: mainBlue,
                side: BorderSide(color: mainBlue),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _showConfirmationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: mainBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
      builder: (context) => AlertDialog(
        title: const Text('Confirm Update'),
        content: const Text('Update inventory with current display quantities?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Inventory updated successfully!'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: mainBlue),
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
