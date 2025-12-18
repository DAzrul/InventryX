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

  static const double frameWidth = 300;
  static const double frameHeight = 180;

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
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Barcode Scanner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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

          /// CAMERA
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_scanned) return;

              final barcode = capture.barcodes.firstOrNull?.rawValue;
              if (barcode != null && barcode.isNotEmpty) {
                _scanned = true;
                Navigator.pop(context, barcode);
              }
            },
          ),

          /// DARK OVERLAY WITH CUT-OUT
          CustomPaint(
            size: Size.infinite,
            painter: ScannerOverlayPainter(
              frameWidth: frameWidth,
              frameHeight: frameHeight,
            ),
          ),

          /// SCAN FRAME
          Center(
            child: SizedBox(
              width: frameWidth,
              height: frameHeight,
              child: Stack(
                children: [

                  /// FRAME BORDER
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.9),
                        width: 1.5,
                      ),
                    ),
                  ),

                  /// SCAN LINE
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _lineController,
                      builder: (_, __) {
                        return Align(
                          alignment: Alignment(0, _lineController.value * 2 - 1),
                          child: Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.8),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                )
                              ],
                              gradient: const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.redAccent,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  /// CORNERS
                  ..._buildCorners(),
                ],
              ),
            ),
          ),

          /// TITLE & HINT
          Positioned(
            top: 110,
            child: Column(
              children: const [
                Text(
                  "Scan Barcode",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Align barcode inside the frame",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          /// BOTTOM INFO
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: const [
                  Icon(Icons.qr_code_scanner, color: Colors.white, size: 26),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Barcode will be detected automatically",
                      style: TextStyle(color: Colors.white70),
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

  /// FRAME CORNERS
  List<Widget> _buildCorners() {
    const double size = 22;
    const double width = 4;

    return [
      _corner(Alignment.topLeft, Border(
        top: BorderSide(color: Colors.redAccent, width: width),
        left: BorderSide(color: Colors.redAccent, width: width),
      )),
      _corner(Alignment.topRight, Border(
        top: BorderSide(color: Colors.redAccent, width: width),
        right: BorderSide(color: Colors.redAccent, width: width),
      )),
      _corner(Alignment.bottomLeft, Border(
        bottom: BorderSide(color: Colors.redAccent, width: width),
        left: BorderSide(color: Colors.redAccent, width: width),
      )),
      _corner(Alignment.bottomRight, Border(
        bottom: BorderSide(color: Colors.redAccent, width: width),
        right: BorderSide(color: Colors.redAccent, width: width),
      )),
    ].map((e) => Positioned.fill(child: e)).toList();
  }

  Widget _corner(Alignment align, Border border) {
    return Align(
      alignment: align,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(border: border),
      ),
    );
  }
}

/// OVERLAY PAINTER WITH CUT-OUT
class ScannerOverlayPainter extends CustomPainter {
  final double frameWidth;
  final double frameHeight;

  ScannerOverlayPainter({
    required this.frameWidth,
    required this.frameHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.65);

    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final holeRect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: frameWidth,
      height: frameHeight,
    );

    final path = Path()
      ..addRect(fullRect)
      ..addRRect(
        RRect.fromRectAndRadius(holeRect, const Radius.circular(14)),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
