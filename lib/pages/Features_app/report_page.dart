import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Package Export
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as ex;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

// Navigation Imports
import '../admin/admin_page.dart';
import '../admin/utils/features_modal.dart';
import '../Profile/User_profile_page.dart';

class ReportPage extends StatefulWidget {
  final String? loggedInUsername;
  final String? userId;

  const ReportPage({super.key, this.loggedInUsername, this.userId});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  int _selectedIndex = 1;
  final Color primaryBlue = const Color(0xFF233E99);

  // [UBAH 1] Default Filter set kepada 'This Month'
  String _selectedTimeframe = 'This Month';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  // --- LOGIC: DATE PICKER ---
  Future<void> _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      currentDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primaryBlue, onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _selectedTimeframe = 'Custom Range';
      });
    } else {
      // Jika cancel, reset ke default This Month
      setState(() => _selectedTimeframe = 'This Month');
    }
  }

  // --- HELPER: GET DATE RANGE ---
  Map<String, Timestamp?> _getDateRange() {
    DateTime now = DateTime.now();
    DateTime? start;
    DateTime? end;

    if (_selectedTimeframe == 'This Month') {
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else if (_selectedTimeframe == 'This Year') {
      start = DateTime(now.year, 1, 1);
      end = DateTime(now.year, 12, 31, 23, 59, 59);
    } else if (_selectedTimeframe == 'Custom Range') {
      start = _customStartDate;
      end = _customEndDate;
    }
    // All Time kekal null

    return {
      'start': start != null ? Timestamp.fromDate(start) : null,
      'end': end != null ? Timestamp.fromDate(end) : null
    };
  }

  // ===========================================================================
  // 1. PROFESSIONAL PDF GENERATOR (ADMIN - FULL ACCESS)
  // ===========================================================================
  Future<void> _generateAndPrintPDF() async {
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final pdf = pw.Document();
      final int tabIndex = _tabController.index;
      final String generatedBy = widget.loggedInUsername ?? "Administrator";
      final String generateDate = DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now());

      final dateRange = _getDateRange();
      Timestamp? startTimestamp = dateRange['start'];
      Timestamp? endTimestamp = dateRange['end'];

      String reportTitle = "";
      String summaryText = "";
      String timeframeLabel = "Period: $_selectedTimeframe";
      if (_selectedTimeframe == 'Custom Range' && _customStartDate != null && _customEndDate != null) {
        timeframeLabel = "${DateFormat('dd/MM/yy').format(_customStartDate!)} - ${DateFormat('dd/MM/yy').format(_customEndDate!)}";
      }

      List<String> tableHeaders = [];
      List<List<dynamic>> tableData = [];

      final PdfColor brandColor = PdfColors.blue900;
      final PdfColor accentColor = PdfColors.grey200;

      if (tabIndex == 0) {
        // --- 1. INVENTORY (STOCK) - [UBAH 2] Generates Table Report ---
        reportTitle = "CURRENT STOCK REPORT";
        tableHeaders = ['No', 'Item Name', 'Category', 'Stock', 'Price', 'Value'];

        Query query = _db.collection('products').orderBy('productName');
        // Filter: Show active items updated within range (or all if All Time)
        if (startTimestamp != null) query = query.where('updatedAt', isGreaterThanOrEqualTo: startTimestamp);
        if (endTimestamp != null) query = query.where('updatedAt', isLessThanOrEqualTo: endTimestamp);

        final snap = await query.get();

        double totalVal = 0;
        int lowStockCount = 0;
        int index = 1;

        for (var d in snap.docs) {
          final data = d.data() as Map<String, dynamic>;
          int s = int.tryParse(data['currentStock'].toString()) ?? 0;
          double p = double.tryParse(data['price'].toString()) ?? 0;
          double rowTot = s * p;
          totalVal += rowTot;
          if (s <= 10) lowStockCount++;

          // Fill Table Data
          tableData.add([
            index.toString(),
            data['productName']?.toString().toUpperCase() ?? '-',
            data['category'] ?? '-',
            s.toString(),
            "RM ${p.toStringAsFixed(2)}",
            "RM ${rowTot.toStringAsFixed(2)}"
          ]);
          index++;
        }
        summaryText = "Inventory Valuation Report. Total Asset Value: RM ${totalVal.toStringAsFixed(2)}. Critical items: $lowStockCount.";

      } else if (tabIndex == 1) {
        // --- 2. FORECAST ---
        reportTitle = "FUTURE SALES FORECAST";
        tableHeaders = ['Date', 'Product', 'Expected Sales', 'Status'];

        Query query = _db.collection('forecasts').orderBy('predictedDemand', descending: true);
        final snap = await query.get();

        for (var d in snap.docs) {
          final data = d.data() as Map<String, dynamic>;
          if (data['forecastDate'] != null) {
            Timestamp t = data['forecastDate'];
            if (startTimestamp != null && t.compareTo(startTimestamp) < 0) continue;
            if (endTimestamp != null && t.compareTo(endTimestamp) > 0) continue;
          }

          String date = data['forecastDate'] != null ? DateFormat('yyyy-MM-dd').format((data['forecastDate'] as Timestamp).toDate()) : '-';
          double demand = double.tryParse(data['predictedDemand'].toString()) ?? 0;
          tableData.add([date, data['productName'] ?? '-', "${demand.toInt()} Units", demand > 50 ? "High Demand" : "Normal"]);
        }
        summaryText = "AI-driven forecast sorted by highest projected demand for selected period.";

      } else if (tabIndex == 2) {
        // --- 3. RISK ---
        reportTitle = "EXPIRY & HEALTH CHECK";
        timeframeLabel = "Snapshot: Today";
        tableHeaders = ['Product Name', 'Risk Level', 'Days Left', 'Status'];
        final snap = await _db.collection('risk_analysis').orderBy('RiskValue', descending: true).get();

        for (var d in snap.docs) {
          final data = d.data() as Map<String, dynamic>;
          String level = data['RiskLevel']?.toString().toUpperCase() ?? 'LOW';
          String expiryInfo = "${data['DaysToExpiry'] ?? 0} Days Left";
          tableData.add([data['ProductName'] ?? '-', level, expiryInfo, "Monitoring"]);
        }
        summaryText = "Current risk assessment based on real-time expiry and stock data.";

      } else if (tabIndex == 3) {
        // --- 4. SALES (FULL ACCESS) ---
        reportTitle = "SALES TRANSACTION LEDGER";
        tableHeaders = ['Transaction Date', 'Sale ID', 'Product Item', 'Revenue'];

        Query query = _db.collection('sales').orderBy('saleDate', descending: true);
        if (startTimestamp != null) query = query.where('saleDate', isGreaterThanOrEqualTo: startTimestamp);
        if (endTimestamp != null) query = query.where('saleDate', isLessThanOrEqualTo: endTimestamp);

        final snap = await query.get();
        double totalRev = 0;

        for (var d in snap.docs) {
          final data = d.data() as Map<String, dynamic>;
          String date = data['saleDate'] != null
              ? DateFormat('dd/MM/yyyy HH:mm').format((data['saleDate'] as Timestamp).toDate())
              : '-';

          double rev = double.tryParse(data['totalAmount'].toString()) ?? 0;
          totalRev += rev;
          String productName = data['snapshotName'] ?? 'Unknown Item';

          tableData.add([
            date,
            d.id.substring(0, 8).toUpperCase(),
            productName,
            "RM ${rev.toStringAsFixed(2)}" // Admin sees REAL money
          ]);
        }
        summaryText = "Financial sales record. Total Revenue: RM ${totalRev.toStringAsFixed(2)}.";
      }

      // --- PDF BUILDER ---
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => pw.Column(children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text("INVENTRYX ADMIN", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20, color: brandColor)),
              pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.green), borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Text("FULL REPORT", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.green))
              ),
            ]),
            pw.SizedBox(height: 5),
            pw.Divider(color: brandColor, thickness: 1.5),
            pw.SizedBox(height: 10),
          ]),
          build: (pw.Context context) {
            return [
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(reportTitle, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Generated By: $generatedBy", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text(generateDate, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text(timeframeLabel, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: brandColor)),
                ]),
              ]),
              pw.SizedBox(height: 15),
              pw.Container(
                  width: double.infinity, padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(color: accentColor, borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text("EXECUTIVE SUMMARY", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: brandColor)),
                    pw.SizedBox(height: 3),
                    pw.Text(summaryText, style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.justify),
                  ])
              ),
              pw.SizedBox(height: 20),

              // --- TABLE RENDERER (ALL TABS USE TABLE) ---
              pw.TableHelper.fromTextArray(
                context: context, headers: tableHeaders, data: tableData, border: null,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: pw.BoxDecoration(color: brandColor, borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4))),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft, 2: pw.Alignment.center, 3: tabIndex == 3 ? pw.Alignment.centerRight : pw.Alignment.center},
              ),
            ];
          },
        ),
      );

      if (mounted) Navigator.pop(context);
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'InventryX_Admin_Report');

    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  // ===========================================================================
  // 2. EXPORT EXCEL (ADMIN)
  // ===========================================================================
  Future<void> _generateAndSaveExcel() async {
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      var excel = ex.Excel.createExcel();
      final int tabIndex = _tabController.index;
      if (excel.sheets.containsKey("Sheet1")) excel.delete("Sheet1");

      final dateRange = _getDateRange();
      Timestamp? startTimestamp = dateRange['start'];
      Timestamp? endTimestamp = dateRange['end'];

      String sheetName = "Report";
      List<String> headers = [];
      List<List<dynamic>> rows = [];

      if (tabIndex == 0) {
        sheetName = "Inventory Valuation";
        headers = ['Product Name', 'Category', 'Stock Level', 'Price (RM)', 'Total'];
        Query query = _db.collection('products');
        if (startTimestamp != null) query = query.where('updatedAt', isGreaterThanOrEqualTo: startTimestamp);
        if (endTimestamp != null) query = query.where('updatedAt', isLessThanOrEqualTo: endTimestamp);

        final snap = await query.get();
        for (var d in snap.docs) {
          final data = d.data() as Map<String, dynamic>;
          int s = int.tryParse(data['currentStock'].toString()) ?? 0;
          double p = double.tryParse(data['price'].toString()) ?? 0;
          rows.add([data['productName'] ?? '', data['category'] ?? '', s, p, s*p]);
        }
      } else if (tabIndex == 1) {
        sheetName = "Demand Forecast";
        headers = ['Forecast Date', 'Product Name', 'Predicted Demand'];
        Query query = _db.collection('forecasts').orderBy('forecastDate', descending: false);
        if (startTimestamp != null) query = query.where('forecastDate', isGreaterThanOrEqualTo: startTimestamp);
        final snap = await query.get();
        for (var d in snap.docs) {
          final data = d.data() as Map<String, dynamic>;
          if (data['forecastDate'] != null && endTimestamp != null) {
            if ((data['forecastDate'] as Timestamp).compareTo(endTimestamp) > 0) continue;
          }
          rows.add([data['forecastDate'] != null ? DateFormat('yyyy-MM-dd').format((data['forecastDate'] as Timestamp).toDate()) : '-', data['productName'] ?? '', double.tryParse(data['predictedDemand'].toString())?.toInt() ?? 0]);
        }
      } else if (tabIndex == 2) {
        sheetName = "Risk Analysis";
        headers = ['Product Name', 'Risk Level', 'Days To Expiry'];
        final snap = await _db.collection('risk_analysis').get();
        for (var d in snap.docs) {
          final data = d.data() as Map<String, dynamic>;
          rows.add([data['ProductName'] ?? '', data['RiskLevel'] ?? '', data['DaysToExpiry'] ?? 0]);
        }
      } else if (tabIndex == 3) {
        sheetName = "Sales Transactions";
        headers = ['Date', 'Sale ID', 'Product', 'Quantity', 'Revenue'];
        Query query = _db.collection('sales').orderBy('saleDate', descending: true);
        if (startTimestamp != null) query = query.where('saleDate', isGreaterThanOrEqualTo: startTimestamp);
        if (endTimestamp != null) query = query.where('saleDate', isLessThanOrEqualTo: endTimestamp);
        final snap = await query.get();
        for (var d in snap.docs) {
          final data = d.data() as Map<String, dynamic>;
          rows.add([
            data['saleDate'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((data['saleDate'] as Timestamp).toDate()) : '-',
            d.id,
            data['snapshotName'] ?? 'Unknown',
            data['quantitySold'] ?? 0,
            double.tryParse(data['totalAmount'].toString()) ?? 0
          ]);
        }
      }

      ex.Sheet sheet = excel[sheetName];
      sheet.appendRow([ex.TextCellValue("INVENTRYX REPORT - $_selectedTimeframe")]);
      sheet.appendRow([ex.TextCellValue(sheetName.toUpperCase())]);
      List<ex.CellValue> headerCells = headers.map((h) => ex.TextCellValue(h)).toList();
      sheet.appendRow(headerCells);

      for (var row in rows) {
        List<ex.CellValue> cellValues = [];
        for (var cell in row) {
          if (cell is int) cellValues.add(ex.IntCellValue(cell));
          else if (cell is double) cellValues.add(ex.DoubleCellValue(cell));
          else cellValues.add(ex.TextCellValue(cell.toString()));
        }
        sheet.appendRow(cellValues);
      }

      excel.setDefaultSheet(sheetName);
      var fileBytes = excel.save();
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/InventryX_${sheetName.replaceAll(" ", "_")}.xlsx';
      final file = File(path);
      await file.writeAsBytes(fileBytes!);

      if (mounted) Navigator.pop(context);
      await OpenFilex.open(file.path);

    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error Excel: $e"), backgroundColor: Colors.red));
    }
  }

  // --- NAVIGASI ---
  void _onItemTapped(int index) {
    if (index == 0) {
      final user = FirebaseAuth.instance.currentUser;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => AdminPage(username: widget.loggedInUsername ?? "Admin", userId: user?.uid ?? '', loggedInUsername: widget.loggedInUsername ?? "Admin")), (Route<dynamic> route) => false);
    } else if (index == 1) {
      FeaturesModal.show(context, widget.loggedInUsername ?? "Admin");
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentUsername = widget.loggedInUsername ?? "Admin";
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            var d = snapshot.data!.data() as Map<String, dynamic>;
            currentUsername = d['username'] ?? currentUsername;
          }
          // Calculate Date Range for UI components
          final dateRange = _getDateRange();

          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFF),
            body: IndexedStack(index: _selectedIndex == 2 ? 1 : 0, children: [
              _buildReportUI(context, dateRange),
              ProfilePage(username: currentUsername, userId: uid ?? '')
            ]),
            bottomNavigationBar: _buildFloatingNavBar(),
          );
        });
  }

  Widget _buildFloatingNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12), height: 62,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 5))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(25), child: BottomNavigationBar(currentIndex: _selectedIndex, onTap: _onItemTapped, backgroundColor: Colors.white, selectedItemColor: primaryBlue, unselectedItemColor: Colors.grey.shade400, showSelectedLabels: true, showUnselectedLabels: false, type: BottomNavigationBarType.fixed, elevation: 0, selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10), items: [_navItem(Icons.home_outlined, Icons.home_rounded, "Home"), _navItem(Icons.grid_view_outlined, Icons.grid_view_rounded, "Features"), _navItem(Icons.person_outline_rounded, Icons.person_rounded, "Profile")])),
    );
  }

  BottomNavigationBarItem _navItem(IconData inactiveIcon, IconData activeIcon, String label) {
    return BottomNavigationBarItem(icon: Icon(inactiveIcon, size: 22), activeIcon: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: primaryBlue.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(activeIcon, size: 22, color: primaryBlue)), label: label);
  }

  Widget _buildReportUI(BuildContext context, Map<String, Timestamp?> dateRange) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("Analytics", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E), fontSize: 22)),
        centerTitle: true, backgroundColor: Colors.white, elevation: 0, automaticallyImplyLeading: false,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: primaryBlue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTimeframe,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryBlue, size: 20),
                style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 12),
                onChanged: (String? newValue) {
                  if(newValue == 'Custom Range') _pickDateRange();
                  else setState(() => _selectedTimeframe = newValue!);
                },
                items: <String>['All Time', 'This Month', 'This Year', 'Custom Range'].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.only(right: 12), child: IconButton(icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryBlue.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.file_download_outlined, color: primaryBlue, size: 22)), onPressed: () => _showExportOptions(context)))
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(65), child: Container(margin: const EdgeInsets.fromLTRB(16, 0, 16, 12), padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(25)), child: TabBar(controller: _tabController, isScrollable: false, indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]), labelColor: primaryBlue, labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12), unselectedLabelColor: Colors.grey.shade500, unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), dividerColor: Colors.transparent, tabs: const [Tab(text: "Stock"), Tab(text: "Forecast"), Tab(text: "Risk"), Tab(text: "Sales")]))),
      ),
      body: TabBarView(
          controller: _tabController,
          physics: const BouncingScrollPhysics(),
          children: [
            _InventoryReportTab(db: _db, start: dateRange['start'], end: dateRange['end']),
            _ForecastReportTab(db: _db, start: dateRange['start'], end: dateRange['end']),
            _RiskReportTab(db: _db),
            _SalesReportTab(db: _db, start: dateRange['start'], end: dateRange['end'])
          ]
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    List<String> tabNames = ["Stock", "Forecast", "Risk", "Sales"];
    String currentTab = tabNames[_tabController.index];
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (ctx) => Container(padding: const EdgeInsets.all(24), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10))), const SizedBox(height: 25), Text("Export $currentTab", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))), const SizedBox(height: 30), _exportTile(Icons.picture_as_pdf_rounded, "Print / Save PDF", Colors.red, () { Navigator.pop(ctx); _generateAndPrintPDF(); }), const SizedBox(height: 12), _exportTile(Icons.table_chart_rounded, "Download Excel", Colors.green, () { Navigator.pop(ctx); _generateAndSaveExcel(); }), const SizedBox(height: 25)])));
  }

  Widget _exportTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)), const SizedBox(width: 15), Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)), const Spacer(), const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16)])));
  }
}

