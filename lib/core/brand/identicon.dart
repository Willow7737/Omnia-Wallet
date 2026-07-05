import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';

/// A deterministic, GitHub-style identicon generated from any seed (a DID).
/// A unique little "image" per identity — no asset or network needed.
class Identicon extends StatelessWidget {
  const Identicon({super.key, required this.seed, this.size = 64});

  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IdenticonPainter(
          seed: seed.isEmpty ? 'omnia' : seed,
          background: scheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}

class _IdenticonPainter extends CustomPainter {
  _IdenticonPainter({required this.seed, required this.background});

  final String seed;
  final Color background;

  static const int _grid = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final hash = crypto.sha256.convert(seed.codeUnits).bytes;
    final Uint8List bytes = Uint8List.fromList(hash);

    // Derive a pleasant, saturated colour from the hash hue.
    final hue = (bytes[0] << 8 | bytes[1]) % 360;
    final color = HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.5).toColor();

    final radius = size.width * 0.22;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.clipRRect(rrect);
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final cell = size.width / _grid;
    final paint = Paint()..color = color;

    // Fill a 5x5 grid, mirrored horizontally so it reads as a symmetric glyph.
    for (var x = 0; x < (_grid / 2).ceil(); x++) {
      for (var y = 0; y < _grid; y++) {
        final idx = x * _grid + y;
        final on = (bytes[idx % bytes.length] & 0x01) == 1;
        if (!on) continue;
        final mirror = _grid - 1 - x;
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
        canvas.drawRect(
            Rect.fromLTWH(mirror * cell, y * cell, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_IdenticonPainter old) =>
      old.seed != seed || old.background != background;
}
