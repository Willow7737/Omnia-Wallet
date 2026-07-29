import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/data/reactions.dart';
import 'package:omnia_wallet/data/supabase_gateway.dart';

import 'support/fake_gateway.dart';
import 'package:omnia_wallet/state/providers.dart';
import 'package:omnia_wallet/state/reactions.dart';

/// Rapid tapping was the reported bug: the count climbed to 2 before settling
/// back. Every part of the cure is about *timing* — how many requests go out,
/// in what order, and which server reads are allowed to land — so none of it
/// shows up in a render test. It is asserted here directly.
void main() {
  const key = ReactionKey(ReactionKey.post, 'p1');

  ProviderContainer containerWith(
    _FakeRepo repo, {
    bool signedIn = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        reactionRepositoryProvider.overrideWithValue(repo),
        supabaseGatewayProvider
            .overrideWithValue(_FakeGateway(authenticated: signedIn)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Longer than the notifier's write debounce, so the flush has run.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 900));

  group('rapid tapping', () {
    test('sends one request for a burst, carrying the final state', () async {
      final repo = _FakeRepo();
      final container = containerWith(repo);
      final notifier = container.read(reactionsProvider.notifier);

      // Five taps in the time it takes to tap five times.
      for (var i = 0; i < 5; i++) {
        notifier.toggle(
          contentType: ReactionKey.post,
          contentId: 'p1',
          direction: 1,
        );
      }
      await settle();

      expect(repo.writes, hasLength(1),
          reason: 'a burst of taps must not become a burst of requests');
      // Odd number of taps on an unliked post: it ends liked.
      expect(repo.writes.single.value, 1);
    });

    test('an even number of taps settles back to no reaction', () async {
      final repo = _FakeRepo();
      final notifier = containerWith(repo).read(reactionsProvider.notifier);

      for (var i = 0; i < 4; i++) {
        notifier.toggle(
          contentType: ReactionKey.post,
          contentId: 'p1',
          direction: 1,
        );
      }
      await settle();

      expect(repo.writes.single.value, 0, reason: 'should have cleared');
    });

    test('the count never overshoots while tapping', () async {
      final repo = _FakeRepo();
      final container = containerWith(repo);
      final notifier = container.read(reactionsProvider.notifier);

      // This is the exact symptom: the number climbing past one like from one
      // person. Check after every tap, not just at the end.
      for (var i = 0; i < 8; i++) {
        notifier.toggle(
          contentType: ReactionKey.post,
          contentId: 'p1',
          direction: 1,
        );
        final tally = container.read(reactionsProvider)[key]!;
        expect(tally.likes, lessThanOrEqualTo(1),
            reason: 'one person cannot like a post twice');
        expect(tally.likes, i.isEven ? 1 : 0);
      }
      await settle();
    });

    test('updates the screen without waiting for the network', () {
      // The repository here never completes. The heart must fill anyway.
      final repo = _FakeRepo(hang: true);
      final container = containerWith(repo);

      container.read(reactionsProvider.notifier).toggle(
            contentType: ReactionKey.post,
            contentId: 'p1',
            direction: 1,
          );

      expect(container.read(reactionsProvider)[key]!.liked, isTrue);
    });
  });

  group('reads racing writes', () {
    test('a refetch does not clobber a tap that has not settled', () async {
      // The reported bug in miniature: the server's `mine` was read before
      // the like landed, so a refetch says "1 like, not yours" and the next
      // tap adds a second one on top.
      final repo = _FakeRepo()
        ..tallies[key] = const ReactionTally(likes: 1)
        ..mineValues[key] = 0;

      final container = containerWith(repo);
      final notifier = container.read(reactionsProvider.notifier);

      notifier.toggle(
        contentType: ReactionKey.post,
        contentId: 'p1',
        direction: 1,
      );
      final optimistic = container.read(reactionsProvider)[key]!;

      // A realtime tick lands mid-interaction, carrying that stale pair.
      await notifier.load(contentType: ReactionKey.post, ids: ['p1']);

      expect(
        container.read(reactionsProvider)[key],
        optimistic,
        reason: 'a stale read overwrote what the user just did',
      );
      await settle();
    });

    test('a refetch is applied to content the user is not touching', () async {
      const other = ReactionKey(ReactionKey.post, 'p2');
      final repo = _FakeRepo()
        ..tallies[other] = const ReactionTally(likes: 7)
        ..mineValues[other] = 0;

      final container = containerWith(repo);
      await container
          .read(reactionsProvider.notifier)
          .load(contentType: ReactionKey.post, ids: ['p2']);

      expect(container.read(reactionsProvider)[other]!.likes, 7);
    });
  });

  group('signed out', () {
    test('cannot react, and nothing optimistic is painted', () async {
      final repo = _FakeRepo();
      final container = containerWith(repo, signedIn: false);
      final notifier = container.read(reactionsProvider.notifier);

      expect(notifier.canReact, isFalse);

      notifier.toggle(
        contentType: ReactionKey.post,
        contentId: 'p1',
        direction: 1,
      );
      await settle();

      // A like that would vanish on the next load is worse than no like.
      expect(container.read(reactionsProvider)[key], isNull);
      expect(repo.writes, isEmpty);
    });
  });

  group('failure', () {
    test('a failed write leaves the server as the source of truth', () async {
      final repo = _FakeRepo(fail: true)
        ..tallies[key] = const ReactionTally(likes: 3)
        ..mineValues[key] = 0;

      final container = containerWith(repo);
      container.read(reactionsProvider.notifier).toggle(
            contentType: ReactionKey.post,
            contentId: 'p1',
            direction: 1,
          );
      await settle();

      // Not a rollback to a remembered value — that is itself stale after a
      // burst. The reconcile read wins.
      final tally = container.read(reactionsProvider)[key]!;
      expect(tally.likes, 3);
      expect(tally.mine, 0);
    });
  });
}

class _Write {
  _Write(this.value);
  final int value;
}

class _FakeRepo implements ReactionRepository {
  _FakeRepo({this.fail = false, this.hang = false});

  final bool fail;

  /// Never completes, to prove the screen does not wait on the network.
  final bool hang;

  final List<_Write> writes = [];
  final Map<ReactionKey, ReactionTally> tallies = {};
  final Map<ReactionKey, int> mineValues = {};

  @override
  Future<Map<ReactionKey, ReactionTally>> counts({
    required String contentType,
    required List<String> ids,
  }) async =>
      tallies;

  @override
  Future<Map<ReactionKey, int>> mine({
    required String contentType,
    required List<String> ids,
    required String userId,
    required String accessToken,
  }) async =>
      mineValues;

  @override
  Future<void> setReaction({
    required String contentType,
    required String contentId,
    required int value,
    required String userId,
    required String accessToken,
  }) async {
    if (hang) return Completer<void>().future;
    writes.add(_Write(value));
    if (fail) throw StateError('write failed');
  }
}

class _FakeGateway extends FakeGatewayBase {
  // `authenticated` is named that way on the base because the interface
  // already uses `signedIn` for its stream.
  _FakeGateway({required super.authenticated});

  @override
  String? get userEmail => 'user@example.com';

  @override
  String? get userName => 'Willow';

  @override
  Future<String> accessToken() async => 'token';

  @override
  Future<void> signInWithSocial(SocialProvider provider) async {}

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Stream<void> get signedIn => const Stream.empty();

  @override
  Stream<void> tableChanges(String table) => const Stream.empty();
}
