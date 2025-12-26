import 'package:flutter/material.dart';

class ManagerNotificationPage extends StatefulWidget {
  const ManagerNotificationPage({super.key});

  @override
  State<ManagerNotificationPage> createState() => _ManagerNotificationPageState();
}

class _ManagerNotificationPageState extends State<ManagerNotificationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String headerText = "All Alerts";
  String? selectedCategory;

  // Warna Tema Premium
  final Color primaryBlue = const Color(0xFF1E3A8A);
  final Color bgGray = const Color(0xFFF8FAFF);

  final List<String> productCategories = [
    "Bakery", "Dairy & Milk", "Snacks & Chips", "Coffee & Tea", "Water", "Oral Care", "Healthcare",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0: headerText = selectedCategory ?? "All Alerts"; break;
            case 1: headerText = "Unread Alerts"; break;
            case 2: headerText = "Expiry Alerts"; break;
            case 3: headerText = "Risk Alerts"; break;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGray,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1C1E), fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: primaryBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.filter_list_rounded, color: primaryBlue, size: 20),
            ),
            onPressed: _showFilterDialog,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              labelColor: primaryBlue,
              unselectedLabelColor: Colors.grey.shade500,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              tabs: const [
                Tab(text: " All "),
                Tab(text: " Unread "),
                Tab(text: " Expiry "),
                Tab(text: " Risk "),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              headerText,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E)),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationList(Icons.notifications_none_rounded, "No notifications today"),
                _buildNotificationList(Icons.mark_as_unread_rounded, "You're all caught up!"),
                _buildNotificationList(Icons.history_toggle_off_rounded, "No expiring products"),
                _buildNotificationList(Icons.gpp_maybe_rounded, "No high-risk items"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(IconData icon, String message) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        // Dummy Card untuk tunjuk UI
        _buildModernNotifCard(
          title: "Low Stock: Coca Cola 1.5L",
          subtitle: "Only 5 units left in snacks category.",
          time: "2 mins ago",
          icon: Icons.inventory_2_rounded,
          color: Colors.orange,
        ),
        _buildModernNotifCard(
          title: "Expiry Warning: Fresh Milk",
          subtitle: "Batch #442 expires in 2 days.",
          time: "1 hour ago",
          icon: Icons.timer_rounded,
          color: Colors.red,
        ),
        const SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              Icon(icon, size: 60, color: Colors.grey.shade300),
              const SizedBox(height: 10),
              Text(message, style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernNotifCard({required String title, required String subtitle, required String time, required IconData icon, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Text("Filter Category", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: productCategories.length,
                  itemBuilder: (context, index) {
                    final cat = productCategories[index];
                    return ListTile(
                      title: Text(cat, style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: selectedCategory == cat ? Icon(Icons.check_circle, color: primaryBlue) : null,
                      onTap: () {
                        setState(() {
                          selectedCategory = cat;
                          headerText = "$selectedCategory Alerts";
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  setState(() { selectedCategory = null; headerText = "All Alerts"; });
                  Navigator.pop(context);
                },
                child: const Text("Reset Filter", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}