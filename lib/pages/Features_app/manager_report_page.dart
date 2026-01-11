import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// Package Export
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as ex;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

// Navigation Imports
import '../manager/manager_page.dart';
import '../manager/utils/manager_features_modal.dart';
import '../Profile/User_profile_page.dart';

class ManagerReportPage extends StatefulWidget {
  final String loggedInUsername;
  final String userId;

  const ManagerReportPage({
    super.key,
    required this.loggedInUsername,
    required this.userId
  });

  @override
  State<ManagerReportPage> createState() => _ManagerReportPageState();
}

class _ManagerReportPageState extends State<ManagerReportPage> with SingleTickerProviderStateMixin {
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
      lastDate: DateTime.now().add(const Duration(days: 365)), // Boleh pilih future utk forecast
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
        // Set end date to end of the day (23:59:59)
        _customEndDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _selectedTimeframe = 'Custom Range';
      });
    } else {
      // Kalau user cancel, revert balik ke All Time
      setState(() => _selectedTimeframe = 'All Time');
    }
  }

  // --- HELPER: DAPATKAN TARIKH MULA & TAMAT ---
  // Return Map: {'start': Timestamp?, 'end': Timestamp?}
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
    // All Time: start & end kekal null

    return {
      'start': start != null ? Timestamp.fromDate(start) : null,
      'end': end != null ? Timestamp.fromDate(end) : null
    };
  }

  // ===========================================================================
  // 1. PROFESSIONAL PDF GENERATOR
  // ===========================================================================
  Future<void> _generateAndPrintPDF() async {
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final pdf = pw.Document();
      final int tabIndex = _tabController.index;
      final String generatedBy = widget.loggedInUsername;
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

        // Filter Logic for Stock (Updated At)
        Query query = _db.collection('products').orderBy('productName');
        if (startTimestamp != null) query = query.where('updatedAt', isGreaterThanOrEqualTo: startTimestamp);
        if (endTimestamp != null) query = query.where('updatedAt', isLessThanOrEqualTo: endTimestamp);

        final snap = await query.get();

        double totalVal = 0;
        int lowStockCount = 0;

        for (var d in snap.docs) {
          final data = d.data() as Map<String, dynamic>;
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
        summaryText = "Stock activity overview for selected period. Total Value: RM ${totalVal.toStringAsFixed(2)}. Items needing restock: $lowStockCount items.";

      } else if (tabIndex == 1) {
        // --- 2. FORECAST ---
        reportTitle = "FUTURE SALES FORECAST";
        tableHeaders = ['Date', 'Product', 'Expected Sales', 'Status'];

        Query query = _db.collection('forecasts').orderBy('predictedDemand', descending: true);
        final snap = await query.get();

        for (var d in snap.docs) {
          final data = d.data() as Map<String, dynamic>;
          // Manual Filter for Date Range
          if (data['forecastDate'] != null) {
            Timestamp t = data['forecastDate'];
            if (startTimestamp != null && t.compareTo(startTimestamp) < 0) continue;
            if (endTimestamp != null && t.compareTo(endTimestamp) > 0) continue;
          }

          String date = data['forecastDate'] != null ? DateFormat('yyyy-MM-dd').format((data['forecastDate'] as Timestamp).toDate()) : '-';
          double demand = double.tryParse(data['predictedDemand'].toString()) ?? 0;
          tableData.add([date, data['productName'] ?? '-', "${demand.toInt()} Units", demand > 50 ? "High Demand" : "Normal"]);
        }
        summaryText = "AI prediction of items likely to sell in selected period.";

      } else if (tabIndex == 2) {
        // --- 3. RISK ---
        reportTitle = "EXPIRY & HEALTH CHECK";
        timeframeLabel = "Snapshot: Today"; // Risk usually current
        tableHeaders = ['Product Name', 'Risk Level', 'Days Left', 'Status'];
        final snap = await _db.collection('risk_analysis').orderBy('RiskValue', descending: true).get();

        for (var d in snap.docs) {
          final data = d.data();
          String level = data['RiskLevel']?.toString().toUpperCase() ?? 'LOW';
          String expiryInfo = "${data['DaysToExpiry'] ?? 0} days";
          tableData.add([data['ProductName'] ?? '-', level, expiryInfo, "Monitoring"]);
        }
        summaryText = "Report highlighting items that are expiring soon or at risk of spoilage.";

      } else if (tabIndex == 3) {
        // --- 4. SALES ---
        reportTitle = "SALES LOG (MANAGEMENT VIEW)";
        tableHeaders = ['Date', 'Sale ID', 'Product', 'Qty Sold'];

        Query query = _db.collection('sales').orderBy('saleDate', descending: true);
        if (startTimestamp != null) query = query.where('saleDate', isGreaterThanOrEqualTo: startTimestamp);
        if (endTimestamp != null) query = query.where('saleDate', isLessThanOrEqualTo: endTimestamp);

        final snap = await query.get();

        for (var d in snap.docs) {
          final data = d.data() as Map<String, dynamic>;
          String date = data['saleDate'] != null
              ? DateFormat('dd/MM/yyyy').format((data['saleDate'] as Timestamp).toDate())
              : '-';

          String productName = data['snapshotName'] ?? 'Unknown Item';
          String qty = (data['quantitySold'] ?? 0).toString();

          tableData.add([date, d.id.substring(0, 8).toUpperCase(), productName, qty]);
        }
        summaryText = "Sales activity log for selected period. Revenue data is hidden for security.";
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => pw.Column(children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text("INVENTRYX REPORT", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20, color: brandColor)),
              pw.Text("CONFIDENTIAL", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.red)),
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
                  pw.Text("By: $generatedBy", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text(generateDate, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text(timeframeLabel, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: brandColor)),
                ]),
              ]),
              pw.SizedBox(height: 15),
              pw.Container(
                  width: double.infinity, padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(color: accentColor, borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Text(summaryText, style: const pw.TextStyle(fontSize: 10))
              ),
              pw.SizedBox(height: 20),
              if (tabIndex == 0) pw.Wrap(spacing: 10, runSpacing: 10, children: gridCards)
              else pw.TableHelper.fromTextArray(
                  context: context, headers: tableHeaders, data: tableData,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                  headerDecoration: pw.BoxDecoration(color: brandColor),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)))
              ),
            ];
          },
        ),
      );

      if (mounted) Navigator.pop(context);
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Inventryx_Report');

    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  // ===========================================================================
  // 2. EXPORT EXCEL
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

      String sheetName = "Data";
      List<String> headers = [];
      List<List<dynamic>> rows = [];

      if (tabIndex == 0) {
        sheetName = "StockList";
        headers = ['Item Name', 'Category', 'Quantity Left', 'Unit Price', 'Total Value'];

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
        sheetName = "Forecast";
        headers = ['Date', 'Item Name', 'Expected Units'];
        final snap = await _db.collection('forecasts').get();
        for (var d in snap.docs) {
          final data = d.data();
          if (data['forecastDate'] != null) {
            Timestamp t = data['forecastDate'];
            if (startTimestamp != null && t.compareTo(startTimestamp) < 0) continue;
            if (endTimestamp != null && t.compareTo(endTimestamp) > 0) continue;
          }
          double val = double.tryParse(data['predictedDemand'].toString()) ?? 0;
          rows.add([data['forecastDate'] != null ? DateFormat('yyyy-MM-dd').format((data['forecastDate'] as Timestamp).toDate()) : '-', data['productName'] ?? '', val.toInt()]);
        }
      } else if (tabIndex == 2) {
        sheetName = "RiskCheck";
        headers = ['Item Name', 'Risk Level', 'Days to Expire'];
        final snap = await _db.collection('risk_analysis').get();
        for (var d in snap.docs) {
          final data = d.data();
          rows.add([data['ProductName'] ?? '', data['RiskLevel'] ?? '', data['DaysToExpiry'] ?? 0]);
        }
      } else if (tabIndex == 3) {
        sheetName = "SalesLog";
        headers = ['Date', 'Sale ID', 'Item Name', 'Qty Sold'];
        Query query = _db.collection('sales').orderBy('saleDate', descending: true);
        if (startTimestamp != null) query = query.where('saleDate', isGreaterThanOrEqualTo: startTimestamp);
        if (endTimestamp != null) query = query.where('saleDate', isLessThanOrEqualTo: endTimestamp);

        final snap = await query.get();
        for (var d in snap.docs) {
          final data = d.data() as Map<String, dynamic>;
          rows.add([data['saleDate'] != null ? DateFormat('yyyy-MM-dd').format((data['saleDate'] as Timestamp).toDate()) : '-', d.id, data['snapshotName'] ?? '', data['quantitySold'] ?? 0]);
        }
      }

      ex.Sheet sheet = excel[sheetName];
      sheet.appendRow([ex.TextCellValue("REPORT GENERATED ON ${DateFormat('yyyy-MM-dd').format(DateTime.now())}")]);
      sheet.appendRow([ex.TextCellValue("")]);
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
      final path = '${directory.path}/Report_${sheetName}.xlsx';
      final file = File(path);
      await file.writeAsBytes(fileBytes!);

      if (mounted) Navigator.pop(context);
      await OpenFilex.open(file.path);

    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => ManagerPage(loggedInUsername: widget.loggedInUsername, userId: widget.userId, username: '')), (Route<dynamic> route) => false);
    } else if (index == 1) {
      ManagerFeaturesModal.show(context, widget.loggedInUsername, widget.userId);
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          String currentUsername = widget.loggedInUsername;
          if (snapshot.hasData && snapshot.data!.exists) {
            var d = snapshot.data!.data() as Map<String, dynamic>;
            currentUsername = d['username'] ?? widget.loggedInUsername;
          }
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFF),
            body: IndexedStack(
                index: _selectedIndex == 2 ? 1 : 0,
                children: [
                  _buildReportUI(context),
                  ProfilePage(username: currentUsername, userId: widget.userId)
                ]
            ),
            bottomNavigationBar: _buildFloatingNavBar(),
          );
        });
  }

  Widget _buildFloatingNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12), height: 62,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(25), child: BottomNavigationBar(currentIndex: _selectedIndex, onTap: _onItemTapped, backgroundColor: Colors.white, selectedItemColor: primaryBlue, unselectedItemColor: Colors.grey.shade400, showSelectedLabels: true, showUnselectedLabels: false, type: BottomNavigationBarType.fixed, elevation: 0, selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10), items: [_navItem(Icons.home_outlined, Icons.home_rounded, "Home"), _navItem(Icons.grid_view_outlined, Icons.grid_view_rounded, "Features"), _navItem(Icons.person_outline_rounded, Icons.person_rounded, "Profile")])),
    );
  }

  BottomNavigationBarItem _navItem(IconData inactiveIcon, IconData activeIcon, String label) {
    return BottomNavigationBarItem(icon: Icon(inactiveIcon, size: 22), activeIcon: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), shape: BoxShape.circle), child: Icon(activeIcon, size: 22, color: primaryBlue)), label: label);
  }

  Widget _buildReportUI(BuildContext context) {
    // Get timestamps for current filter
    final dateRange = _getDateRange();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("Performance Reports", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E), fontSize: 22)),
        centerTitle: true, backgroundColor: Colors.white, elevation: 0, automaticallyImplyLeading: false,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: primaryBlue.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTimeframe,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryBlue, size: 20),
                style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 12),
                onChanged: (String? newValue) {
                  if (newValue == 'Custom Range') {
                    _pickDateRange();
                  } else {
                    setState(() => _selectedTimeframe = newValue!);
                  }
                },
                items: <String>['All Time', 'This Month', 'This Year', 'Custom Range'].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.only(right: 12), child: IconButton(icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.file_download_outlined, color: primaryBlue, size: 22)), onPressed: () => _showExportOptions(context)))
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(65), child: Container(margin: const EdgeInsets.fromLTRB(16, 0, 16, 12), padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(25)), child: TabBar(controller: _tabController, isScrollable: false, indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]), labelColor: primaryBlue, labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12), unselectedLabelColor: Colors.grey.shade500, unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), dividerColor: Colors.transparent, tabs: const [Tab(text: "Stock"), Tab(text: "Forecast"), Tab(text: "Health"), Tab(text: "Sales")]))),
      ),
      body: TabBarView(
          controller: _tabController,
          physics: const BouncingScrollPhysics(),
          children: [
            _InventoryReportTab(db: _db, start: dateRange['start'], end: dateRange['end']),
            _ForecastReportTab(db: _db, start: dateRange['start'], end: dateRange['end']),
            _RiskReportTab(db: _db), // Risk typically snapshot
            _SalesReportTab(db: _db, start: dateRange['start'], end: dateRange['end'])
          ]
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    List<String> tabNames = ["Stock List", "Forecast", "Health Status", "Sales Log"];
    String currentTab = tabNames[_tabController.index];
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (ctx) => Container(padding: const EdgeInsets.all(24), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10))), const SizedBox(height: 25), Text("Export $currentTab", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))), const SizedBox(height: 30), _exportTile(Icons.picture_as_pdf_rounded, "Save as PDF", Colors.red, () { Navigator.pop(ctx); _generateAndPrintPDF(); }), const SizedBox(height: 12), _exportTile(Icons.table_chart_rounded, "Save as Excel", Colors.green, () { Navigator.pop(ctx); _generateAndSaveExcel(); }), const SizedBox(height: 25)])));
  }

  Widget _exportTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)), const SizedBox(width: 15), Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)), const Spacer(), const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16)])));
  }
}

