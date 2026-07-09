import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
/// Omnia DID. Returns `null` if the user backs out.
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
      final did = parseScannedDid(barcode.rawValue);
      if (did != null) {
        _handled = true;
        Navigator.of(context).pop(did);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan recipient DID'),
        actions: [
          IconButton(
            tooltip: 'Toggle torch',
            icon: const Icon(Icons.flashlight_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Switch camera',
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Simple viewfinder overlay.
          IgnorePointer(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Text(
              'Point the camera at an Omnia DID QR code',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 6, color: Colors.black)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
