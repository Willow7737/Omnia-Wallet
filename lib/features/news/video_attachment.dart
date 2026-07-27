import 'package:flutter/material.dart';
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

  /// Controls hide while playing and come back on a tap, so the picture is
  /// not permanently half-covered by chrome.
  bool _chrome = true;

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
      setState(() => _chrome = true);
    } else {
      controller.play();
      setState(() => _chrome = false);
    }
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
        onTap: playing ? () => setState(() => _chrome = !_chrome) : _toggle,
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

            // A scrim only under the chrome, so the picture is untouched once
            // the controls are gone.
            AnimatedOpacity(
              opacity: _chrome ? 1 : 0,
              duration: Motion.fast,
              child: IgnorePointer(
                ignoring: !_chrome,
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
