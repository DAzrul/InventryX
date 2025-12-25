import 'package:flutter/material.dart';
import 'add_incoming_stock.dart';

class InventoryDashboard extends StatefulWidget {
  @override
  _InventoryDashboardState createState() => _InventoryDashboardState();
}

class _InventoryDashboardState extends State<InventoryDashboard> {
  final Color mainBlue = const Color(0xFF00147C);

  int currentIndex = 0;

  // Pages for bottom navigation
  late final List<Widget> pages = [
    _dashboardContent(),        // Home UI (your original dashboard)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      body: pages[currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: mainBlue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.flag_outlined), label: "Forecast"),
          BottomNavigationBarItem(icon: Icon(Icons.apps), label: "Features"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: "Notification"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }

  // YOUR ORIGINAL DASHBOARD PAGE (kept 100%)
  Widget _dashboardContent() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainBlue,
        elevation: 0,
        title: const Text("Inventory Management",
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCard(),
            const SizedBox(height: 20),
            _buildAlertCard(),
            const SizedBox(height: 20),

            Text("Quick Actions",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: mainBlue)),
            const SizedBox(height: 12),
            _buildQuickActions(context),

            const SizedBox(height: 24),
            Text("Recent Activity",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: mainBlue)),
            const SizedBox(height: 12),

            _buildRecentActivityItem(
              icon: Icons.add_circle,
              title: "Stock In: Whole Wheat Bread",
              change: "+ 50 units",
              time: "30 min ago",
              color: Colors.green,
            ),
            _buildRecentActivityItem(
              icon: Icons.remove_circle,
              title: "Stock Out: Dairy Milk (2L)",
              change: "- 10 units",
              time: "1 hour ago",
              color: Colors.red,
            ),
            _buildRecentActivityItem(
              icon: Icons.add_circle,
              title: "Stock In: Cage-Free Eggs",
              change: "+ 120 units",
              time: "2 hours ago",
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Overview",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _overviewItem("Total Stock", "1250 units"),
                _overviewItem("On Display", "125 units"),
                _overviewItem("Balance", "12 units"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewItem(String title, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildAlertCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.red[800], size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Low Stock Alert!",
                    style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                SizedBox(height: 4),
                Text("5 items need reorder. Reorder needed."),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text("View"),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _quickActionItem(Icons.inventory_2, "Stock In", onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => AddIncomingStockPage()),
          );
        }),

        _quickActionItem(Icons.outbond, "Stock Out"),
      ],
    );
  }

  Widget _quickActionItem(IconData icon, String label,
      {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: mainBlue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivityItem({
    required IconData icon,
    required String title,
    required String change,
    required String time,
    required Color color,
  }) {
    return Card(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
        leading: Icon(icon, size: 32, color: color),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(time),
        trailing: Text(change,
            style:
            TextStyle(fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}
