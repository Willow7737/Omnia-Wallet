import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';

import '../theme.dart';

/// A deterministic identicon generated from any seed (a DID) — a unique little
/// avatar per identity with no asset and no network round-trip.
///
/// The glyph is drawn from a two-tone gradient rather than one flat hue, so at
/// avatar size it reads as an image instead of as a QR fragment. Lightness is
/// pinned per theme, which keeps every identicon legible against the page
/// without letting the hash pick an unreadable colour.
class Identicon extends StatelessWidget {
  const Identicon({super.key, required this.seed, this.size = 64});

  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IdenticonPainter(
          seed: seed.isEmpty ? 'omnia' : seed,
          background: o.bg50,
          isDark: o.isDark,
        ),
      ),
    );
  }
}

class _IdenticonPainter extends CustomPainter {
  _IdenticonPainter({
    required this.seed,
    required this.background,
    required this.isDark,
  });

  final String seed;
  final Color background;
  final bool isDark;

  static const int _grid = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final hash = crypto.sha256.convert(seed.codeUnits).bytes;
    final Uint8List bytes = Uint8List.fromList(hash);

    // Hue from the hash; saturation and lightness fixed so the result is
    // always readable on the current theme rather than occasionally muddy.
    final hue = ((bytes[0] << 8 | bytes[1]) % 360).toDouble();
    final light = isDark ? 0.62 : 0.48;
    final from = HSLColor.fromAHSL(1, hue, 0.62, light).toColor();
    final to =
        HSLColor.fromAHSL(1, (hue + 42) % 360, 0.62, light - 0.08).toColor();

    final rect = Offset.zero & size;
    canvas.clipRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.24)),
    );
    canvas.drawRect(rect, Paint()..color = background);

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [from, to],
      ).createShader(rect);

    // A 5x5 grid mirrored horizontally, so it reads as a symmetric glyph.
    final cell = size.width / _grid;
    for (var x = 0; x < (_grid / 2).ceil(); x++) {
      for (var y = 0; y < _grid; y++) {
        final idx = x * _grid + y;
        if ((bytes[idx % bytes.length] & 0x01) != 1) continue;
        final mirror = _grid - 1 - x;
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
        canvas.drawRect(
          Rect.fromLTWH(mirror * cell, y * cell, cell, cell),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_IdenticonPainter old) =>
      old.seed != seed || old.background != background || old.isDark != isDark;
}