// 1. INVENTORY TAB (STOCK) - FILTERED BY UPDATED_AT RANGE
class _InventoryReportTab extends StatelessWidget {
  final FirebaseFirestore db;
  final Timestamp? start;
  final Timestamp? end;

  const _InventoryReportTab({required this.db, this.start, this.end});

  @override
  Widget build(BuildContext context) {
    Query query = db.collection('products');
    if (start != null) query = query.where('updatedAt', isGreaterThanOrEqualTo: start);
    if (end != null) query = query.where('updatedAt', isLessThanOrEqualTo: end);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No stock activity in this period.", style: TextStyle(color: Colors.grey)));

        double totalValue = 0;
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          double p = double.tryParse(data['price']?.toString() ?? '0') ?? 0;
          int s = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
          totalValue += (p * s);
        }
        return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), physics: const BouncingScrollPhysics(), children: [
          _buildPremiumStatCard("Stock Value (Active)", "RM ${totalValue.toStringAsFixed(2)}", Icons.account_balance_wallet_outlined, const Color(0xFF233E99)),
          const SizedBox(height: 30),
          const Text("Active Stock by Category", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 15),
          _buildCleanBarChart(docs),
          const SizedBox(height: 30),
          const Text("Restock Needed", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.redAccent)),
          const SizedBox(height: 15),
          if (docs.where((d) => (int.tryParse((d.data() as Map<String, dynamic>)['currentStock'].toString()) ?? 0) <= 10).isEmpty) _buildEmptyAlert() else ...docs.where((d) => (int.tryParse((d.data() as Map<String, dynamic>)['currentStock'].toString()) ?? 0) <= 10).map((d) {
            final data = d.data() as Map<String, dynamic>;
            return _buildModernAlertTile(data['productName'] ?? 'Item', "${data['currentStock']} units left", Icons.warning_amber_rounded, Colors.red);
          })]);
      },
    );
  }
  Widget _buildEmptyAlert() { return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(20)), child: const Center(child: Text("All stock levels are healthy! ✅", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))); }
  Widget _buildPremiumStatCard(String title, String val, IconData icon, Color color) { return Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: Colors.white60, size: 18), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600))]), const SizedBox(height: 12), Text(val, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5))])); }

  Widget _buildCleanBarChart(List<QueryDocumentSnapshot> docs) {
    Map<String, double> catData = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      String cat = data['category'] ?? 'Others';
      int s = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
      catData[cat] = (catData[cat] ?? 0) + s.toDouble();
    }

    return Container(height: 260, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)]), child: BarChart(BarChartData(maxY: catData.values.isEmpty ? 10 : catData.values.reduce((a, b) => a > b ? a : b) * 1.3, barGroups: catData.entries.map((e) => BarChartGroupData(x: catData.keys.toList().indexOf(e.key), barRods: [BarChartRodData(toY: e.value, color: const Color(0xFF233E99), width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))])).toList(), titlesData: FlTitlesData(topTitles: const AxisTitles(), rightTitles: const AxisTitles(), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) { if (v.toInt() >= catData.length) return const SizedBox(); return Padding(padding: const EdgeInsets.only(top: 10), child: Text(catData.keys.elementAt(v.toInt()).substring(0, 3).toUpperCase(), style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w900))); })), leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: Colors.grey.shade400))))), gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)), borderData: FlBorderData(show: false))));
  }

  Widget _buildModernAlertTile(String name, String subtitle, IconData icon, Color color) { return Container(margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: color.withOpacity(0.08)), boxShadow: [BoxShadow(color: color.withOpacity(0.02), blurRadius: 10)]), child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1A1C1E))), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))])), const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14)])); }
}