// -----------------------------------------------------------------------------
// TAB 1: INVENTORY REPORT (FULL PIE CHART - BLUE THEME FIXED)
// -----------------------------------------------------------------------------
class _InventoryReportTab extends StatefulWidget {
  final FirebaseFirestore db;
  final Timestamp? start;
  final Timestamp? end;

  const _InventoryReportTab({required this.db, this.start, this.end});

  @override
  State<_InventoryReportTab> createState() => _InventoryReportTabState();
}

class _InventoryReportTabState extends State<_InventoryReportTab> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    Query query = widget.db.collection('products');
    if (widget.start != null) query = query.where('updatedAt', isGreaterThanOrEqualTo: widget.start);
    if (widget.end != null) query = query.where('updatedAt', isLessThanOrEqualTo: widget.end);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No stock activity in this period.", style: TextStyle(color: Colors.grey)));

        double totalValue = 0;
        Map<String, double> catTotalUnits = {};
        Map<String, int> catProductCount = {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          double p = double.tryParse(data['price']?.toString() ?? '0') ?? 0;
          int s = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;

          totalValue += (p * s);
          String cat = (data['category'] ?? 'Others').toString().toUpperCase();

          catTotalUnits[cat] = (catTotalUnits[cat] ?? 0) + s.toDouble();
          catProductCount[cat] = (catProductCount[cat] ?? 0) + 1;
        }

        var lowStockItems = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          int stock = int.tryParse(data['currentStock'].toString()) ?? 0;
          return stock <= 10;
        }).toList();

        List<Widget> contentWidgets = [
          _buildPremiumStatCard("Stock Value (Cost)", "RM ${totalValue.toStringAsFixed(2)}", Icons.account_balance_wallet_outlined, const Color(0xFF233E99)),
          const SizedBox(height: 30),
          const Text("Category Distribution", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text("Breakdown by Total Units & Product Count", style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),

          _buildCategoryPieChart(catTotalUnits, catProductCount),

          const SizedBox(height: 30),
          const Text("Restock Needed", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black)),
          const SizedBox(height: 15),
        ];

        if (lowStockItems.isEmpty) {
          contentWidgets.add(_buildEmptyAlert());
        } else {
          for (var d in lowStockItems) {
            final data = d.data() as Map<String, dynamic>;
            contentWidgets.add(_buildModernAlertTile(
                data['productName'] ?? 'Item',
                "${data['currentStock']} units left",
                Icons.warning_amber_rounded,
                Colors.red,
                data
            ));
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: contentWidgets,
        );
      },
    );
  }

