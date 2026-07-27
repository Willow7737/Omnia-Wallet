import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/data/reactions.dart';

/// The counter arithmetic is what the reader actually sees, and it runs
/// *before* the server confirms anything — an optimistic update that disagrees
/// with the row the server ends up holding makes the count jump back a moment
/// later. So it is a pure function, and it is pinned here.
void main() {
  const none = ReactionTally(likes: 5, dislikes: 2);

  group('toggled', () {
    test('liking adds one and records the direction', () {
      final after = none.toggled(1);
      expect(after.likes, 6);
      expect(after.dislikes, 2);
      expect(after.mine, 1);
      expect(after.liked, isTrue);
    });

    test('liking again takes it back off', () {
      final after = none.toggled(1).toggled(1);
      expect(after.likes, 5);
      expect(after.mine, 0);
      expect(after.liked, isFalse);
    });

    test('switching sides moves the vote in one tap', () {
      // Not two taps, and not a like *and* a dislike from the same person.
      final after = none.toggled(1).toggled(-1);
      expect(after.likes, 5, reason: 'the like should have been withdrawn');
      expect(after.dislikes, 3);
      expect(after.mine, -1);
      expect(after.disliked, isTrue);
    });

    test('disliking twice clears it', () {
      final after = none.toggled(-1).toggled(-1);
      expect(after.dislikes, 2);
      expect(after.mine, 0);
    });

    test('a full round trip returns to exactly where it started', () {
      expect(none.toggled(1).toggled(-1).toggled(-1), none);
    });

    test('never renders a negative count from a stale tally', () {
      // The server said zero likes, but this user's own row says they liked
      // it — the count is behind. Un-liking must floor at zero, not show -1.
      const stale = ReactionTally(likes: 0, dislikes: 0, mine: 1);
      final after = stale.toggled(1);
      expect(after.likes, 0);
      expect(after.mine, 0);
    });
  });

  group('withCounts / withMine', () {
    test('fresh server counts do not clobber this user’s own standing', () {
      // A realtime tick brings new totals; it must not un-highlight the heart
      // the reader is looking at.
      const mine = ReactionTally(likes: 5, dislikes: 0, mine: 1);
      final refreshed = mine.withCounts(likes: 9, dislikes: 1);
      expect(refreshed.likes, 9);
      expect(refreshed.dislikes, 1);
      expect(refreshed.mine, 1);
    });

    test('withMine keeps the counts', () {
      final tallied = none.withMine(-1);
      expect(tallied.likes, 5);
      expect(tallied.dislikes, 2);
      expect(tallied.mine, -1);
    });
  });

  group('ReactionKey', () {
    test('a post and a reply with the same id are different content', () {
      // They live in separate tables and share one reaction table, so the
      // pair — not the id — has to be the key.
      expect(
        const ReactionKey('post', 'x') == const ReactionKey('reply', 'x'),
        isFalse,
      );
    });

    test('equal keys hash together, so map lookups find the tally', () {
      const a = ReactionKey('post', 'x');
      const b = ReactionKey('post', 'x');
      expect(a, b);
      expect({a: 1}[b], 1);
    });
  });

  group('inList', () {
    test('quotes each id so a stray comma cannot widen the filter', () {
      expect(ReactionRepository.inList(['a', 'b']), '("a","b")');
      expect(ReactionRepository.inList(['a,b']), '("a,b")');
    });

    test('escapes a quote rather than closing the string early', () {
      expect(ReactionRepository.inList(['a"b']), r'("a\"b")');
    });
  });
}