// 2. FORECAST TAB (FILTERED CHART BY DATE)
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.insights_rounded, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 15),
                const Text("Not enough data to show trends.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                const Text("Try selecting 'This Year' or run Forecast.", style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          );
        }

        List<FlSpot> spots = [];
        double maxDemand = 0;
        final chartDocs = docs; // Use ALL filtered docs for chart

        for (int i = 0; i < chartDocs.length; i++) {
          final data = chartDocs[i].data() as Map<String, dynamic>;
          double val = double.tryParse(data['predictedDemand']?.toString() ?? '0') ?? 0;
          if (val > maxDemand) maxDemand = val;
          spots.add(FlSpot(i.toDouble(), val));
        }

        return ListView(padding: const EdgeInsets.fromLTRB(20, 25, 20, 100), physics: const BouncingScrollPhysics(), children: [
          _buildHeader("Sales Forecast Trend"),
          const SizedBox(height: 20),
          _buildLineChart(spots, maxDemand, chartDocs), // Pass docs to get dates
          const SizedBox(height: 35),
          _buildHeader("Expected Sales List"),
          const SizedBox(height: 15),
          ...docs.take(10).map((d) {
            final data = d.data() as Map<String, dynamic>;
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
    return Container(height: 300, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))]), child: LineChart(LineChartData(minX: 0, maxX: (spots.length - 1).toDouble(), minY: 0, maxY: maxY * 1.2, lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: Colors.purpleAccent, barWidth: 4, isStrokeCapRound: true, dotData: FlDotData(show: true), belowBarData: BarAreaData(show: true, color: Colors.purpleAccent.withOpacity(0.1)))], titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: (docs.length / 5).ceil().toDouble(), getTitlesWidget: (value, meta) {
          int index = value.toInt();
          if (index >= 0 && index < docs.length) {
            final data = docs[index].data() as Map<String, dynamic>;
            if (data['forecastDate'] is Timestamp) {
              return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(DateFormat('d/M').format((data['forecastDate'] as Timestamp).toDate()), style: const TextStyle(fontSize: 10, color: Colors.grey)));
            }
          }
          return const SizedBox();
        })),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey))))), gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)), borderData: FlBorderData(show: false))));
  }

  Widget _buildForecastTile(String date, String productName, String demand) { return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.trending_up_rounded, color: Colors.purple, size: 20)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(productName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 2), Text("Target Date: $date", style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold))])), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(demand, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.purple)), const Text("units", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))])])); }
}