// --- FULL PIE CHART WIDGET (LAYOUT SEBELAH-MENYEBELAH, TIADA LUBANG) ---
  // --- FULL PIE CHART WIDGET (FIX: TEXT WRAPPING UTK NAMA PANJANG) ---
  Widget _buildCategoryPieChart(Map<String, double> unitData, Map<String, int> productCountData) {
    final List<Color> colors = [
      const Color(0xFF3B82F6), // Royal Blue
      const Color(0xFFEF4444), // Red Coral
      const Color(0xFF10B981), // Emerald Green
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF64748B), // Slate Grey
    ];

    double totalAllUnits = unitData.values.fold(0, (sum, item) => sum + item);
    List<PieChartSectionData> sections = [];
    List<Widget> indicators = [];
    int i = 0;

    unitData.forEach((category, qty) {
      final isTouched = i == _touchedIndex;
      final double radius = isTouched ? 75.0 : 70.0;
      final double widgetScale = isTouched ? 1.03 : 1.0;

      final color = colors[i % colors.length];
      final int productCount = productCountData[category] ?? 0;
      final percentage = totalAllUnits > 0 ? (qty / totalAllUnits * 100) : 0;

      // 1. Chart Section
      sections.add(PieChartSectionData(
        color: color,
        value: qty,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        titlePositionPercentageOffset: 0.6,
      ));

      // 2. Legend Item
      final List<BoxShadow> shadow = isTouched
          ? [const BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]
          : <BoxShadow>[];

      indicators.add(
          GestureDetector(
            onTap: () {
              setState(() {
                if (_touchedIndex == i) {
                  _touchedIndex = -1;
                } else {
                  _touchedIndex = i;
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              transform: Matrix4.identity()..scale(widgetScale),
              transformAlignment: Alignment.centerLeft,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  color: isTouched ? color.withOpacity(0.08) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: isTouched ? Border.all(color: color.withOpacity(0.5), width: 1.5) : Border.all(color: Colors.grey.shade100),
                  boxShadow: shadow
              ),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 12),

                  // [FIX DI SINI]: Expanded benarkan teks turun baris
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11, // Kecilkan sikit font
                              color: isTouched ? Colors.black : Colors.grey.shade800
                          ),
                          maxLines: 2, // Benarkan 2 baris
                          overflow: TextOverflow.ellipsis, // Kalau lebih 2 baris baru potong
                        ),
                        Text(
                            "$productCount Products",
                            style: TextStyle(
                                color: isTouched ? Colors.grey.shade700 : Colors.grey.shade500,
                                fontSize: 10
                            )
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text("${qty.toInt()}", style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13)),
                ],
              ),
            ),
          )
      );

      i++;
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // BAHAGIAN KIRI: CARTA (Kurangkan Flex supaya chart kecil sikit, bagi ruang teks)
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 0,
                  centerSpaceRadius: 0,
                  startDegreeOffset: -90,
                  sections: sections,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),

          // BAHAGIAN KANAN: LEGEND (Besarkan Flex supaya teks muat)
          Expanded(
            flex: 6, // 6 bahagian untuk teks, 4 bahagian untuk chart
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: indicators,
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET LAIN KEKAL SAMA ---
  Widget _buildEmptyAlert() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)),
      child: const Center(child: Text("All stock levels are healthy! ✅", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildPremiumStatCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: Colors.white60, size: 18), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 12),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5))
        ],
      ),
    );
  }

  Widget _buildModernAlertTile(String name, String subtitle, IconData icon, Color color, Map<String, dynamic> fullData) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow("Category", fullData['category'] ?? '-'),
                _detailRow("Current Stock", "${fullData['currentStock']} units"),
                _detailRow("Price", "RM ${fullData['price']}"),
                _detailRow("Last Update", fullData['updatedAt'] != null
                    ? DateFormat('dd MMM yyyy').format((fullData['updatedAt'] as Timestamp).toDate())
                    : '-'),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: color.withValues(alpha: 0.08)), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.02), blurRadius: 10)]),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1A1C1E))), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))])),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20)
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 2: FORECAST REPORT (SCROLLABLE & FILTERED)
// -----------------------------------------------------------------------------
class _ForecastReportTab extends StatelessWidget {
  final FirebaseFirestore db;
  final Timestamp? start;
  final Timestamp? end;

