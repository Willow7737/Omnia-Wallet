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
///
/// # How a tap is handled
///
/// The rule every social app converges on: **the finger drives the screen,
/// the network follows.** Concretely —
///
///  1. A tap updates local state immediately and unconditionally. It never
///     waits on, and is never corrected by, a request in flight.
///  2. The write is *coalesced*. Ten rapid taps send one request carrying the
///     final state, not ten requests racing each other to the server.
///  3. At most one request per piece of content is ever outstanding. If the
///     user taps again while one is in flight, the new intent is recorded and
///     sent after it settles.
///  4. A refetch — whether from a realtime event or a screen opening — never
///     overwrites content the user is currently interacting with.
///
/// Rule 4 is what produced the reported bug. `counts` and `mine` are two
/// requests; if a refetch's `mine` was read before the user's like landed and
/// its `counts` after, the pair arrives as "1 like, but not yours". The next
/// tap then adds a second like on top of one the user had already made, and
/// the heart briefly shows 2 before the following refetch corrects it. No
/// amount of care inside `toggled` can fix that — the stale read has to not
/// be applied at all.
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
  Timer? _realtimeDebounce;

  /// What has been loaded, so a realtime tick knows what to refetch.
  final Map<String, Set<String>> _tracked = {};

  /// The reaction value the server *should* end up holding, for content the
  /// user has touched and whose write has not settled yet.
  final Map<ReactionKey, int> _desired = {};

  /// Per-key debounce, so a burst of taps sends one request.
  final Map<ReactionKey, Timer> _writeTimers = {};

  /// Keys with a request outstanding. Rule 3.
  final Set<ReactionKey> _inFlight = {};

  /// How long after the last tap the write goes out. Long enough to swallow a
  /// double-tap-to-undo, short enough that a single deliberate tap does not
  /// feel like it was dropped.
  static const Duration _writeDelay = Duration(milliseconds: 400);

  ReactionTally operator [](ReactionKey key) =>
      state[key] ?? const ReactionTally();

  /// Whether reacting is possible at all — false when signed out, which the
  /// UI checks before painting anything optimistic.
  bool get canReact {
    final gateway = _ref.read(supabaseGatewayProvider);
    return gateway.isAvailable && gateway.isSignedIn && gateway.userId != null;
  }

  /// True while this content has an unsettled local change, in which case a
  /// server read must not be applied over it.
  bool _isBusy(ReactionKey key) =>
      _desired.containsKey(key) || _inFlight.contains(key);

  // -------------------------------------------------------------------------
  // Reading
  // -------------------------------------------------------------------------

  void _watchRealtime() {
    final gateway = _ref.read(supabaseGatewayProvider);
    _realtime = gateway.tableChanges('news_reactions').listen(
          (_) => _scheduleRealtimeRefresh(),
          // A dropped socket must not take the feed down with it; counts simply
          // stop being live until the next explicit load.
          onError: (_) {},
        );
  }

  /// A burst of reactions produces a burst of events. Coalesce them, or a
  /// popular post refetches once per like.
  void _scheduleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 350), () {
      for (final entry in _tracked.entries) {
        unawaited(load(contentType: entry.key, ids: entry.value.toList()));
      }
    });
  }

  /// Fetch public counts for [ids], and this user's own reactions when signed
  /// in.
  ///
  /// Content the user is mid-interaction with is deliberately left alone —
  /// see rule 4 on [reactionsProvider].
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
        if (_isBusy(key)) continue;
        next[key] =
            (counts[key] ?? const ReactionTally()).withMine(mine[key] ?? 0);
      }
      state = next;
    } catch (_) {
      // Counts are decoration on top of content that already rendered. A
      // failure here leaves whatever was last known in place rather than
      // replacing a post with an error.
    }
  }

  /// Re-read a single piece of content, ignoring the busy guard.
  ///
  /// Used to reconcile after a write settles, which is the one moment a
  /// server read is more trustworthy than what is on screen.
  Future<void> _reconcile(ReactionKey key) async {
    final repo = _ref.read(reactionRepositoryProvider);
    final gateway = _ref.read(supabaseGatewayProvider);
    try {
      final counts = await repo.counts(
        contentType: key.contentType,
        ids: [key.contentId],
      );
      var tally = counts[key] ?? const ReactionTally();

      final userId = gateway.isAvailable ? gateway.userId : null;
      if (userId != null && gateway.isSignedIn) {
        final token = await gateway.accessToken();
        final mine = await repo.mine(
          contentType: key.contentType,
          ids: [key.contentId],
          userId: userId,
          accessToken: token,
        );
        tally = tally.withMine(mine[key] ?? 0);
      }
      // Another tap may have arrived while this was in the air; that intent
      // is newer than this read, so it wins.
      if (!mounted || _isBusy(key)) return;
      state = {...state, key: tally};
    } catch (_) {
      // Leave the optimistic value. It is what the user asked for, and the
      // next load will settle it.
    }
  }

  // -------------------------------------------------------------------------
  // Writing
  // -------------------------------------------------------------------------

  /// Apply the user's press.
  ///
  /// Returns immediately: the screen is already updated by the time this
  /// call ends, and the request is scheduled rather than awaited. Callers
  /// should check [canReact] first — a signed-out user gets no optimistic
  /// paint, because it would vanish on the next load.
  ///
  /// [direction] is +1 (like) or -1 (dislike).
  void toggle({
    required String contentType,
    required String contentId,
    required int direction,
  }) {
    if (!canReact) return;

    final key = ReactionKey(contentType, contentId);
    final after = this[key].toggled(direction);

    state = {...state, key: after};
    _tracked.putIfAbsent(contentType, () => {}).add(contentId);
    _desired[key] = after.mine;

    _writeTimers[key]?.cancel();
    _writeTimers[key] = Timer(_writeDelay, () => unawaited(_flush(key)));
  }

  /// Send the settled intent for [key], then reconcile.
  Future<void> _flush(ReactionKey key) async {
    _writeTimers.remove(key);
    // Rule 3: one request at a time. Whoever is in flight will re-check
    // `_desired` when it finishes, so dropping out here loses nothing.
    if (_inFlight.contains(key)) return;

    final gateway = _ref.read(supabaseGatewayProvider);
    final userId = gateway.isAvailable ? gateway.userId : null;
    if (userId == null || !gateway.isSignedIn) {
      _desired.remove(key);
      return;
    }

    _inFlight.add(key);
    try {
      // Loop rather than recurse: taps arriving during a write are picked up
      // on the next turn, and the loop ends when the server holds what the
      // user last asked for.
      while (_desired.containsKey(key)) {
        final value = _desired[key]!;
        final token = await gateway.accessToken();
        await _ref.read(reactionRepositoryProvider).setReaction(
              contentType: key.contentType,
              contentId: key.contentId,
              value: value,
              userId: userId,
              accessToken: token,
            );
        // Only clear if nothing newer arrived while that was in the air.
        if (_desired[key] == value) _desired.remove(key);
      }
    } catch (_) {
      // The write failed. Rolling back to a remembered "before" is wrong
      // after several taps — that value is itself stale. Drop the intent and
      // let the server say what is true.
      _desired.remove(key);
    } finally {
      _inFlight.remove(key);
    }

    if (mounted) await _reconcile(key);
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    for (final timer in _writeTimers.values) {
      timer.cancel();
    }
    _realtime?.cancel();
    super.dispose();
  }
}
