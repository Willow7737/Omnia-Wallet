import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../core/haptics.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/ui/press.dart';

/// Whether a media URL points at something to play rather than something to
/// look at.
///
/// Decided from the extension because the app writes these URLs itself, into
/// its own storage bucket, so the name is as trustworthy as a column would be
/// — and a column would mean a migration plus a backfill for the same answer.
/// The query string is stripped first: a signed URL carries `?token=…` after
/// the extension.
bool isVideoUrl(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  return const ['.mp4', '.mov', '.m4v', '.webm', '.mkv'].any(path.endsWith);
}

/// A video attached to a post or a reply.
///
/// Loads its first frame and waits. No autoplay: sound starting on its own
/// while someone is reading is the thing people turn autoplay off to escape,
/// and a wallet's feed is not a place anyone came to be surprised by audio.
///
/// Two gestures, deliberately unambiguous:
///
///  * **the play button** starts it here in the feed, for a look without
///    losing your place;
///  * **anywhere else on the picture** opens it full screen — the same thing
///    tapping a photo does, which is what anyone will try first.
///
/// The controls stay visible inline rather than fading out. Auto-hiding
/// chrome belongs where the picture is the point; in a feed it just means the
/// pause button is missing when you reach for it.
///
/// Full screen reuses *this* controller rather than making a second one, so
/// it opens at the frame you were on, returns to it, and can never end up
/// playing two soundtracks at once.
class VideoAttachment extends StatefulWidget {
  const VideoAttachment({
    super.key,
    required this.url,
    this.maxHeight = 420,
  });

  final String url;
  final double maxHeight;

  @override
  State<VideoAttachment> createState() => _VideoAttachmentState();
}

