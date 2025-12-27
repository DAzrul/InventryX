import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'product_add_page.dart';
import 'product_edit_page.dart';
import 'product_delete_dialog.dart';
import '../../Features_app/barcode_scanner_page.dart';
import '../../Profile/User_profile_page.dart';
import '../widgets/bottom_nav_page.dart';

class ProductListPage extends StatefulWidget {
  final String? loggedInUsername;
  final String? userId;

  const ProductListPage({super.key, this.loggedInUsername, this.userId});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  int _selectedIndex = 1;
  String _selectedCategory = 'ALL';
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();
  final Color primaryBlue = const Color(0xFF233E99);

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<void> _scanBarcode() async {
    final scanned = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const BarcodeScannerPage())
    );
    if (scanned != null) {
      setState(() {
        _searchText = scanned.toLowerCase();
        _searchController.text = scanned;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentUsername = widget.loggedInUsername ?? "Admin";

    return BottomNavPage(
      loggedInUsername: currentUsername,
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      child: IndexedStack(
        index: _selectedIndex == 2 ? 1 : 0,
        children: [
          _buildInventoryHome(),
          ProfilePage(username: currentUsername, userId: '',),
        ],
      ),
    );
  }

  Widget _buildInventoryHome() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Column(
        children: [
          _buildCustomAppBar(),
          _buildSearchAndScanSection(),
          _buildCategoryFilter(),
          Expanded(child: _buildProductListStream()),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton(
          backgroundColor: primaryBlue,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductAddPage())),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 55, 10, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
                "Inventory Management",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildSearchAndScanSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 5),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchText = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Search name or barcode...",
                  prefixIcon: Icon(Icons.search_rounded, color: primaryBlue),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _scanBarcode,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryBlue,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final List<String> cats = ['ALL', 'FOOD', 'BEVERAGES', 'PERSONAL CARE'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: cats.map((cat) {
            final isSelected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: isSelected ? primaryBlue : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: isSelected ? primaryBlue : Colors.grey.shade200),
                ),
                child: Text(cat, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildProductListStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("products").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (_selectedCategory != 'ALL' && data['category'] != _selectedCategory) return false;
          final name = (data['productName'] ?? '').toString().toLowerCase();
          final barcode = (data['barcodeNo'] ?? '').toString();
          return name.contains(_searchText) || barcode.contains(_searchText);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            // [FIX] Kita guna class kat bawah ni mat!
            return ProductItemCard(data: data, docId: docs[index].id, primaryColor: primaryBlue);
          },
        );
      },
    );
  }
}

// --- [FIX] INI CLASS YANG HILANG TADI MAT! ---
class ProductItemCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final Color primaryColor;
  const ProductItemCard({super.key, required this.data, required this.docId, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0.0;
    int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
      ),
      child: ListTile(
        leading: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: (data['imageUrl'] != null && data['imageUrl'].isNotEmpty)
                ? CachedNetworkImage(imageUrl: data['imageUrl'], width: 60, height: 60, fit: BoxFit.cover, placeholder: (context, url) => Container(color: Colors.grey[100], child: const Icon(Icons.image)))
                : Container(width: 60, height: 60, color: Colors.grey.shade100, child: const Icon(Icons.inventory_2_rounded))
        ),
        title: Text(
            data['productName'] ?? 'Unnamed',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis
        ),
        subtitle: Row(
          children: [
            Text('RM ${price.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: stock <= 5 ? Colors.red.withOpacity(0.1) : primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Stock: $stock', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: stock <= 5 ? Colors.red : primaryColor)),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: Colors.blueGrey, size: 26),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductEditPage(productId: docId, productData: data))),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 24),
              onPressed: () => showDialog(context: context, builder: (_) => ProductDeleteDialog(productId: docId, productData: data)),
            ),
          ],
        ),
      ),
    );
  }
}