  const _ForecastReportTab({required this.db, this.start, this.end});

  @override
  Widget build(BuildContext context) {
    // Limit 50 data untuk diproses
    Query query = db.collection('forecasts')
        .orderBy('predictedDemand', descending: true)
        .limit(50);

    if (start != null) query = query.where('forecastDate', isGreaterThanOrEqualTo: start);
    if (end != null) query = query.where('forecastDate', isLessThanOrEqualTo: end);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.purple));
        }

        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

        final allDocs = snapshot.data?.docs ?? [];

        // --- 1. FILTER DATA (BUANG 0) ---
        final activeDocs = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          double val = double.tryParse(data['predictedDemand']?.toString() ?? '0') ?? 0;
          return val > 0;
        }).toList();

        if (activeDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart_rounded, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 15),
                const Text("No active forecast data.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        // --- 2. PERSIAPAN DATA GRAF ---
        // Kita ambil Top 30 untuk dimasukkan dalam graf (supaya boleh scroll)
        final chartDocs = activeDocs.take(30).toList();

        double maxY = 0;
        for (var doc in chartDocs) {
          final data = doc.data() as Map<String, dynamic>;
          double val = double.tryParse(data['predictedDemand']?.toString() ?? '0') ?? 0;
          if (val > maxY) maxY = val;
        }

        return ListView(
            padding: const EdgeInsets.fromLTRB(20, 25, 20, 100),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildHeader("Forecast Overview"),
              const SizedBox(height: 5),
              Text("Top ${chartDocs.length} predicted items (Scrollable)", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20),

              // --- 3. SCROLLABLE BAR CHART ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal, // Benarkan scroll ke tepi
                child: Container(
                  // Kiraan lebar dinamik: Setiap batang dapat 60px
                  width: (chartDocs.length * 60.0).clamp(MediaQuery.of(context).size.width - 40, 5000.0),
                  height: 320,
                  padding: const EdgeInsets.fromLTRB(10, 24, 20, 10),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))]
                  ),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY * 1.2,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipPadding: const EdgeInsets.all(8),
                          tooltipMargin: 8,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final data = chartDocs[groupIndex].data() as Map<String, dynamic>;
                            return BarTooltipItem(
                              "${data['productName']}\n",
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              children: [
                                TextSpan(
                                  text: "${rod.toY.toInt()} Units",
                                  style: const TextStyle(color: Colors.yellowAccent, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < chartDocs.length) {
                                final data = chartDocs[index].data() as Map<String, dynamic>;
                                String name = data['productName'] ?? '';
                                // Pendekkan nama untuk label bawah
                                if (name.length > 8) name = "${name.substring(0, 8)}..";

                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: RotatedBox(
                                    quarterTurns: 0,
                                    child: Text(name, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: chartDocs.asMap().entries.map((entry) {
                        int idx = entry.key;
                        final data = entry.value.data() as Map<String, dynamic>;
                        double val = double.tryParse(data['predictedDemand']?.toString() ?? '0') ?? 0;

                        return BarChartGroupData(
                          x: idx,
                          barRods: [
                            BarChartRodData(
                              toY: val,
                              color: Colors.purpleAccent,
                              width: 30, // Batang lebih lebar sebab ada ruang scroll
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: maxY * 1.2,
                                color: Colors.grey.withOpacity(0.05),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 35),
              _buildHeader("Detailed Forecast List"),
              const SizedBox(height: 15),

              // Senarai penuh di bawah
              ...activeDocs.map((d) {
                final data = d.data() as Map<String, dynamic>;
                String dateStr = "N/A";
                if (data['forecastDate'] is Timestamp) {
                  dateStr = DateFormat('dd MMM').format((data['forecastDate'] as Timestamp).toDate());
                }
                double val = double.tryParse(data['predictedDemand']?.toString() ?? '0') ?? 0;

                return _buildForecastTile(dateStr, data['productName'] ?? 'Unknown', val.toInt().toString());
              })
            ]
        );
      },
    );
  }

  Widget _buildHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E)));
  }

  Widget _buildForecastTile(String date, String productName, String demand) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.trending_up_rounded, color: Colors.purple, size: 20)),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(productName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text("Forecast Date: $date", style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold))
        ])),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(demand, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.purple)), const Text("units", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))])
      ]),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 3: RISK REPORT (TOOLTIP FIXED + POPUP ADDED)