class _VideoAttachmentState extends State<VideoAttachment>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onTick);
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  /// Leaving the app must stop the sound. Coming back does not resume — that
  /// is the reader's call, not ours.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    Haptics.selection();
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    Haptics.selection();
    await Navigator.of(context, rootNavigator: true)
        .push(FullscreenVideo.route(controller));
  }

  void _toggleMute() {
    final controller = _controller;
    if (controller == null) return;
    Haptics.tick();
    controller.setVolume(controller.value.volume > 0 ? 0 : 1);
    setState(() {});
  }

  static String _clock(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final controller = _controller;

    if (_failed) {
      return _Frame(
        aspect: 16 / 9,
        maxHeight: widget.maxHeight,
        child: ColoredBox(
          color: o.bg50,
          child: Center(
            child: Icon(Iconsax.video_slash_copy, color: o.textLow),
          ),
        ),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return _Frame(
        aspect: 16 / 9,
        maxHeight: widget.maxHeight,
        child: ColoredBox(
          color: o.bg50,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    final value = controller.value;
    final playing = value.isPlaying;
    final muted = value.volume == 0;

    return _Frame(
      aspect: value.aspectRatio,
      maxHeight: widget.maxHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Tapping the picture opens it full screen — the same gesture a
        // photo answers to. The play button below takes precedence over this
        // because it is a child hit target, so it still plays in place.
        onTap: _openFullscreen,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: value.size.width,
                height: value.size.height,
                child: VideoPlayer(controller),
              ),
            ),

            // Controls stay up in the feed. See the class doc.
            RepaintBoundary(
              child: IgnorePointer(
                ignoring: false,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black54],
                        ),
                      ),
                    ),
                    Center(
                      child: Pressable(
                        onTap: _toggle,
                        feel: PressFeel.firm,
                        semanticLabel: playing ? 'Pause' : 'Play',
                        child: Container(
                          width: 54,
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            playing ? Iconsax.pause : Iconsax.play,
                            size: 24,
                            color: OmniaPalette.white,
                          ),
                        ),
                      ),
                    ),
                    // Discoverability for the tap-to-open gesture: without a
                    // visible affordance, "the picture is also a button" is
                    // something only some people ever find.
                    Positioned(
                      top: Space.sm,
                      right: Space.sm,
                      child: Pressable(
                        onTap: _openFullscreen,
                        feel: PressFeel.subtle,
                        semanticLabel: 'Open full screen',
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Iconsax.maximize_4_copy,
                            size: 15,
                            color: OmniaPalette.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: Space.md,
                      right: Space.md,
                      bottom: Space.sm,
                      child: Row(
                        children: [
                          Text(
                            '${_clock(value.position)} / '
                            '${_clock(value.duration)}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: FontSizes.xs,
                              color: OmniaPalette.white,
                              fontFeatures: kTabularFigures,
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: _Scrubber(controller: controller),
                          ),
                          const SizedBox(width: Space.sm),
                          Pressable(
                            onTap: _toggleMute,
                            feel: PressFeel.subtle,
                            semanticLabel: muted ? 'Unmute' : 'Mute',
                            child: Icon(
                              muted
                                  ? Iconsax.volume_slash_copy
                                  : Iconsax.volume_high_copy,
                              size: 17,
                              color: OmniaPalette.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The rounded, hairlined box every attachment sits in, sized by the video's
/// own aspect ratio but never taller than the room allowed.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.aspect,
    required this.maxHeight,
    required this.child,
  });

  final double aspect;
  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ClipRRect(
        borderRadius: Radii.rMd,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: Radii.rMd,
            border: Border.all(color: o.borderLow),
          ),
          child: AspectRatio(
            aspectRatio: aspect <= 0 ? 16 / 9 : aspect,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A drag-anywhere progress bar.
///
/// Deliberately not `VideoProgressIndicator`: that one is Material-styled and
/// only seeks on tap, and a 14-second clip needs to be scrubbable.
class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final total = value.duration.inMilliseconds;
    final progress =
        total == 0 ? 0.0 : (value.position.inMilliseconds / total).clamp(0, 1);

    void seekTo(double dx, double width) {
      if (total == 0 || width <= 0) return;
      controller.seekTo(
        Duration(milliseconds: ((dx / width).clamp(0, 1) * total).round()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seekTo(d.localPosition.dx, width),
          onHorizontalDragUpdate: (d) => seekTo(d.localPosition.dx, width),
          child: SizedBox(
            height: 20,
            child: Center(
              child: Stack(
                children: [
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: OmniaPalette.white.withValues(alpha: 0.35),
                      borderRadius: Radii.rFull,
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.toDouble(),
                    child: Container(
                      height: 3,
                      decoration: const BoxDecoration(
                        color: OmniaPalette.white,
                        borderRadius: Radii.rFull,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A video filling the screen, driven by the caller's controller.
///
/// It takes the controller rather than making one. A second controller on the
/// same URL would re-buffer from zero, start at the beginning instead of where
/// you were, and — for as long as both existed — play two soundtracks over
/// each other. Sharing it means opening and closing full screen is free and
/// the position simply carries.
///
/// Portrait is released while this is up. The app is locked to portrait, which
/// is right for a wallet and wrong for a 16:9 clip; the lock is restored on
/// the way out, in `dispose`, so a crash-free exit cannot leave the rest of
/// the app rotatable.
class FullscreenVideo extends StatefulWidget {
  const FullscreenVideo({super.key, required this.controller});

  final VideoPlayerController controller;

  static Route<void> route(VideoPlayerController controller) =>
      OverlayFadeRoute<void>(
        settings: const RouteSettings(name: '/video'),
        builder: (_) => FullscreenVideo(controller: controller),
      );

  @override
  State<FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<FullscreenVideo> {
  /// Chrome fades out here — unlike the feed, the picture is the point.
  bool _chrome = true;
  double _dragY = 0;

  VideoPlayerController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Arriving full screen is a request to watch it.
    if (!_c.value.isPlaying) _c.play();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onTick);
    // The controller belongs to the widget that opened this, so it is left
    // running — only the screen goes back to how it was.
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggle() {
    Haptics.selection();
    _c.value.isPlaying ? _c.pause() : _c.play();
    setState(() => _chrome = true);
  }

  void _dragUpdate(DragUpdateDetails d) => setState(() => _dragY += d.delta.dy);

  void _dragEnd(DragEndDetails d) {
    if (_dragY.abs() > 120 || (d.primaryVelocity ?? 0) > 700) {
      Haptics.tick();
      Navigator.of(context).pop();
      return;
    }
    setState(() => _dragY = 0);
  }

  static String _clock(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final value = _c.value;
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
              onVerticalDragUpdate: _dragUpdate,
              onVerticalDragEnd: _dragEnd,
              child: Transform.translate(
                offset: Offset(0, _dragY),
                child: Transform.scale(
                  scale: 1 - progress * 0.15,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio:
                          value.aspectRatio <= 0 ? 16 / 9 : value.aspectRatio,
                      child: VideoPlayer(_c),
                    ),
                  ),
                ),
              ),
            ),
          ),
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
                        _Glass(
                          icon: Iconsax.arrow_left_2_copy,
                          tooltip: 'Close',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        _Glass(
                          icon: value.volume > 0
                              ? Iconsax.volume_high_copy
                              : Iconsax.volume_slash_copy,
                          tooltip: value.volume > 0 ? 'Mute' : 'Unmute',
                          onTap: () {
                            Haptics.tick();
                            _c.setVolume(value.volume > 0 ? 0 : 1);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: Pressable(
                      onTap: _toggle,
                      feel: PressFeel.firm,
                      semanticLabel: value.isPlaying ? 'Pause' : 'Play',
                      child: Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          value.isPlaying ? Iconsax.pause : Iconsax.play,
                          size: 28,
                          color: OmniaPalette.white,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: EdgeInsets.only(
                      left: Space.lg,
                      right: Space.lg,
                      bottom: media.padding.bottom + Space.lg,
                    ),
                    child: Row(
                      children: [
                        Text(
                          _clock(value.position),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: FontSizes.sm,
                            color: OmniaPalette.white,
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(child: _Scrubber(controller: _c)),
                        const SizedBox(width: Space.md),
                        Text(
                          _clock(value.duration),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: FontSizes.sm,
                            color: OmniaPalette.white,
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                      ],
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

/// A round control that stays legible over any frame.
class _Glass extends StatelessWidget {
  const _Glass({
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
