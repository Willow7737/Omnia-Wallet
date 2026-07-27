import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/reactions.dart';

/// Fetches like/dislike tallies for whatever content [child] is about to show.
///
/// Counts live in a single store shared by the feed, the post screen and the
/// reply thread, so *something* has to say which ids are on screen. Doing it
/// with a wrapper rather than inside each list means the fetch happens once
/// per set of ids, not once per rebuild, and the widget that renders a count
/// stays a plain consumer of the store.
class ReactionLoader extends ConsumerStatefulWidget {
  const ReactionLoader({
    super.key,
    required this.contentType,
    required this.ids,
    required this.child,
  });

  final String contentType;
  final List<String> ids;
  final Widget child;

  @override
  ConsumerState<ReactionLoader> createState() => _ReactionLoaderState();
}

class _ReactionLoaderState extends ConsumerState<ReactionLoader> {
  /// The ids already asked for, so a rebuild with the same content is free.
  List<String> _loaded = const [];

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(ReactionLoader old) {
    super.didUpdateWidget(old);
    _maybeLoad();
  }

  void _maybeLoad() {
    final ids = widget.ids;
    if (ids.isEmpty || _sameAs(ids)) return;
    _loaded = List.of(ids);
    // After the frame: loading publishes to a StateNotifier, and doing that
    // during build would rebuild a tree that is mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(reactionsProvider.notifier)
          .load(contentType: widget.contentType, ids: ids);
    });
  }

  bool _sameAs(List<String> ids) {
    if (ids.length != _loaded.length) return false;
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] != _loaded[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
