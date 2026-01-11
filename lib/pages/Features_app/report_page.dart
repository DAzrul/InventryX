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

  // --- FILTER STATE ---
  String _selectedTimeframe = 'All Time';
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
      setState(() => _selectedTimeframe = 'All Time');
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
      List<pw.Widget> gridCards = [];

      final PdfColor brandColor = PdfColors.blue900;
      final PdfColor accentColor = PdfColors.grey200;

      if (tabIndex == 0) {
        // --- 1. INVENTORY ---
        reportTitle = "CURRENT STOCK REPORT";
        timeframeLabel = "Snapshot: Today (Active)";

        Query query = _db.collection('products').orderBy('productName');
        if (startTimestamp != null) query = query.where('updatedAt', isGreaterThanOrEqualTo: startTimestamp);
        if (endTimestamp != null) query = query.where('updatedAt', isLessThanOrEqualTo: endTimestamp);

        final snap = await query.get();

        double totalVal = 0;
        int lowStockCount = 0;

        for (var d in snap.docs) {
          final data = d.data() as Map<String, dynamic>; // Explicit cast
          int s = int.tryParse(data['currentStock'].toString()) ?? 0;
          double p = double.tryParse(data['price'].toString()) ?? 0;
          double rowTot = s * p;
          totalVal += rowTot;
          if (s <= 10) lowStockCount++;

          gridCards.add(
              pw.Container(
                  width: 150, height: 85, margin: const pw.EdgeInsets.all(6), padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: s <= 10 ? PdfColors.red50 : PdfColors.white,
                    border: pw.Border.all(color: s <= 10 ? PdfColors.red200 : PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text(data['productName']?.toString().toUpperCase() ?? '-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blue900), maxLines: 2, overflow: pw.TextOverflow.clip),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text("STOCK", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                        pw.Text(s.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: s <= 10 ? PdfColors.red : PdfColors.black)),
                      ]),
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                        pw.Text("VALUE", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                        pw.Text("RM ${rowTot.toStringAsFixed(0)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.green700)),
                      ]),
                    ])
                  ])
              )
          );
        }
        summaryText = "Inventory Valuation Report. Total Asset Value: RM ${totalVal.toStringAsFixed(2)}. Critical items: $lowStockCount.";

      } else if (tabIndex == 1) {
        // --- 2. FORECAST ---
        reportTitle = "FUTURE SALES FORECAST";
        tableHeaders = ['Date', 'Product', 'Expected Sales', 'Status'];

        Query query = _db.collection('forecasts').orderBy('predictedDemand', descending: true);
        final snap = await query.get();

        for (var d in snap.docs) {
          final data = d.data() as Map<String, dynamic>; // Explicit cast
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
          final data = d.data() as Map<String, dynamic>; // Explicit cast
          String level = data['RiskLevel']?.toString().toUpperCase() ?? 'LOW';
          String expiryInfo = "${data['DaysToExpiry'] ?? 0} Days Left";
          tableData.add([data['ProductName'] ?? '-', level, expiryInfo, "Monitoring"]);
        }
        summaryText = "Current risk assessment. Prioritize High Risk items for clearance.";

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
            "RM ${rev.toStringAsFixed(2)}"
          ]);
        }
        summaryText = "Financial sales record. Total Revenue: RM ${totalRev.toStringAsFixed(2)}.";
      }

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
              if (tabIndex == 0)
                pw.Wrap(spacing: 10, runSpacing: 10, children: gridCards)
              else
                pw.TableHelper.fromTextArray(
                  context: context, headers: tableHeaders, data: tableData, border: null,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                  headerDecoration: pw.BoxDecoration(color: brandColor, borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4))),
                  cellStyle: const pw.TextStyle(fontSize: 9),
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
          final data = d.data() as Map<String, dynamic>; // Explicit cast
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
          final data = d.data() as Map<String, dynamic>; // Explicit cast
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
          final data = d.data() as Map<String, dynamic>; // Explicit cast
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
          final data = d.data() as Map<String, dynamic>; // Explicit cast
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
        bottom: PreferredSize(preferredSize: const Size.fromHeight(65), child: Container(margin: const EdgeInsets.fromLTRB(16, 0, 16, 12), padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(25)), child: TabBar(controller: _tabController, isScrollable: false, indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]), labelColor: primaryBlue, labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12), unselectedLabelColor: Colors.grey.shade500, unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), dividerColor: Colors.transparent, tabs: const [Tab(text: "Stock"), Tab(text: "Forecast"), Tab(text: "Health"), Tab(text: "Sales")]))),
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

// 1. INVENTORY TAB
class _InventoryReportTab extends StatelessWidget {
  final FirebaseFirestore db;
  final Timestamp? start;
  final Timestamp? end;
  const _InventoryReportTab({required this.db, this.start, this.end});

