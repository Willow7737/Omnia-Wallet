import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// The Omnia bracket-"O" mark.
///
/// The asset paints in `currentColor`, so it is always tinted here rather than
/// relying on the file's own fill — that is what previously made it render as
/// a black-on-black void wherever the tint was forgotten.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.omnia.text;
    return SvgPicture.asset(
      'assets/logo/omnia_mark.svg',
      height: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      semanticsLabel: 'Omnia',
    );
  }
}

/// Mark + lowercase "omnia" wordmark, laid out horizontally — the Home
/// header's title.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.markSize = 22,
    this.fontSize = 22,
    this.color,
  });

  final double markSize;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.omnia.text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: markSize, color: tint),
        SizedBox(width: markSize * 0.36),
        Text(
          'omnia',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: fontSize,
            fontWeight: Weights.bold,
            letterSpacing: kTracking,
            height: 1.1,
            color: tint,
          ),
        ),
      ],
    );
  }
}

/// The soft halo behind the mark on the onboarding hero.
class BrandHalo extends StatelessWidget {
  const BrandHalo({super.key, this.size = 260, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.omnia.accent;
    return SvgPicture.asset(
      'assets/illustrations/hero_glow.svg',
      height: size,
      width: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

/// A third-party brand logo from `assets/brand_icons/`.
///
/// [tint] is for marks that are meant to take the theme's colour (GitHub's is
/// monochrome by design). Leave it null for marks whose colour *is* the brand
/// — Google's "G" must never be recoloured.
class BrandIcon extends StatelessWidget {
  const BrandIcon({
    super.key,
    required this.asset,
    this.size = 20,
    this.tint,
    this.label,
  });

  const BrandIcon.google({super.key, this.size = 20})
      : asset = 'assets/brand_icons/google_g.svg',
        tint = null,
        label = 'Google';

  const BrandIcon.github({super.key, this.size = 22, this.tint})
      : asset = 'assets/brand_icons/github_mark.svg',
        label = 'GitHub';

  final String asset;
  final double size;
  final Color? tint;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter:
          tint == null ? null : ColorFilter.mode(tint!, BlendMode.srcIn),
      semanticsLabel: label,
    );
  }
}
