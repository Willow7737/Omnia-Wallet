import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/haptics.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/ui/press.dart';
import '../../core/ui/sheet.dart';

/// A tappable image in the feed — a post's picture, or one attached to a
/// reply — that opens full screen.
///
/// The thumbnail and the full-screen image share a [Hero] tag, so the picture
/// grows out of its place in the thread rather than a new screen sliding over
/// it. That continuity is what tells the reader they are looking at the same
/// image, and it is why the tag has to be unique per piece of content.
class MediaThumb extends StatelessWidget {
  const MediaThumb({
    super.key,
    required this.url,
    required this.heroTag,
    this.maxHeight = 300,
    this.caption,
  });

  final String url;
  final String heroTag;
  final double maxHeight;

  /// Shown under the image full screen — the post title, usually.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;

    return Semantics(
      button: true,
      label: 'Open image',
      child: GestureDetector(
        onTap: () {
          Haptics.selection();
          Navigator.of(context, rootNavigator: true).push(
            MediaViewer.route(url: url, heroTag: heroTag, caption: caption),
          );
        },
        child: ClipRRect(
          borderRadius: Radii.rMd,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: Radii.rMd,
              border: Border.all(color: o.borderLow),
            ),
            constraints: BoxConstraints(maxHeight: maxHeight),
            width: double.infinity,
            child: Hero(
              tag: heroTag,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 180,
                    color: o.bg50,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: o.textLow,
                        value: progress.expectedTotalBytes == null
                            ? null
                            : progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: o.bg50,
                  alignment: Alignment.center,
                  child: Icon(Iconsax.gallery_slash_copy, color: o.textLow),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen image: pinch and double-tap to zoom, drag down to dismiss.
///
/// Drag-to-dismiss is the gesture people reach for first in every photo
/// viewer they already use, and it is the reason this is a route rather than
/// a dialog — the backdrop has to fade with the drag, which needs a
/// transparent page under the reader's finger.
class MediaViewer extends StatefulWidget {
  const MediaViewer({
    super.key,
    required this.url,
    required this.heroTag,
    this.caption,
  });

  final String url;
  final String heroTag;
  final String? caption;

  static Route<void> route({
    required String url,
    required String heroTag,
    String? caption,
  }) =>
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: null,
        transitionDuration: Motion.normal,
        reverseTransitionDuration: Motion.fast,
        pageBuilder: (_, __, ___) =>
            MediaViewer(url: url, heroTag: heroTag, caption: caption),
        // The Hero does the moving; a slide underneath it would fight the
        // flight path. Only the chrome fades.
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer>
    with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late final AnimationController _reset = AnimationController(
    vsync: this,
    duration: Motion.normal,
  );
  Animation<Matrix4>? _resetAnimation;

  /// How far the image has been dragged toward dismissal.
  double _dragY = 0;

  /// True while zoomed in, which is when the drag gesture must yield to
  /// panning — otherwise the viewer dismisses itself every time you move
  /// around a zoomed photo.
  bool _zoomed = false;

  /// Chrome (close button, caption) hides on a tap, the way every photo
  /// viewer does it, so the image can be looked at unobstructed.
  bool _chrome = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final zoomed = _controller.value.getMaxScaleOnAxis() > 1.01;
      if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
    });
    _reset.addListener(() {
      final value = _resetAnimation?.value;
      if (value != null) _controller.value = value;
    });
  }

  @override
  void dispose() {
    _reset.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(Matrix4 target) {
    _resetAnimation = Matrix4Tween(begin: _controller.value, end: target)
        .animate(CurvedAnimation(parent: _reset, curve: Curves.easeOutCubic));
    _reset.forward(from: 0);
  }

  void _doubleTap(TapDownDetails details) {
    Haptics.selection();
    if (_zoomed) {
      _animateTo(Matrix4.identity());
      return;
    }
    // Zoom about the point that was tapped, so the detail under the finger is
    // the detail that ends up centred.
    const scale = 2.5;
    final p = details.localPosition;
    _animateTo(
      Matrix4.identity()
        ..translateByDouble(-p.dx * (scale - 1), -p.dy * (scale - 1), 0, 1)
        ..scaleByDouble(scale, scale, scale, 1),
    );
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (_zoomed) return;
    setState(() => _dragY += details.delta.dy);
  }

  void _dragEnd(DragEndDetails details) {
    if (_zoomed) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_dragY.abs() > 120 || velocity > 700) {
      Haptics.tick();
      Navigator.of(context).pop();
      return;
    }
    setState(() => _dragY = 0);
  }

  Future<void> _copyLink() async {
    Haptics.selection();
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (mounted) showOmniaToast(context, message: 'Image link copied');
  }

  @override
  Widget build(BuildContext context) {
    // The backdrop thins as the image is dragged away, so the page behind
    // becomes visible before the route actually pops.
    final progress = (_dragY.abs() / 300).clamp(0.0, 1.0);
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 1 - progress * 0.7),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _chrome = !_chrome),
              onDoubleTapDown: _doubleTap,
              // The handler has to exist for onDoubleTapDown to fire.
              onDoubleTap: () {},
              onVerticalDragUpdate: _dragUpdate,
              onVerticalDragEnd: _dragEnd,
              child: Transform.translate(
                offset: Offset(0, _dragY),
                child: Transform.scale(
                  scale: 1 - progress * 0.15,
                  child: InteractiveViewer(
                    transformationController: _controller,
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                      child: Hero(
                        tag: widget.heroTag,
                        child: Image.network(
                          widget.url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, p) => p == null
                              ? child
                              : const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: OmniaPalette.white,
                                    ),
                                  ),
                                ),
                          errorBuilder: (_, __, ___) => const Icon(
                            Iconsax.gallery_slash_copy,
                            color: OmniaPalette.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Chrome. Ignores pointers while hidden so a tap to bring it back
          // is not swallowed by an invisible button.
          IgnorePointer(
            ignoring: !_chrome,
            child: AnimatedOpacity(
              opacity: _chrome ? 1 : 0,
              duration: Motion.fast,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      top: media.padding.top + Space.sm,
                      left: Space.sm,
                      right: Space.sm,
                    ),
                    child: Row(
                      children: [
                        _GlassButton(
                          icon: Iconsax.arrow_left_2_copy,
                          tooltip: 'Close',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        _GlassButton(
                          icon: Iconsax.link_copy,
                          tooltip: 'Copy image link',
                          onTap: _copyLink,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (widget.caption case final caption?
                      when caption.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        Space.lg,
                        Space.lg,
                        Space.lg,
                        Space.lg + media.padding.bottom,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                      child: Text(
                        caption,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: FontSizes.sm,
                          height: LineHeights.snug,
                          color: OmniaPalette.white,
                        ),
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
}

/// A round control that stays legible over any photo.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      feel: PressFeel.subtle,
      semanticLabel: tooltip,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: OmniaPalette.white),
      ),
    );
  }
}
