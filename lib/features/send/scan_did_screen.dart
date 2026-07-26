import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/design/tokens.dart';
import '../../core/haptics.dart';
import '../../core/ui/button.dart';
import '../../data/payment_request.dart';

/// Extract an Omnia DID from a scanned QR payload.
///
/// Accepts a bare `did:omnia:<hex>` string or a payload that contains one
/// (e.g. a URI like `omnia:did:omnia:...` or with surrounding whitespace).
/// DID id lengths vary by origin — self-custody wallets derive 32 hex chars,
/// web/Supabase accounts get 8 — so any 8–64 hex id is accepted. Returns the
/// normalized `did:omnia:...` string, or `null` if the payload doesn't
/// contain a well-formed Omnia DID.
///
/// Kept as a pure top-level function so it can be unit-tested without a camera.
String? parseScannedDid(String? raw) {
  if (raw == null) return null;
  final match = RegExp(
    r'did:omnia:[0-9a-fA-F]{8,64}',
    caseSensitive: false,
  ).firstMatch(raw.trim());
  return match?.group(0)?.toLowerCase();
}

/// Full-screen camera view that scans a QR code and pops with the recognized
/// [PaymentRequest] (DID + optional requested amount). Returns `null` if the
/// user backs out.
///
/// Chrome is drawn over the camera feed with no opaque surfaces: the viewfinder
/// is a corner-bracket cutout in a dimmed scrim, so the frame reads as a target
/// rather than as a box sitting on top of the picture.
class ScanDidScreen extends StatefulWidget {
  const ScanDidScreen({super.key});

  @override
  State<ScanDidScreen> createState() => _ScanDidScreenState();
}

class _ScanDidScreenState extends State<ScanDidScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _torchOn = false;

  // Guard so we only pop once even if several frames decode the same code.
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final request = PaymentRequest.parse(barcode.rawValue);
      if (request != null) {
        _handled = true;
        // The haptic *is* the confirmation — the screen is about to leave, so
        // there is no time for a visual one to register.
        Haptics.success();
        Navigator.of(context).pop(request);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewfinder = MediaQuery.sizeOf(context).width * 0.68;

    return Scaffold(
      backgroundColor: OmniaPalette.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Dim everything except the viewfinder.
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _ScrimPainter(size: viewfinder),
            ),
          ),
          IgnorePointer(
            child: SizedBox(
              width: viewfinder,
              height: viewfinder,
              child: CustomPaint(painter: _BracketPainter()),
            ),
          ),

          // Top bar: close + torch, floating over the feed.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                child: Row(
                  children: [
                    OmniaIconButton(
                      icon: Iconsax.close_circle,
                      size: 24,
                      color: OmniaPalette.white,
                      background: OmniaPalette.black.withValues(alpha: 0.4),
                      tooltip: 'Close',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    OmniaIconButton(
                      icon: _torchOn ? Iconsax.flash_1 : Iconsax.flash_slash,
                      size: 22,
                      color: _torchOn ? OmniaPalette.black : OmniaPalette.white,
                      background: _torchOn
                          ? OmniaPalette.white
                          : OmniaPalette.black.withValues(alpha: 0.4),
                      tooltip: 'Toggle torch',
                      onTap: () {
                        Haptics.selection();
                        setState(() => _torchOn = !_torchOn);
                        _controller.toggleTorch();
                      },
                    ),
                    const SizedBox(width: Space.sm),
                    OmniaIconButton(
                      icon: Iconsax.refresh_copy,
                      size: 22,
                      color: OmniaPalette.white,
                      background: OmniaPalette.black.withValues(alpha: 0.4),
                      tooltip: 'Switch camera',
                      onTap: () {
                        Haptics.selection();
                        _controller.switchCamera();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: Space.xxl,
            right: Space.xxl,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: Space.x4l),
                child: Text(
                  'Point the camera at an Omnia DID QR code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: FontSizes.md,
                    fontWeight: Weights.medium,
                    color: OmniaPalette.white,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: OmniaPalette.black.withValues(alpha: 0.8),
                      ),
                    ],
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

/// Dims the whole frame except a rounded square in the middle.
class _ScrimPainter extends CustomPainter {
  _ScrimPainter({required this.size});

  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final hole = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: canvasSize.center(Offset.zero),
        width: size,
        height: size,
      ),
      const Radius.circular(Radii.xl),
    );

    // Even-odd on a combined path punches the viewfinder out of the scrim in
    // one draw, with no seams where two rectangles would meet.
    final path = Path()
      ..addRect(Offset.zero & canvasSize)
      ..addRRect(hole)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = OmniaPalette.black.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.size != size;
}

/// Four corner brackets — the classic scanner target.
class _BracketPainter extends CustomPainter {
  static const double _arm = 26;
  static const double _radius = Radii.xl;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = OmniaPalette.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    const r = _radius;

    final path = Path()
      // top-left
      ..moveTo(0, _arm + r)
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(_arm + r, 0)
      // top-right
      ..moveTo(w - _arm - r, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, _arm + r)
      // bottom-right
      ..moveTo(w, h - _arm - r)
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
      ..lineTo(w - _arm - r, h)
      // bottom-left
      ..moveTo(_arm + r, h)
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
      ..lineTo(0, h - _arm - r);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BracketPainter oldDelegate) => false;
}