// -----------------------------------------------------------------------------
class _RiskReportTab extends StatefulWidget {
  final FirebaseFirestore db;
  const _RiskReportTab({required this.db});

  @override
  State<_RiskReportTab> createState() => _RiskReportTabState();
}

class _RiskReportTabState extends State<_RiskReportTab> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.db.collection('risk_analysis').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return Center(child: Text("No health issues detected.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));
        final docs = snapshot.data!.docs;
        return ListView(
            padding: const EdgeInsets.fromLTRB(20, 25, 20, 100),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildRiskHeader(docs.length),
              const SizedBox(height: 30),
              ...docs.map((d) {
                final data = d.data() as Map<String, dynamic>;
                return _buildRiskTile(
                    data['ProductName'] ?? 'Unknown',
                    "Expires in ${data['DaysToExpiry'] ?? 0} days",
                    data['RiskLevel'] ?? 'Low',
                    data // Pass Full Data
                );
              })
            ]
        );
      },
    );
  }

  Widget _buildRiskHeader(int count) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFFD32F2F), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: const Color(0xFFD32F2F).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle), child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 28)),
        const SizedBox(width: 15),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Items at Risk", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)), Text("$count Items", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))])
      ]),
    );
  }

  // [MODIFIED] Added Popup
  Widget _buildRiskTile(String productName, String subtitle, String probability, Map<String, dynamic> fullData) {
    Color riskColor = Colors.green;
    String prob = probability.toLowerCase();
    if (prob.contains('high')) riskColor = const Color(0xFFD32F2F); else if (prob.contains('medium')) riskColor = Colors.orange;

    return InkWell(
      onTap: () {
        // 1. Kira Tarikh Luput (Hari ini + Baki Hari)
        int daysLeft = int.tryParse(fullData['DaysToExpiry']?.toString() ?? '0') ?? 0;
        DateTime expDate = DateTime.now().add(Duration(days: daysLeft));
        String dateStr = DateFormat('dd MMM yyyy').format(expDate);

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Icon(Icons.warning_amber_rounded, color: riskColor),
              const SizedBox(width: 10),
              Expanded(child: Text("Risk Alert", style: TextStyle(color: riskColor, fontWeight: FontWeight.bold))),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                _detailRow("Risk Level", probability.toUpperCase()),
                _detailRow("Days to Expiry", "${fullData['DaysToExpiry']} days"),

                // [BARU] Tunjuk Tarikh Luput Sebenar
                _detailRow("Expiry Date", dateStr),

                const SizedBox(height: 10),
                const Text("Recommendation:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                    prob.contains('high')
                        ? "Clear stock immediately (Discount/Promo)."
                        : "Monitor stock movement closely.",
                    style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)
                ),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: riskColor.withOpacity(0.2), width: 1), // Guna withOpacity utk elak error version
            boxShadow: [BoxShadow(color: riskColor.withOpacity(0.05), blurRadius: 10)]
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: riskColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(probability.toUpperCase(), style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.w900))
            ),
            const Spacer(),
            Icon(Icons.info_outline_rounded, size: 20, color: Colors.grey[400])
          ]),
          const SizedBox(height: 10),
          Text(productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: riskColor),
            const SizedBox(width: 5),
            Expanded(child: Text(subtitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: riskColor)))
          ])
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 4: SALES REPORT (UPDATED TO BAR CHART)
// -----------------------------------------------------------------------------
class _SalesReportTab extends StatelessWidget {
  final FirebaseFirestore db;
  final Timestamp? start;
  final Timestamp? end;
  const _SalesReportTab({required this.db, this.start, this.end});

