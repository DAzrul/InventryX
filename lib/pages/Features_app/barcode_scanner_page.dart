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
    const frameWidth = 300.0;
    const frameHeight = 180.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          /// Camera
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

          /// Overlay
          Container(
            color: Colors.black.withOpacity(0.6),
          ),

          /// Transparent scan frame area
          Center(
            child: SizedBox(
              width: frameWidth,
              height: frameHeight,
              child: Stack(
                children: [
                  /// Transparent center
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),

                  /// Animated scan line
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _lineController,
                      builder: (context, child) {
                        return Align(
                          alignment: Alignment(0, _lineController.value * 2 - 1),
                          child: Container(
                            height: 3,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.redAccent.withOpacity(0),
                                  Colors.redAccent,
                                  Colors.redAccent.withOpacity(0)
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  /// Corner highlights
                  ..._buildCorners(),
                ],
              ),
            ),
          ),

          /// Hint Text
          Positioned(
            top: 100,
            child: const Text(
              "Align the barcode within the frame",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          /// Bottom info card
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: const [
                  Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Scanning will auto-detect the barcode",
                      style: TextStyle(color: Colors.white, fontSize: 14),
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

  List<Widget> _buildCorners() {
    const cornerSize = 20.0;
    const borderWidth = 4.0;
    const borderColor = Colors.redAccent;

    return [
      // Top-left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: borderColor, width: borderWidth),
              left: BorderSide(color: borderColor, width: borderWidth),
            ),
          ),
        ),
      ),
      // Top-right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: borderColor, width: borderWidth),
              right: BorderSide(color: borderColor, width: borderWidth),
            ),
          ),
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: borderColor, width: borderWidth),
              left: BorderSide(color: borderColor, width: borderWidth),
            ),
          ),
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: borderColor, width: borderWidth),
              right: BorderSide(color: borderColor, width: borderWidth),
            ),
          ),
        ),
      ),
    ];
  }
}
