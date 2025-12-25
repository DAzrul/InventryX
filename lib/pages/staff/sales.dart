import 'package:flutter/material.dart';
import 'daily_sales.dart';
import 'history_sales.dart'; // Import fail history yang telah anda sediakan

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  // Track which index is currently "active" or clicked
  int? selectedIndex;

  void _handleTap(int index) async {
    setState(() {
      selectedIndex = index;
    });

    // Memberi maklum balas visual (warna bertukar) sebelum navigasi
    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    if (index == 0) {
      // Navigasi ke Daily Sales Page
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DailySalesPage()),
      ).then((_) {
        // Reset warna kad apabila kembali ke halaman ini
        if (mounted) setState(() => selectedIndex = null);
      });
    }
    else if (index == 1) {
      // Navigasi ke History Sales Page [Penyelesaian kepada permintaan anda]
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HistorySalesPage()),
      ).then((_) {
        // Reset warna kad apabila kembali ke halaman ini
        if (mounted) setState(() => selectedIndex = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Sales",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.withOpacity(0.2), height: 1.0),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // Option 0: Daily Sales Input
            _SalesOptionCard(
              title: "Daily Sales Input",
              subtitle: "Automated sales simulation",
              icon: Icons.assignment_outlined,
              isActive: selectedIndex == 0,
              onTap: () => _handleTap(0),
            ),

            const SizedBox(height: 16),

            // Option 1: Sales History
            _SalesOptionCard(
              title: "Sales History",
              subtitle: "View previous entries & edits",
              icon: Icons.history,
              isActive: selectedIndex == 1,
              onTap: () => _handleTap(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SalesOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isActive ? const Color(0xFF20338F) : Colors.white;
    final Color contentColor = isActive ? Colors.white : Colors.black;
    final Color subtitleColor = isActive ? Colors.white.withOpacity(0.8) : Colors.grey.shade600;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.transparent : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: contentColor, size: 36),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    color: contentColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}