  @override
  Widget build(BuildContext context) {
    Query query = db.collection('sales').orderBy('saleDate', descending: false);
    if (start != null) query = query.where('saleDate', isGreaterThanOrEqualTo: start);
    if (end != null) query = query.where('saleDate', isLessThanOrEqualTo: end);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No sales records found for this period.", style: TextStyle(color: Colors.grey)));
        }

        // --- 1. DATA AGGREGATION ---
        Map<String, double> dailySalesMap = {};
        double totalRevenuePeriod = 0;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          Timestamp? t = data['saleDate'];
          if (t == null) continue;
          String dateKey = DateFormat('yyyy-MM-dd').format(t.toDate());
          double amount = double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0;

          dailySalesMap[dateKey] = (dailySalesMap[dateKey] ?? 0) + amount;
          totalRevenuePeriod += amount;
        }

        List<String> sortedDates = dailySalesMap.keys.toList()..sort();

        // Cari max Y untuk scale graf
        double maxY = 0;
        if (dailySalesMap.isNotEmpty) {
          maxY = dailySalesMap.values.reduce((a, b) => a > b ? a : b);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: [
            // KAD TOTAL REVENUE
            Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF00796B), Color(0xFF004D40)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: const Color(0xFF004D40).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Total Revenue (Period)", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text("RM ${totalRevenuePeriod.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text("${docs.length} Transactions processed", style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600))
                ])
            ),

            const SizedBox(height: 30),
            const Text("Daily Sales Performance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
            const SizedBox(height: 15),

            // --- 2. SCROLLABLE BAR CHART WIDGET ---
            if (sortedDates.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal, // Benarkan scroll ke tepi
                child: Container(
                  // KIRAAN LEBAR: Setiap batang dapat 50px ruang.
                  // Kalau data sikit, guna lebar skrin penuh. Kalau banyak, dia memanjang.
                  width: (sortedDates.length * 50.0).clamp(MediaQuery.of(context).size.width - 40, 5000.0),
                  height: 300,
                  padding: const EdgeInsets.fromLTRB(10, 24, 20, 10),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                  ),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY * 1.1,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipPadding: const EdgeInsets.all(8),
                          tooltipMargin: 8,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            String dateKey = sortedDates[groupIndex];
                            DateTime date = DateTime.parse(dateKey);
                            String formattedDate = DateFormat('dd MMM').format(date);

                            return BarTooltipItem(
                              "$formattedDate\n",
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              children: [
                                TextSpan(
                                  text: "RM ${rod.toY.toStringAsFixed(2)}",
                                  style: const TextStyle(color: Colors.tealAccent, fontSize: 14, fontWeight: FontWeight.w900),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < sortedDates.length) {
                                DateTime date = DateTime.parse(sortedDates[index]);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                      DateFormat('d/M').format(date),
                                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: sortedDates.asMap().entries.map((entry) {
                        int idx = entry.key;
                        String dateKey = entry.value;
                        double val = dailySalesMap[dateKey]!;

                        return BarChartGroupData(
                          x: idx,
                          barRods: [
                            BarChartRodData(
                              toY: val,
                              color: const Color(0xFF00796B),
                              width: 25, // Lebar batang yang selesa sebab boleh scroll
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: maxY * 1.1,
                                color: Colors.grey.withOpacity(0.05),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              )
            else
              const Center(child: Text("Not enough data for chart")),

            const SizedBox(height: 30),
            const Text("Daily Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
            const SizedBox(height: 15),

            // --- 3. LIST (DAILY SUMMARY) ---
            ...sortedDates.reversed.map((dateKey) {
              double total = dailySalesMap[dateKey]!;
              DateTime date = DateTime.parse(dateKey);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.calendar_today_rounded, color: Colors.teal, size: 20)
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('dd MMMM yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1C1E))),
                            const SizedBox(height: 4),
                            Text(DateFormat('EEEE').format(date), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                    Text("RM ${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF00796B))),
                  ],
                ),
              );
            })
          ],
        );
      },
    );
  }
}