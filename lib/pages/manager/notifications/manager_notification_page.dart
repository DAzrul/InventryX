import 'package:flutter/material.dart';

class ManagerNotificationPage extends StatefulWidget {
  const ManagerNotificationPage({super.key});

  @override
  State<ManagerNotificationPage> createState() =>
      _ManagerNotificationPageState();
}

class _ManagerNotificationPageState extends State<ManagerNotificationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Header title
  String headerText = "All Alerts";

  // Dummy counts
  final int unreadCount = 3;
  final int expiryCount = 1;
  final int riskCount = 2;

  // Product categories (dummy)
  final List<String> productCategories = [
    "Bakery",
    "Dairy & Milk",
    "Snacks & Chips",
    "Coffee & Tea",
    "Water",
    "Oral Care",
    "Healthcare",
  ];

  // Selected filter
  String? selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0:
              headerText = selectedCategory != null
                  ? "$selectedCategory Alerts"
                  : "All Alerts";
              break;
            case 1:
              headerText = "Unread Alerts";
              break;
            case 2:
              headerText = "Expiry Alerts";
              break;
            case 3:
              headerText = "Risk Alerts";
              break;
          }
        });
      }
    });
  }

  void _showFilterDialog() {
    String? tempSelected = selectedCategory;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Filter by Product Category"),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: productCategories.map((category) {
                    return RadioListTile<String>(
                      title: Text(category),
                      value: category,
                      groupValue: tempSelected,
                      onChanged: (value) {
                        setStateDialog(() {
                          tempSelected = value;
                        });
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  selectedCategory = tempSelected;
                  headerText = selectedCategory != null
                      ? "$selectedCategory Alerts"
                      : "All Alerts";
                  _tabController.index = 0;
                });
                Navigator.pop(context);
              },
              child: const Text("Done"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications",
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF233E99),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF233E99),
          tabs: [
            const Tab(text: "All Alerts"),
            Tab(text: "Unread ($unreadCount)"),
            Tab(text: "Expiry Alerts ($expiryCount)"),
            Tab(text: "Risk Alerts ($riskCount)"),
          ],
        ),
      ),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(headerText,
                    style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_list,
                          color: Color(0xFF233E99)),
                      onPressed: _showFilterDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.grey),
                      onPressed: () {},
                    ),
                  ],
                )
              ],
            ),
          ),

          // CONTENT
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const Center(child: Text("No notifications yet")),
                const Center(child: Text("No unread notifications")),

                /// ✅ EXPIRY ALERTS TAB
                ListView(
                  children: const [
                    ExpiryNotificationCard(
                      productName: "Dutch Lady Full Cream Milk (1L)",
                      category: "Dairy & Milk",
                      batchId: "STK0021",
                      expiryDate: "06.12.2025",
                      daysLeft: 5,
                    ),
                  ],
                ),

                const Center(child: Text("No risk alerts yet")),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ====================
/// EXPIRY NOTIFICATION CARD
/// ====================
class ExpiryNotificationCard extends StatelessWidget {
  final String productName;
  final String category;
  final String batchId;
  final String expiryDate;
  final int daysLeft;

  const ExpiryNotificationCard({
    super.key,
    required this.productName,
    required this.category,
    required this.batchId,
    required this.expiryDate,
    required this.daysLeft,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Future: navigate to detail page
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "🔔 EXPIRY SOON ($daysLeft Days Left)",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                Text(
                  expiryDate,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              productName,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text("Category: $category"),
            Text("Batch ID: $batchId"),
          ],
        ),
      ),
    );
  }
}
