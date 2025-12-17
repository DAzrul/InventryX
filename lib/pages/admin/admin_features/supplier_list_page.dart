import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'supplier_add_page.dart';
import 'supplier_edit_page.dart';
import 'supplier_delete_dialog.dart';

/// ---------------- SUPPLIER LIST ITEM ----------------
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
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.blueGrey, size: 20),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------- SUPPLIER LIST PAGE ----------------
class SupplierListPage extends StatefulWidget {
  const SupplierListPage({super.key});

  @override
  State<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends State<SupplierListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  Stream<QuerySnapshot> get _supplierStream =>
      FirebaseFirestore.instance.collection("supplier").snapshots();

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Supplier"),
        content:
        const Text("Are you sure you want to delete this supplier?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection("supplier")
                  .doc(id)
                  .delete();
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      /// APP BAR
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0, // make title start a little to the left
        title: Padding(
          padding: const EdgeInsets.only(left: 10), // shift title slightly left
          child: const Text(
            "Suppliers",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 26, // make it bigger
              color: Colors.black,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: Color(0xFF233E99), size: 30),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupplierAddPage()),
            ),
          ),
        ],
      ),


      body: Column(
        children: [
          /// 🔍 SEARCH BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) =>
                  setState(() => _searchText = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search supplier name or phone...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          /// DASHBOARD CARD
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF233E99),
                borderRadius: BorderRadius.circular(15),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: _supplierStream,
                builder: (context, snapshot) {
                  final count = snapshot.hasData
                      ? snapshot.data!.docs.length.toString()
                      : "...";
                  return Row(
                    children: [
                      const Icon(Icons.store,
                          color: Colors.white, size: 30),
                      const SizedBox(width: 10),
                      Text(
                        count,
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const Spacer(),
                      const Text("Total Suppliers",
                          style:
                          TextStyle(color: Colors.white70)),
                    ],
                  );
                },
              ),
            ),
          ),

          /// SUPPLIER LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _supplierStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final name =
                  (d['supplierName'] ?? '').toString().toLowerCase();
                  final phone =
                  (d['contactNo'] ?? '').toString().toLowerCase();
                  return name.contains(_searchText) ||
                      phone.contains(_searchText);
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text("No suppliers found"));
                }

                return ListView.builder(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final s =
                    doc.data() as Map<String, dynamic>;

                    return SupplierListItem(
                      supplierName: s['supplierName'],
                      phone: s['contactNo'],
                      email: s['email'],
                      onEdit: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SupplierEditPage(
                            supplierId: doc.id,
                            supplierData: s,
                          ),
                        ),
                      ),
                      onDelete: () async {
                        final deleted = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) =>
                              SupplierDeleteDialog(
                                supplierId: doc.id,
                                supplierData: s,
                              ),
                        );

                        if (deleted == true && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Supplier deleted')),
                          );
                        }
                      }
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
