import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../event/data/repositories/event_repository.dart';

class QRScannerPage extends StatefulWidget {
  final String eventId;

  const QRScannerPage({super.key, required this.eventId});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final _repo = GetIt.instance<EventRepository>();
  final MobileScannerController _scannerController = MobileScannerController();

  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final ticketId = barcodes.first.rawValue;
      if (ticketId != null && ticketId.isNotEmpty) {
        setState(() => _isProcessing = true);
        _scannerController.stop();

        try {
          await _repo.scanAttendance(
            eventId: widget.eventId,
            ticketId: ticketId,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Check-in successful!'),
                backgroundColor: Color(0xFF10B981),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString()),
                backgroundColor: AppTheme.error,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } finally {
          if (mounted) {
            // Wait briefly before resuming to avoid accidental double-scans immediately
            await Future.delayed(const Duration(seconds: 2));
            setState(() => _isProcessing = false);
            _scannerController.start();
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Scan Ticket',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Text(
                  'Error initializing camera:\n${error.errorDetails?.message ?? "Unknown"}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
          // Scanner Overlay
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: AppTheme.primary,
                borderRadius: 16,
                borderLength: 40,
                borderWidth: 8,
                cutOutSize: MediaQuery.of(context).size.width * 0.75,
              ),
            ),
          ),
          // Status indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primary),
                    SizedBox(height: 16),
                    Text(
                      'Verifying ticket...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Instructions text
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48.0),
                child: Text(
                  'Posisikan QR Code di dalam frame',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom shape to draw a frame over the camera
class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape({
    this.borderColor = AppTheme.primary,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 60),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10.0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final cutoutRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final cutOutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(cutoutRect, Radius.circular(borderRadius)),
      );

    final backgroundPath = Path()
      ..addRect(rect)
      ..addPath(cutOutPath, Offset.zero)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(backgroundPath, backgroundPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path();

    // Top left corner
    path.moveTo(cutoutRect.left, cutoutRect.top + borderLength);
    path.lineTo(cutoutRect.left, cutoutRect.top + borderRadius);
    path.arcToPoint(
      Offset(cutoutRect.left + borderRadius, cutoutRect.top),
      radius: Radius.circular(borderRadius),
    );
    path.lineTo(cutoutRect.left + borderLength, cutoutRect.top);

    // Top right corner
    path.moveTo(cutoutRect.right - borderLength, cutoutRect.top);
    path.lineTo(cutoutRect.right - borderRadius, cutoutRect.top);
    path.arcToPoint(
      Offset(cutoutRect.right, cutoutRect.top + borderRadius),
      radius: Radius.circular(borderRadius),
    );
    path.lineTo(cutoutRect.right, cutoutRect.top + borderLength);

    // Bottom right corner
    path.moveTo(cutoutRect.right, cutoutRect.bottom - borderLength);
    path.lineTo(cutoutRect.right, cutoutRect.bottom - borderRadius);
    path.arcToPoint(
      Offset(cutoutRect.right - borderRadius, cutoutRect.bottom),
      radius: Radius.circular(borderRadius),
    );
    path.lineTo(cutoutRect.right - borderLength, cutoutRect.bottom);

    // Bottom left corner
    path.moveTo(cutoutRect.left + borderLength, cutoutRect.bottom);
    path.lineTo(cutoutRect.left + borderRadius, cutoutRect.bottom);
    path.arcToPoint(
      Offset(cutoutRect.left, cutoutRect.bottom - borderRadius),
      radius: Radius.circular(borderRadius),
    );
    path.lineTo(cutoutRect.left, cutoutRect.bottom - borderLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      cutOutSize: cutOutSize * t,
    );
  }
}
