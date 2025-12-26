import 'package:flutter/material.dart';
import 'daily_sales.dart';
import 'history_sales.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  int? selectedIndex;

  void _handleTap(int index) async {
    setState(() => selectedIndex = index);

    // Feedback visual sekejap sebelum lompat page
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    Widget targetPage = (index == 0) ? const DailySalesPage() : const HistorySalesPage();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => targetPage),
    ).then((_) {
      if (mounted) setState(() => selectedIndex = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF), // Background lebih soft
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Sales Management", // Nama lebih profesional
          style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.withValues(alpha: 0.1), height: 1.0),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(), // Feel premium macam iPhone
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Choose Action",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
            const SizedBox(height: 20),

            _SalesOptionCard(
              title: "Daily Sales Input",
              subtitle: "Record today's automated simulation",
              icon: Icons.add_chart_rounded,
              isActive: selectedIndex == 0,
              primaryColor: const Color(0xFF233E99),
              onTap: () => _handleTap(0),
            ),

            const SizedBox(height: 20),

            _SalesOptionCard(
              title: "Sales History",
              subtitle: "Track & edit previous records",
              icon: Icons.manage_history_rounded,
              isActive: selectedIndex == 1,
              primaryColor: const Color(0xFF1E3A8A),
              onTap: () => _handleTap(1),
            ),

            const SizedBox(height: 40),
            // Tips ringkas untuk staff
            _buildInfoBox(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF233E99).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF233E99).withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF233E99)),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              "Keep your sales record updated daily for more accurate stock forecasting.",
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final Color primaryColor;
  final VoidCallback onTap;

  const _SalesOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        // Guna Gradient bila aktif supaya nampak premium
        gradient: isActive
            ? LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: isActive ? null : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? primaryColor.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Row( // Tukar ke Row supaya lebih "clean" dan "minimalist"
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white24 : primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: isActive ? Colors.white : primaryColor, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isActive ? Colors.white : const Color(0xFF1A1C1E),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isActive ? Colors.white70 : Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isActive ? Colors.white54 : Colors.grey.shade300,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}