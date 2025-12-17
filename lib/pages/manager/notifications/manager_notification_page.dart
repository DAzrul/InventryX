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
              onPressed: () {
                Navigator.pop(context); // Cancel
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  selectedCategory = tempSelected;
                  headerText = selectedCategory != null
                      ? "$selectedCategory Alerts"
                      : "All Alerts";
                  _tabController.index = 0; // Back to All Alerts
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
        title: const Text(
          "Notifications",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  headerText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_list,
                          color: Color(0xFF233E99)),
                      onPressed: _showFilterDialog,
                    ),
                    IconButton(
                      icon:
                      const Icon(Icons.search, color: Colors.grey),
                      onPressed: () {
                        // Future implementation
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Placeholder content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(
                4,
                    (index) => Center(
                  child: Text(
                    "No notifications yet",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
