import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------- SUPPLIER LIST ITEM WIDGET ----------------
class SupplierListItem extends StatelessWidget {
  final String supplierName;
  final String phone;
  final String email;
  final String status;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SupplierListItem({
    super.key,
    required this.supplierName,
    required this.phone,
    required this.email,
    required this.status,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = status == 'Active';
    final Color statusColor = isActive ? Colors.green : Colors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: Colors.blueGrey.shade100,
            child: const Icon(Icons.store, color: Colors.black54),
          ),
          title: Text(
            supplierName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            "Phone: $phone\nEmail: $email",
            style: const TextStyle(fontSize: 13),
          ),
          // FIXED SECTION START
          trailing: Row(
            mainAxisSize: MainAxisSize.min, // Takes only needed space
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4), // Tiny gap
              IconButton(
                constraints: const BoxConstraints(), // Removes big default padding
                padding: const EdgeInsets.all(8),
                icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey, size: 20),
                onPressed: onEdit,
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
          // FIXED SECTION END
        ),
      ),
    );
  }
}

// ---------------- SUPPLIER LIST PAGE ----------------
class SupplierListPage extends StatefulWidget {
  const SupplierListPage({super.key});

  @override
  State<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends State<SupplierListPage> {
  int _currentIndex = 0;

  Stream<QuerySnapshot> get _supplierStream {
    return FirebaseFirestore.instance
        .collection("supplier")
        .snapshots();
  }

  void _onBottomNavTap(int index) {
    if (index == 1) return;
    // Just a placeholder for nav logic
    if (index == 0 || index == 2) {
      Navigator.pop(context, index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      /// AppBar
      appBar: AppBar(
        title: const Text(
          "Suppliers",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Column(
        children: [
          /// Dashboard Card (TOTAL SUPPLIERS)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF233E99),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: _supplierStream, // Reused the getter stream
                builder: (context, snapshot) {
                  final count = snapshot.hasData
                      ? snapshot.data!.docs.length.toString()
                      : "...";

                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.store, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            count,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            "Total Suppliers",
                            style: TextStyle(fontSize: 14, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          /// Supplier List Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "List of Suppliers",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          /// Supplier List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _supplierStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 50, color: Colors.grey),
                        SizedBox(height: 10),
                        Text("No suppliers found", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final supplier = doc.data() as Map<String, dynamic>;

                    return SupplierListItem(
                      supplierName: supplier['supplierName'] ?? 'Unknown',
                      phone: supplier['contactNo'] ?? 'N/A',
                      email: supplier['email'] ?? 'N/A',
                      status: supplier['status'] ?? 'Inactive',
                      onEdit: () {
                        // TODO: Navigate to Edit Page
                        print("Edit clicked for ${doc.id}");
                      },
                      onDelete: () {
                        // TODO: Show Delete Dialog
                        print("Delete clicked for ${doc.id}");
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
        selectedItemColor: const Color(0xFF233E99),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Features'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outlined), label: 'Profile'),
        ],
      ),
    );
  }
}