  @override
  Widget build(BuildContext context) {
    // Filter by Updated At
    Query query = db.collection('products');
    if (start != null) query = query.where('updatedAt', isGreaterThanOrEqualTo: start);
    if (end != null) query = query.where('updatedAt', isLessThanOrEqualTo: end);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        double totalValue = 0;
        Map<String, double> catData = {};
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No stock activity in this period.", style: TextStyle(color: Colors.grey)));

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>; // Explicit cast
          double p = double.tryParse(data['price']?.toString() ?? '0') ?? 0;
          int s = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
          totalValue += (p * s);
          catData[data['category'] ?? 'Others'] = (catData[data['category']] ?? 0) + s.toDouble();
        }
        return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), physics: const BouncingScrollPhysics(), children: [_buildPremiumStatCard("Total Asset Value", "RM ${totalValue.toStringAsFixed(2)}", Icons.account_balance_wallet_outlined, const Color(0xFF233E99)), const SizedBox(height: 30), const Text("Category Distribution", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(height: 15), _buildCleanBarChart(catData), const SizedBox(height: 30), const Text("Critical Stock Alerts", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.redAccent)), const SizedBox(height: 15), if (docs.where((d) => (int.tryParse((d.data() as Map<String, dynamic>)['currentStock'].toString()) ?? 0) <= 10).isEmpty) _buildEmptyAlert() else ...docs.where((d) => (int.tryParse((d.data() as Map<String, dynamic>)['currentStock'].toString()) ?? 0) <= 10).map((d) {
          final data = d.data() as Map<String, dynamic>;
          return _buildModernAlertTile(data['productName'] ?? 'Item', "${data['currentStock']} units left", Icons.warning_amber_rounded, Colors.red);
        })]);
      },
    );
  }
  Widget _buildEmptyAlert() { return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)), child: const Center(child: Text("All stock levels are healthy! ✅", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))); }
  Widget _buildPremiumStatCard(String title, String val, IconData icon, Color color) { return Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: Colors.white60, size: 18), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600))]), const SizedBox(height: 12), Text(val, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5))])); }
  Widget _buildCleanBarChart(Map<String, double> data) { return Container(height: 260, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20)]), child: BarChart(BarChartData(maxY: data.values.isEmpty ? 10 : data.values.reduce((a, b) => a > b ? a : b) * 1.3, barGroups: data.entries.map((e) => BarChartGroupData(x: data.keys.toList().indexOf(e.key), barRods: [BarChartRodData(toY: e.value, color: const Color(0xFF233E99), width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))])).toList(), titlesData: FlTitlesData(topTitles: const AxisTitles(), rightTitles: const AxisTitles(), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) { if (v.toInt() >= data.length) return const SizedBox(); return Padding(padding: const EdgeInsets.only(top: 10), child: Text(data.keys.elementAt(v.toInt()).substring(0, 3).toUpperCase(), style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w900))); })), leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: Colors.grey.shade400))))), gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)), borderData: FlBorderData(show: false)))); }
  Widget _buildModernAlertTile(String name, String subtitle, IconData icon, Color color) { return Container(margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: color.withValues(alpha: 0.08)), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.02), blurRadius: 10)]), child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1A1C1E))), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))])), const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14)])); }
}

// 2. FORECAST TAB (FILTERED)
class _ForecastReportTab extends StatelessWidget {
  final FirebaseFirestore db;
  final Timestamp? start;
  final Timestamp? end;
  const _ForecastReportTab({required this.db, this.start, this.end});

  @override
  Widget build(BuildContext context) {
    Query query = db.collection('forecasts').orderBy('forecastDate', descending: false);
    if (start != null) query = query.where('forecastDate', isGreaterThanOrEqualTo: start);
    if (end != null) query = query.where('forecastDate', isLessThanOrEqualTo: end);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty || docs.length < 2) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.insights_rounded, size: 60, color: Colors.grey.shade300), const SizedBox(height: 15), const Text("Not enough data to show trends yet.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)), const Text("Run 'Forecast' in Utilities to generate.", style: TextStyle(color: Colors.grey, fontSize: 11))]));
        }

        List<FlSpot> spots = [];
        double maxDemand = 0;
        final chartDocs = docs;

        for (int i = 0; i < chartDocs.length; i++) {
          final data = chartDocs[i].data() as Map<String, dynamic>; // Explicit cast
          double val = double.tryParse(data['predictedDemand']?.toString() ?? '0') ?? 0;
          if (val > maxDemand) maxDemand = val;
          spots.add(FlSpot(i.toDouble(), val));
        }

        return ListView(padding: const EdgeInsets.fromLTRB(20, 25, 20, 100), physics: const BouncingScrollPhysics(), children: [
          _buildHeader("Sales Forecast Trend"),
          const SizedBox(height: 20),
          _buildLineChart(spots, maxDemand, chartDocs),
          const SizedBox(height: 35),
          _buildHeader("Expected Sales List"),
          const SizedBox(height: 15),
          ...docs.take(10).map((d) {
            final data = d.data() as Map<String, dynamic>; // Explicit cast
            String dateStr = "N/A";
            if (data['forecastDate'] is Timestamp) {
              dateStr = DateFormat('dd MMM').format((data['forecastDate'] as Timestamp).toDate());
            }
            double val = double.tryParse(data['predictedDemand']?.toString() ?? '0') ?? 0;
            return _buildForecastTile(dateStr, data['productName'] ?? 'Unknown', val.toInt().toString());
          })
        ]);
      },
    );
  }
  Widget _buildHeader(String title) { return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))); }
  Widget _buildLineChart(List<FlSpot> spots, double maxY, List<QueryDocumentSnapshot> docs) {
    return Container(height: 300, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.purple.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 5))]), child: LineChart(LineChartData(minX: 0, maxX: (spots.length - 1).toDouble(), minY: 0, maxY: maxY * 1.2, lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: Colors.purpleAccent, barWidth: 4, isStrokeCapRound: true, dotData: FlDotData(show: true), belowBarData: BarAreaData(show: true, color: Colors.purpleAccent.withValues(alpha: 0.1)))], titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: (docs.length / 5).ceil().toDouble(), getTitlesWidget: (value, meta) {
          int index = value.toInt();
          if (index >= 0 && index < docs.length) {
            final data = docs[index].data() as Map<String, dynamic>; // Explicit cast
            if (data['forecastDate'] is Timestamp) {
              return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(DateFormat('d/M').format((data['forecastDate'] as Timestamp).toDate()), style: const TextStyle(fontSize: 10, color: Colors.grey)));
            }
          }
          return const SizedBox();
        })),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey))))), gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)), borderData: FlBorderData(show: false))));
  }
  Widget _buildForecastTile(String date, String productName, String demand) { return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.trending_up_rounded, color: Colors.purple, size: 20)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(productName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 2), Text("Target Date: $date", style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold))])), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(demand, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.purple)), const Text("units", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))])])); }
}

