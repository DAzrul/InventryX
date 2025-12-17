import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'supplier_add_page.dart';
import 'supplier_edit_page.dart';
import 'supplier_delete_page.dart';

class SupplierListItem extends StatelessWidget {
  final String supplierName;
  final String phone;
  final String email;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SupplierListItem({
    super.key,
    required this.supplierName,
    required this.phone,
    required this.email,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {

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
          ),
          trailing: SizedBox(
            width: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
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
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Column(
        children: [
          /// Dashboard Card (TOTAL SUPPLIERS)
          Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF233E99),
                borderRadius: BorderRadius.circular(15),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("supplier")
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData
                      ? snapshot.data!.docs.length.toString()
                      : "...";

                  return Row(
                    children: [
                      const Icon(Icons.store, color: Colors.white, size: 30),
                      const SizedBox(width: 10),
                      Text(
                        count,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        "Total Suppliers",
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                    ],
                  );
                },
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
                  return const Center(child: Text("No suppliers found"));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final supplier = doc.data() as Map<String, dynamic>;

                    return SupplierListItem(
                      supplierName: supplier['supplierName'] ?? '',
                      phone: supplier['contactNo'] ?? '',
                      email: supplier['email'] ?? '',
                      onEdit: () {
                        // TODO: SupplierEditPage
                      },
                      onDelete: () {
                        // TODO: SupplierDeletePage
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
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Features'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outlined), label: 'Profile'),
        ],
      ),
    );
  }
}
