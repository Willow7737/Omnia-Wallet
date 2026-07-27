import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reactions.dart';
import 'providers.dart';

final reactionRepositoryProvider =
    Provider<ReactionRepository>((ref) => ReactionRepository());

/// Every tally the app has loaded, keyed by content.
///
/// One store rather than a provider per post, because the feed, the post
/// screen and the reply thread all show counts for the same content and must
/// never disagree with each other. A like tapped on the feed is already
/// correct when the detail screen opens.
final reactionsProvider =
    StateNotifierProvider<ReactionsNotifier, Map<ReactionKey, ReactionTally>>(
  (ref) => ReactionsNotifier(ref),
);

class ReactionsNotifier extends StateNotifier<Map<ReactionKey, ReactionTally>> {
  ReactionsNotifier(this._ref) : super(const {}) {
    _watchRealtime();
  }

  final Ref _ref;
  StreamSubscription<void>? _realtime;
  Timer? _debounce;

  /// What has been loaded, so a realtime tick knows what to refetch.
  final Map<String, Set<String>> _tracked = {};

  ReactionTally operator [](ReactionKey key) =>
      state[key] ?? const ReactionTally();

  /// Subscribe to the reaction table so a like landing on another device
  /// shows up here without a pull-to-refresh.
  void _watchRealtime() {
    final gateway = _ref.read(supabaseGatewayProvider);
    _realtime = gateway.tableChanges('news_reactions').listen(
          (_) => _scheduleRefresh(),
          // A dropped socket must not take the feed down with it; counts simply
          // stop being live until the next explicit load.
          onError: (_) {},
        );
  }

  /// A burst of reactions produces a burst of events. Coalesce them, or a
  /// popular post refetches once per like.
  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      for (final entry in _tracked.entries) {
        // ignore: discarded_futures — fire and forget; failures leave the
        // last known counts on screen, which is better than an error state.
        load(contentType: entry.key, ids: entry.value.toList());
      }
    });
  }

  /// Fetch public counts for [ids], and this user's own reactions when signed
  /// in. Safe to call on every build — it only issues network work for the
  /// ids given.
  Future<void> load({
    required String contentType,
    required List<String> ids,
  }) async {
    if (ids.isEmpty || !mounted) return;
    _tracked.putIfAbsent(contentType, () => {}).addAll(ids);

    final repo = _ref.read(reactionRepositoryProvider);
    final gateway = _ref.read(supabaseGatewayProvider);

    try {
      final counts = await repo.counts(contentType: contentType, ids: ids);

      Map<ReactionKey, int> mine = const {};
      final userId = gateway.isAvailable ? gateway.userId : null;
      if (userId != null && gateway.isSignedIn) {
        final token = await gateway.accessToken();
        mine = await repo.mine(
          contentType: contentType,
          ids: ids,
          userId: userId,
          accessToken: token,
        );
      }
      if (!mounted) return;

      final next = {...state};
      for (final id in ids) {
        final key = ReactionKey(contentType, id);
        final tally = counts[key] ?? const ReactionTally();
        next[key] = tally.withMine(mine[key] ?? 0);
      }
      state = next;
    } catch (_) {
      // Counts are decoration on top of content that already rendered. A
      // failure here leaves whatever was last known in place rather than
      // replacing a post with an error.
    }
  }

  /// Apply the user's press optimistically, then persist it.
  ///
  /// [direction] is +1 (like) or -1 (dislike). The UI is updated before the
  /// request goes out — a heart that waits on a round trip feels broken — and
  /// rolled back if the write fails.
  ///
  /// Returns the tally that ended up on screen.
  Future<ReactionTally> toggle({
    required String contentType,
    required String contentId,
    required int direction,
  }) async {
    final key = ReactionKey(contentType, contentId);
    final before = this[key];
    final after = before.toggled(direction);

    state = {...state, key: after};
    _tracked.putIfAbsent(contentType, () => {}).add(contentId);

    final gateway = _ref.read(supabaseGatewayProvider);
    final userId = gateway.isAvailable ? gateway.userId : null;
    if (userId == null || !gateway.isSignedIn) {
      // Not signed in: keep the optimistic paint out of the store rather than
      // showing a like that will vanish on the next load.
      state = {...state, key: before};
      throw StateError('Sign in to react');
    }

    try {
      final token = await gateway.accessToken();
      await _ref.read(reactionRepositoryProvider).setReaction(
            contentType: contentType,
            contentId: contentId,
            value: after.mine,
            userId: userId,
            accessToken: token,
          );
      return after;
    } catch (e) {
      if (mounted) state = {...state, key: before};
      rethrow;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _realtime?.cancel();
    super.dispose();
  }
}