// 3. RISK TAB (UNCHANGED)
class _RiskReportTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _RiskReportTab({required this.db});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('risk_analysis').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return Center(child: Text("No health issues detected.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));
        final docs = snapshot.data!.docs;
        return ListView(padding: const EdgeInsets.fromLTRB(20, 25, 20, 100), physics: const BouncingScrollPhysics(), children: [_buildRiskHeader(docs.length), const SizedBox(height: 30), ...docs.map((d) { final data = d.data() as Map<String, dynamic>; return _buildRiskTile(data['ProductName'] ?? 'Unknown', "Expires in ${data['DaysToExpiry'] ?? 0} days", data['RiskLevel'] ?? 'Low'); })]);
      },
    );
  }
  Widget _buildRiskHeader(int count) { return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFFD32F2F), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: const Color(0xFFD32F2F).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]), child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 28)), const SizedBox(width: 15), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Items at Risk", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)), Text("$count Items", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))])])); }
  Widget _buildRiskTile(String productName, String subtitle, String probability) { Color riskColor = Colors.green; String prob = probability.toLowerCase(); if (prob.contains('high')) riskColor = const Color(0xFFD32F2F); else if (prob.contains('medium')) riskColor = Colors.orange; return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: riskColor.withOpacity(0.2), width: 1), boxShadow: [BoxShadow(color: riskColor.withOpacity(0.05), blurRadius: 10)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: riskColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(probability.toUpperCase(), style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.w900))), const Spacer(), Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey[400])]), const SizedBox(height: 10), Text(productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))), const SizedBox(height: 6), Row(children: [Icon(Icons.warning_amber_rounded, size: 14, color: riskColor), const SizedBox(width: 5), Expanded(child: Text(subtitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: riskColor)))])])); }
}

// 4. SALES TAB (FILTERED BY DATE RANGE)
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

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: [
            Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00796B), Color(0xFF004D40)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: const Color(0xFF004D40).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Total Sales Revenue", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(height: 8), const Text("RM ****", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text("${docs.length} Transactions", style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600))])
            ),

            const SizedBox(height: 30),
            const Text("Recent Transactions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
            const SizedBox(height: 15),

            ...docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              String dateStr = 'Unknown';
              if (data['saleDate'] != null) { dateStr = DateFormat('dd MMM, HH:mm').format((data['saleDate'] as Timestamp).toDate()); }

              String productName = data['snapshotName'] ?? 'Unknown Item';
              int quantity = int.tryParse(data['quantitySold'].toString()) ?? 0;

              return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("Qty: $quantity unit", style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(productName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1C1E)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    ])),
                    const Text("RM ****", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF00796B)))
                  ])
              );
            })
          ],
        );
      },
    );
  }
}