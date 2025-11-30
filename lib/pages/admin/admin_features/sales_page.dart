import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Untuk integrasi data masa depan

class SalesPage extends StatefulWidget {
  // Anda boleh tambahkan parameter jika ingin memuatkan data produk tertentu dari Firestore
  // final String? productId;
  // const SalesPage({super.key, this.productId});

  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  // Data Dummy untuk Demo UI
  String _productName = "Wireless Bluetooth Headphones Pro";
  String _category = "Electronics";
  double _price = 149.99;
  int _stockLevel = 250;
  String _description = "High-fidelity wireless Bluetooth headphones with active noise cancellation, comfortable earcups, and long-lasting battery life. Perfect for immersive audio experiences and travel.";
  String _sku = "PROD-WH1001-GREY";
  String _productImageUrl = "assets/headphone.png"; // Pastikan ada gambar ini di folder assets
  bool _isActive = true; // Status produk

  // Data Dummy untuk Transaction History
  final List<Map<String, dynamic>> _transactionHistory = const [
    {
      'type': 'Stock In', 'qty': 15, 'date': '2023-10-26',
      'user': 'John Doe', 'reason': 'Restock from supplier'
    },
    {
      'type': 'Stock Out', 'qty': 3, 'date': '2023-10-25',
      'user': 'Jane Smith', 'reason': 'Customer order #1001'
    },
    {
      'type': 'Stock In', 'qty': 5, 'date': '2023-10-24',
      'user': 'Admin', 'reason': 'Returned items processed'
    },
    {
      'type': 'Stock Out', 'qty': 2, 'date': '2023-10-23',
      'user': 'John Doe', 'reason': 'Damaged item removed'
    },
  ];


  // --- Fungsi yang boleh dipanggil untuk Quick Actions ---
  void _adjustStockLevel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Adjust Stock Level functionality (To be implemented)')),
    );
  }

  void _toggleProductStatus() {
    setState(() {
      _isActive = !_isActive;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Product status changed to ${_isActive ? "Active" : "Disabled"}')),
    );
  }

  void _deleteProduct() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delete Product functionality (To be implemented)')),
    );
  }

  void _saveChanges() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saving changes...')),
    );
    // Logik untuk menyimpan perubahan ke Firestore akan diletakkan di sini
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StockFlow', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- PRODUCT IMAGE & BASIC INFO ---
            Center(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Image.asset(
                        _productImageUrl,
                        height: 180,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 15),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'SKU: $_sku',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _isActive ? Colors.blue : Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isActive ? 'Active' : 'Disabled',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),

            // --- PRODUCT DETAILS ---
            const Text('Product Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildProductDetailCard(),
            const SizedBox(height: 25),

            // --- QUICK ACTIONS ---
            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildQuickActions(),
            const SizedBox(height: 25),

            // --- TRANSACTION HISTORY ---
            const Text('Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildTransactionHistory(),
            const SizedBox(height: 25),

            // --- SALES & INVENTORY TREND ---
            const Text('Sales & Inventory Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildSalesInventoryTrendChart(),
            const SizedBox(height: 25),

            // --- SAVE CHANGES BUTTON ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widget Pembantu ---

  Widget _buildProductDetailCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Product Name', _productName, editable: true),
            _buildDetailRow('Category', _category, isDropdown: true, dropdownItems: ['Electronics', 'Clothing', 'Books', 'Food']),
            _buildDetailRow('Price', '\$ ${_price.toStringAsFixed(2)}', editable: true, isPrice: true),
            _buildDetailRow('Stock Level', _stockLevel.toString(), editable: true, isNumber: true),
            _buildDetailRow('Description', _description, editable: true, isMultiLine: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool editable = false, bool isDropdown = false, List<String>? dropdownItems, bool isPrice = false, bool isNumber = false, bool isMultiLine = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
          const SizedBox(height: 4),
          if (editable)
            if (isDropdown && dropdownItems != null)
              DropdownButtonFormField<String>(
                value: value,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: dropdownItems.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _category = newValue!; // Update state for category
                  });
                },
              )
            else
              TextFormField(
                initialValue: value,
                maxLines: isMultiLine ? 3 : 1,
                keyboardType: isPrice || isNumber ? TextInputType.numberWithOptions(decimal: isPrice) : TextInputType.text,
                decoration: InputDecoration(
                  prefixText: isPrice ? '\$ ' : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: (newValue) {
                  // Update state based on label (contoh sahaja, perlu logik yang lebih baik)
                  if (label == 'Product Name') _productName = newValue;
                  else if (label == 'Price') _price = double.tryParse(newValue) ?? _price;
                  else if (label == 'Stock Level') _stockLevel = int.tryParse(newValue) ?? _stockLevel;
                  else if (label == 'Description') _description = newValue;
                },
              )
          else
            Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _adjustStockLevel,
                icon: const Icon(Icons.inventory_sharp, color: Colors.white),
                label: const Text('Adjust Stock Level', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _toggleProductStatus,
                icon: Icon(_isActive ? Icons.toggle_off : Icons.toggle_on, color: Colors.white),
                label: Text(_isActive ? 'Disable Product' : 'Enable Product', style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isActive ? Colors.purpleAccent[400] : Colors.green, // Ubah warna berdasarkan status
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _deleteProduct,
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                label: const Text('Delete Product', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionHistory() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: _transactionHistory.map((transaction) {
            bool isStockIn = transaction['type'] == 'Stock In';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isStockIn ? Icons.arrow_circle_up : Icons.arrow_circle_down,
                          color: isStockIn ? Colors.green : Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${transaction['type']} Qty: ${transaction['qty']}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: isStockIn ? Colors.green[800] : Colors.red[800]),
                      ),
                      const Spacer(),
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(transaction['date'], style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(transaction['user'], style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Reason: ${transaction['reason']}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  if (_transactionHistory.last != transaction)
                    Divider(color: Colors.grey[300], height: 20),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSalesInventoryTrendChart() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Gambar placeholder untuk carta
            Image.asset(
              'assets/sales_trend_chart_placeholder.png', // Pastikan gambar ini ada
              fit: BoxFit.contain,
              height: 200,
            ),
          ],
        ),
      ),
    );
  }
}