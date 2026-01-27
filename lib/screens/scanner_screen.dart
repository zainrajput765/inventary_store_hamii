import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  @override
  Widget build(BuildContext context) {
    // 1. Adjusted Scan Window Size (Wider and shorter for Barcodes)
    final double scanWindowWidth = MediaQuery.of(context).size.width * 0.8; // 80% of screen width
    final double scanWindowHeight = 120;

    // Calculate center properly
    final double centerX = MediaQuery.of(context).size.width / 2;
    final double centerY = MediaQuery.of(context).size.height / 2;

    final Rect scanWindow = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: scanWindowWidth,
      height: scanWindowHeight,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Align Barcode in Box"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            scanWindow: scanWindow,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  controller.stop();
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),

          // 2. Overlay (Darkens background)
          CustomPaint(
            painter: ScannerOverlay(scanWindow: scanWindow),
            child: Container(),
          ),

          // 3. Green Border (Visual Guide)
          Positioned(
            left: (MediaQuery.of(context).size.width - scanWindowWidth) / 2,
            top: (MediaQuery.of(context).size.height - scanWindowHeight) / 2, // Vertically centered
            child: Container(
              width: scanWindowWidth,
              height: scanWindowHeight,
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 3),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)
                  ]
              ),
            ),
          ),

          // 4. Flashlight Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(50.0),
              child: ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, state, child) {
                  bool isTorchOn = state.torchState == TorchState.on;
                  return IconButton(
                    color: Colors.white,
                    icon: Icon(isTorchOn ? Icons.flash_on : Icons.flash_off, size: 40, color: isTorchOn ? Colors.yellow : Colors.white),
                    onPressed: () => controller.toggleTorch(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlay extends CustomPainter {
  final Rect scanWindow;
  ScannerOverlay({required this.scanWindow});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addRRect(RRect.fromRectAndRadius(scanWindow, const Radius.circular(12)));

    final backgroundWithCutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(backgroundWithCutout, Paint()..color = Colors.black.withOpacity(0.6)); // 60% opacity
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}