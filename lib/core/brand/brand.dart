import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Omnia bracket-"O" mark, tinted to a theme colour.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return SvgPicture.asset(
      'assets/logo/omnia_mark.svg',
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      semanticsLabel: 'Omnia',
    );
  }
}

/// Mark + lowercase "omnia" wordmark, laid out horizontally. Used in headers.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.markSize = 26,
    this.fontSize = 26,
    this.color,
  });

  final double markSize;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: markSize, color: c),
        SizedBox(width: markSize * 0.35),
        Text(
          'omnia',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: c,
          ),
        ),
      ],
    );
  }
}