// 3. RISK TAB (REMOVED SCORE)
class _RiskReportTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _RiskReportTab({required this.db});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('risk_analysis').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return Center(child: Text("No risk data detected.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));
        final docs = snapshot.data!.docs;
        return ListView(padding: const EdgeInsets.fromLTRB(20, 25, 20, 100), physics: const BouncingScrollPhysics(), children: [_buildRiskHeader(docs.length), const SizedBox(height: 30), ...docs.map((d) { final data = d.data() as Map<String, dynamic>; return _buildRiskTile(data['ProductName'] ?? 'Unknown', "Expires in ${data['DaysToExpiry'] ?? 0} days", data['RiskLevel'] ?? 'Low'); })]);
      },
    );
  }
  Widget _buildRiskHeader(int count) { return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFFD32F2F), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: const Color(0xFFD32F2F).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))]), child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle), child: const Icon(Icons.security_rounded, color: Colors.white, size: 28)), const SizedBox(width: 15), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Identified Risks", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)), Text("$count Items", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))])])); }
  Widget _buildRiskTile(String productName, String subtitle, String probability) { Color riskColor = Colors.green; String prob = probability.toLowerCase(); if (prob.contains('high')) riskColor = const Color(0xFFD32F2F); else if (prob.contains('medium')) riskColor = Colors.orange; return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: riskColor.withValues(alpha: 0.2), width: 1), boxShadow: [BoxShadow(color: riskColor.withValues(alpha: 0.05), blurRadius: 10)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: riskColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(probability.toUpperCase(), style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.w900))), const Spacer(), Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey[400])]), const SizedBox(height: 10), Text(productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))), const SizedBox(height: 6), Row(children: [Icon(Icons.warning_amber_rounded, size: 14, color: riskColor), const SizedBox(width: 5), Expanded(child: Text(subtitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: riskColor)))])])); }
}

// 4. SALES TAB (FULL ACCESS - SHOW MONEY)
class _SalesReportTab extends StatelessWidget {
  final FirebaseFirestore db;
  final Timestamp? start;
  final Timestamp? end;
  const _SalesReportTab({required this.db, this.start, this.end});

  @override
  Widget build(BuildContext context) {
    Query query = db.collection('sales').orderBy('saleDate', descending: true);
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

        double totalSalesAmount = 0;
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>; // Explicit cast
          totalSalesAmount += double.tryParse(data['totalAmount'].toString()) ?? 0;
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: [
            Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00796B), Color(0xFF004D40)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: const Color(0xFF004D40).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Total Sales Revenue", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(height: 8), Text("RM ${totalSalesAmount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text("${docs.length} Transactions", style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600))])
            ),
            const SizedBox(height: 30),
            const Text("Recent Transactions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
            const SizedBox(height: 15),
            ...docs.map((d) {
              final data = d.data() as Map<String, dynamic>; // Explicit cast
              String dateStr = 'Unknown';
              if (data['saleDate'] != null) { dateStr = DateFormat('dd MMM, HH:mm').format((data['saleDate'] as Timestamp).toDate()); }
              double amount = double.tryParse(data['totalAmount'].toString()) ?? 0;
              String productName = data['snapshotName'] ?? 'Unknown Item';
              int quantity = int.tryParse(data['quantitySold'].toString()) ?? 0;

              return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("Qty: $quantity unit", style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(productName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1C1E)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    ])),
                    Text("RM ${amount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF00796B)))
                  ])
              );
            })
          ],
        );
      },
    );
  }
}