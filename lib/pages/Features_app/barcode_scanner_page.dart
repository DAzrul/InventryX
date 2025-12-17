import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage>
    with SingleTickerProviderStateMixin {
  final MobileScannerController cameraController = MobileScannerController();
  bool _scanned = false;

  late AnimationController _lineController;

  @override
  void initState() {
    super.initState();
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _lineController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          /// 📷 CAMERA
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (!_scanned && barcodes.isNotEmpty) {
                _scanned = true;
                final code = barcodes.first.rawValue ?? '';
                if (code.isNotEmpty) {
                  Navigator.pop(context, code);
                }
              }
            },
          ),

          /// 🟦 SCAN FRAME
          Container(
            width: 260,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),

          /// 🔴 ANIMATED SCAN LINE
          Positioned(
            child: SizedBox(
              width: 260,
              height: 160,
              child: AnimatedBuilder(
                animation: _lineController,
                builder: (context, child) {
                  return Align(
                    alignment:
                    Alignment(0, _lineController.value * 2 - 1),
                    child: Container(
                      height: 2,
                      width: double.infinity,
                      color: Colors.redAccent,
                    ),
                  );
                },
              ),
            ),
          ),

          /// ℹ️ BOTTOM INFO CARD
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: const [
                  Icon(Icons.qr_code_scanner,
                      color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Align the barcode inside the frame to scan",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
