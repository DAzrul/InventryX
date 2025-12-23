import 'package:flutter/material.dart';

class StockOutPage extends StatefulWidget {
  @override
  _StockOutPageState createState() => _StockOutPageState();
}

class _StockOutPageState extends State<StockOutPage> {
  final Color mainBlue = const Color(0xFF00147C);

  int _selectedTab = 0; // 0 = Sold, 1 = Others
  bool _autoDeduct = true;
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';

  // For 'Others' tab
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _selectedReasonOther = 'Damaged';

  // Sample data for Sold tab
  List<ProductStock> _soldProducts = [
    ProductStock(
        name: 'Organic Whole Milk (1L)',
        sku: 'RS-PRO-BLK-10',
        unit: 'Bottle',
        prevStock: 50,
        autoDeducted: 35,
        sold: 15),
    ProductStock(
        name: 'Smart Water Bottle',
        sku: 'SWB-GRN-500ML',
        unit: 'Bottle',
        prevStock: 25,
        autoDeducted: 5,
        sold: 20),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: mainBlue,
        elevation: 0,
        title: const Text('Record Outgoing Stock'),
      ),
      body: Column(
        children: [
          _buildSegmentedControl(),
          Expanded(
            child: _selectedTab == 0 ? _buildSoldTab() : _buildOthersTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _buildSegmentButton('Sold', 0),
          const SizedBox(width: 8),
          _buildSegmentButton('Others', 1),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String label, int index) {
    bool selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? mainBlue : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : Colors.grey[800],
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  // ---------------- SOLD TAB ----------------
  Widget _buildSoldTab() {
    final filteredProducts = _soldProducts
        .where((p) =>
    p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        p.sku.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    int totalPrevStock =
    _soldProducts.fold(0, (sum, p) => sum + p.prevStock);
    int totalSold = _soldProducts.fold(0, (sum, p) => sum + p.sold);
    int totalAuto =
    _soldProducts.fold(0, (sum, p) => sum + p.autoDeducted);
    int totalCurrent = totalPrevStock - totalSold - totalAuto;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildDatePicker(),
          const SizedBox(height: 12),
          _buildSearchField(),
          const SizedBox(height: 8),
          _buildAutoDeductToggle(),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                return _buildProductCard(filteredProducts[index]);
              },
            ),
          ),
          const SizedBox(height: 8),
          _buildSummary(totalPrevStock, totalSold, totalAuto, totalCurrent),
          const SizedBox(height: 12),
          _buildCancelApplyButtons(),
        ],
      ),
    );
  }

  // ---------------- OTHERS TAB ----------------
  Widget _buildOthersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildDatePicker(),
          const SizedBox(height: 16),
          // Product Search / Scan
          TextField(
            controller: _productController,
            decoration: InputDecoration(
              hintText: 'Search product or scan barcode',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner), onPressed: () {}),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
          const SizedBox(height: 16),
          // Quantity
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantity to Remove',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
          const SizedBox(height: 16),
          // Reason Dropdown
          DropdownButtonFormField<String>(
            value: _selectedReasonOther,
            items: ['Damaged', 'Expired', 'Returned']
                .map((e) => DropdownMenuItem(child: Text(e), value: e))
                .toList(),
            onChanged: (val) => setState(() => _selectedReasonOther = val!),
            decoration: InputDecoration(
              labelText: 'Reason for Removal',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
          const SizedBox(height: 16),
          // Notes
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Notes (Optional)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: mainBlue),
                    foregroundColor: mainBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Save stock removal logic
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- COMMON WIDGETS ----------------
  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        DateTime? picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2023),
            lastDate: DateTime(2030));
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300)),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
            const SizedBox(width: 12),
            Text('${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (val) => setState(() => _searchQuery = val),
      decoration: InputDecoration(
        hintText: 'Search product',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }

  Widget _buildAutoDeductToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Apply Auto-Deduction'),
        Switch(
          value: _autoDeduct,
          onChanged: (val) => setState(() => _autoDeduct = val),
          activeColor: mainBlue,
        ),
      ],
    );
  }

  Widget _buildProductCard(ProductStock p) {
    int currentStock =
        p.prevStock - p.sold - (_autoDeduct ? p.autoDeducted : 0);
    Color statusColor = currentStock <= 0 ? Colors.orange : Colors.green;
    String statusText = currentStock <= 0 ? 'Low' : 'OK';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('SKU: ${p.sku}  •  Unit: ${p.unit}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStockInfo('Prev Stock', p.prevStock),
                _buildStockInfo('Auto-Deducted', _autoDeduct ? p.autoDeducted : 0),
                _buildStockInfo('Sold', p.sold, color: statusColor),
                _buildStockInfo('Current Display', currentStock),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockInfo(String label, int value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value.toString(),
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, color: color ?? Colors.black)),
      ],
    );
  }

  Widget _buildSummary(int prev, int sold, int auto, int current) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        children: [
          _buildSummaryRow('Total Previous Stock', prev),
          _buildSummaryRow('Total Sold', sold),
          _buildSummaryRow('Total Auto-Deducted Stock', auto),
          _buildSummaryRow('Total Current Display Stock', current),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCancelApplyButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: mainBlue),
              foregroundColor: mainBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // TODO: Apply stock out logic
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: mainBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Apply'),
          ),
        ),
      ],
    );
  }
}

class ProductStock {
  final String name;
  final String sku;
  final String unit;
  final int prevStock;
  final int autoDeducted;
  final int sold;

  ProductStock({
    required this.name,
    required this.sku,
    required this.unit,
    required this.prevStock,
    required this.autoDeducted,
    required this.sold,
  });
}
