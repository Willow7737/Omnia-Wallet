import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme.dart';
import '../../data/news.dart';

/// Renders a post as a shareable picture.
///
/// This paints straight onto a canvas rather than screenshotting the widget on
/// screen, for three reasons that all bite the screenshot approach: the card in
/// the feed is clipped by the viewport, it carries interactive chrome (the
/// action row, the overflow button) that has no business in a shared image, and
/// capturing a live `RepaintBoundary` needs the widget to be mounted and
/// painted — which it is not, when the share is triggered from a menu that has
/// already covered it.
///
/// Painting it explicitly also makes the whole thing a pure function of a
/// [NewsPost], so it can be tested without a screen.
class PostShareCard {
  PostShareCard._();

  /// Logical width of the layout. The bitmap comes out at this times [scale].
  static const double width = 420;

  /// 3× so the picture stays crisp when a messaging app re-encodes it.
  static const double scale = 3;

  static const double _pad = 28;
  static const double _avatar = 44;

  /// The body is clamped — a share card is an invitation to read the post,
  /// not a replacement for it.
  static const int _bodyLines = 8;

  /// Paint [post] and encode it as PNG bytes.
  ///
  /// [image] is the post's picture, already decoded, or null. [palette] fixes
  /// the colours so the card does not change identity with the reader's theme.
  static Future<Uint8List> render({
    required NewsPost post,
    required String link,
    ui.Image? image,
    OmniaColors? palette,
  }) async {
    // Light by default whatever the reader's theme is: a shared picture lands
    // in someone else's app, and a dark card in a light timeline reads as a
    // screenshot of a bug.
    const light = OmniaColors(palette: OmniaPalette.defaults, isDark: false);
    final c = palette ?? light;

    final mark = await _loadMark(c);
    final recorder = ui.PictureRecorder();
    // Height is not known until the text is laid out, so measure first with a
    // throwaway canvas-free pass, then paint for real.
    final height = _paint(null, post, link, image, mark, c);
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width * scale, height * scale),
    );
    canvas.scale(scale);
    _paint(canvas, post, link, image, mark, c);
    mark?.picture.dispose();

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(
      (width * scale).round(),
      (height * scale).round(),
    );
    picture.dispose();
    try {
      final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('The post image could not be encoded.');
      }
      return data.buffer.asUint8List();
    } finally {
      rendered.dispose();
    }
  }

  /// Lays the card out, painting onto [canvas] when one is given. Returns the
  /// height the content needs.
  ///
  /// Measure and paint share one body so the two can never disagree — the
  /// classic failure of this kind of code is a card whose text runs off the
  /// bottom because the measuring pass forgot a gap.
  /// The real Omnia mark, as a vector picture.
  ///
  /// The asset paints in `currentColor`, so the tint is supplied here the same
  /// way `BrandMark` supplies it on screen — otherwise it comes out as a
  /// black-on-black void. Returns null if the asset cannot be loaded, in which
  /// case the avatar falls back to a plain tinted disc; a share should not
  /// fail over a logo.
  static Future<PictureInfo?> _loadMark(OmniaColors c) async {
    try {
      return await vg.loadPicture(
        SvgAssetLoader(
          'assets/logo/omnia_mark.svg',
          theme: SvgTheme(currentColor: c.text),
        ),
        null,
      );
    } catch (_) {
      return null;
    }
  }

  static double _paint(
    ui.Canvas? canvas,
    NewsPost post,
    String link,
    ui.Image? image,
    PictureInfo? mark,
    OmniaColors c,
  ) {
    const contentWidth = width - _pad * 2;
    var y = _pad;

    void paintText(TextPainter tp, double x) {
      if (canvas != null) tp.paint(canvas, ui.Offset(x, y));
      y += tp.height;
    }

    // ---- Card background ----
    if (canvas != null) {
      canvas.drawPaint(ui.Paint()..color = c.bg);
    }

    // ---- Author row ----
    if (canvas != null) {
      final centre = ui.Offset(_pad + _avatar / 2, y + _avatar / 2);
      canvas
        ..drawCircle(centre, _avatar / 2, ui.Paint()..color = c.bg50)
        ..drawCircle(
          centre,
          _avatar / 2,
          ui.Paint()
            ..color = c.borderLow
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      // The actual Omnia mark, at the same proportion to its disc that the
      // feed uses (half the avatar). A hand-drawn approximation here read as
      // a stray "O" and did not look like the app at all.
      if (mark != null) {
        const glyph = _avatar / 2;
        final factor = glyph / mark.size.longestSide;
        canvas
          ..save()
          ..translate(
            centre.dx - mark.size.width * factor / 2,
            centre.dy - mark.size.height * factor / 2,
          )
          ..scale(factor)
          ..drawPicture(mark.picture)
          ..restore();
      }
    }

    final author = _text(
      post.author,
      size: 16,
      weight: FontWeight.w600,
      color: c.text,
      maxWidth: contentWidth - _avatar - 14,
    );
    final when = _text(
      _relative(post.createdAt),
      size: 13,
      color: c.textLow,
      maxWidth: contentWidth - _avatar - 14,
    );

    if (canvas != null) {
      final left = _pad + _avatar + 14;
      final block = author.height + when.height;
      final top = y + (_avatar - block) / 2;
      author.paint(canvas, ui.Offset(left, top));
      when.paint(canvas, ui.Offset(left, top + author.height));
    }
    y += math.max(_avatar, author.height + when.height) + 22;

    // ---- Title ----
    if (post.title.isNotEmpty) {
      paintText(
        _text(
          post.title,
          size: 24,
          weight: FontWeight.w700,
          height: 1.25,
          color: c.text,
          maxWidth: contentWidth,
        ),
        _pad,
      );
      y += 10;
    }

    // ---- Body ----
    if (post.body.isNotEmpty) {
      paintText(
        _text(
          post.body,
          size: 15,
          height: 1.45,
          color: c.textHigh,
          maxWidth: contentWidth,
          maxLines: _bodyLines,
        ),
        _pad,
      );
      y += 18;
    }

    // ---- Picture ----
    if (image != null) {
      final ratio = image.height / image.width;
      final h = math.min(contentWidth * ratio, 300.0);
      final rect = ui.Rect.fromLTWH(_pad, y, contentWidth, h);
      if (canvas != null) {
        final rrect = ui.RRect.fromRectAndRadius(
          rect,
          const ui.Radius.circular(12),
        );
        canvas
          ..save()
          ..clipRRect(rrect);
        // BoxFit.cover, computed by hand — paintImage needs a full painting
        // context, and this is a bare canvas.
        final src = _coverSource(image, contentWidth / h);
        canvas
          ..drawImageRect(image, src, rect, ui.Paint())
          ..restore()
          ..drawRRect(
            rrect,
            ui.Paint()
              ..color = c.borderLow
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = 1,
          );
      }
      y += h + 18;
    }

    // ---- Tags ----
    if (post.tags.isNotEmpty) {
      paintText(
        _text(
          post.tags.map((t) => '#$t').join('  '),
          size: 13,
          weight: FontWeight.w500,
          color: c.link,
          maxWidth: contentWidth,
          maxLines: 2,
        ),
        _pad,
      );
      y += 20;
    } else {
      y += 4;
    }

    // ---- Footer: the link, which is the point of sharing at all ----
    if (canvas != null) {
      canvas.drawLine(
        ui.Offset(_pad, y),
        ui.Offset(width - _pad, y),
        ui.Paint()
          ..color = c.borderLow
          ..strokeWidth = 1,
      );
    }
    y += 16;

    paintText(
      _text(
        link,
        size: 13,
        weight: FontWeight.w500,
        color: c.textLow,
        maxWidth: contentWidth,
        maxLines: 1,
      ),
      _pad,
    );

    return y + _pad;
  }

  /// The source rectangle that fills a box of aspect [targetAspect] (w/h)
  /// without distorting the image — the arithmetic `BoxFit.cover` does.
  static ui.Rect _coverSource(ui.Image image, double targetAspect) {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final imageAspect = w / h;
    if (imageAspect > targetAspect) {
      // Too wide: trim the sides.
      final keep = h * targetAspect;
      return ui.Rect.fromLTWH((w - keep) / 2, 0, keep, h);
    }
    // Too tall: trim top and bottom.
    final keep = w / targetAspect;
    return ui.Rect.fromLTWH(0, (h - keep) / 2, w, keep);
  }

  static TextPainter _text(
    String value, {
    required double size,
    required Color color,
    required double maxWidth,
    FontWeight weight = FontWeight.w400,
    double height = 1.3,
    int? maxLines,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: kMonoFallback,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '…',
    )..layout(maxWidth: maxWidth);
    return tp;
  }

  /// A compact relative time, duplicated from `Fmt` so this file stays free of
  /// anything that needs a running app.
  static String _relative(DateTime when) {
    final d = DateTime.now().difference(when);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${d.inDays ~/ 7}w ago';
  }
}
