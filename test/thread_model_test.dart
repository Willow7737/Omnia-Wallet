import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/data/news.dart';
import 'package:omnia_wallet/features/news/thread_model.dart';

/// The connectors are the thing people notice when a thread is wrong — a rail
/// dangling off a childless comment, or a reply that looks unattached. None of
/// that throws, and none of it shows up in a render smoke test, so the layout
/// is a pure function and it gets tested as one.
void main() {
  NewsReply r(String id, {String? parent}) => NewsReply(
        id: id,
        postId: 'p',
        authorName: id,
        authorDid: 'did:omnia:$id',
        body: id,
        createdAt: DateTime(2026, 1, 1),
        parentId: parent,
      );

  ThreadRow rowFor(ThreadLayout layout, String id) =>
      layout.rows.firstWhere((row) => row.reply.id == id);

  group('depth', () {
    test('nests to arbitrary depth', () {
      final layout = buildThreadLayout([
        r('a'),
        r('b', parent: 'a'),
        r('c', parent: 'b'),
        r('d', parent: 'c'),
      ]);

      expect(layout.rows.map((row) => row.reply.id), ['a', 'b', 'c', 'd']);
      expect(layout.rows.map((row) => row.depth), [0, 1, 2, 3]);
    });

    test('renders a child directly beneath its parent, not after siblings', () {
      // Flat order puts c last, but it answers a — so it belongs under a.
      final layout = buildThreadLayout([
        r('a'),
        r('b'),
        r('c', parent: 'a'),
      ]);
      expect(layout.rows.map((row) => row.reply.id), ['a', 'c', 'b']);
    });
  });

  group('rails', () {
    test('a childless comment trails no rail', () {
      // The reported bug: two unrelated top-level comments were stitched
      // together by a rail belonging to neither.
      final layout = buildThreadLayout([r('a'), r('b')]);
      expect(rowFor(layout, 'a').hasChildrenBelow, isFalse);
      expect(rowFor(layout, 'b').hasChildrenBelow, isFalse);
    });

    test('a comment with replies carries a rail', () {
      final layout = buildThreadLayout([r('a'), r('b', parent: 'a')]);
      expect(rowFor(layout, 'a').hasChildrenBelow, isTrue);
      expect(rowFor(layout, 'b').hasChildrenBelow, isFalse);
    });

    test("an ancestor's rail passes a row only while a sibling is to come", () {
      final layout = buildThreadLayout([
        r('a'),
        r('b', parent: 'a'),
        r('c', parent: 'b'),
        r('d', parent: 'a'),
      ]);

      // Level 1 is b's rail: b has a later sibling (d), so it runs on past c
      // to reach it. Level 0 is a's own rail, and a is the only top-level
      // comment, so nothing of it continues past c.
      expect(rowFor(layout, 'c').ancestorRails, [false, true]);
      // d is a's last child, so a's rail stops at d's elbow.
      expect(rowFor(layout, 'd').ancestorRails, [false]);
      expect(rowFor(layout, 'd').isLastChild, isTrue);
      expect(rowFor(layout, 'b').isLastChild, isFalse);
    });

    test('top-level comments are never joined to each other', () {
      final layout = buildThreadLayout([r('a'), r('b'), r('c')]);
      for (final row in layout.rows) {
        expect(row.depth, 0);
        expect(row.ancestorRails, isEmpty);
      }
    });

    test("a reply never carries a rail on to the next top-level comment", () {
      // The reported bug, exactly: a has an answer, and another comment
      // follows a. The answer used to be given a level-0 rail — because a
      // "had a later sibling" — which drew a line from a, past its own
      // answer, straight into an unrelated comment.
      final layout = buildThreadLayout([
        r('a'),
        r('answer', parent: 'a'),
        r('unrelated'),
      ]);

      expect(
          layout.rows.map((row) => row.reply.id), ['a', 'answer', 'unrelated']);
      expect(
        rowFor(layout, 'answer').ancestorRails,
        [false],
        reason: 'a rail ran from one top-level comment into the next',
      );
    });

    test('a nested sibling still gets its passing rail', () {
      // The fix must not cost the legitimate case: inside a thread, an
      // ancestor with more answers to come does keep its rail.
      final layout = buildThreadLayout([
        r('root'),
        r('a', parent: 'root'),
        r('a1', parent: 'a'),
        r('b', parent: 'root'),
        r('other'),
      ]);

      // Level 0 is `root`, which must never continue; level 1 is `a`, which
      // does — `b` is still to come.
      expect(rowFor(layout, 'a1').ancestorRails, [false, true]);
    });
  });

  group('collapsing', () {
    test('holds back a long run of answers', () {
      final layout = buildThreadLayout(
        [r('a'), for (var i = 0; i < 6; i++) r('c$i', parent: 'a')],
        collapseAfter: 3,
      );

      expect(layout.rows.length, 4, reason: 'parent plus three answers');
      expect(layout.collapsed, hasLength(1));
      expect(layout.collapsed.values.single.hidden.length, 3);
      expect(layout.collapsed.values.single.parentId, 'a');
    });

    test('keeps the rail running down to the collapsed marker', () {
      final layout = buildThreadLayout(
        [r('a'), for (var i = 0; i < 6; i++) r('c$i', parent: 'a')],
        collapseAfter: 3,
      );
      // The last *shown* answer is not really the last one, so the parent's
      // rail must carry on to reach the "show more" row.
      expect(rowFor(layout, 'c2').isLastChild, isFalse);
    });

    test('expanding reveals the rest', () {
      final replies = [
        r('a'),
        for (var i = 0; i < 6; i++) r('c$i', parent: 'a')
      ];
      final layout = buildThreadLayout(
        replies,
        collapseAfter: 3,
        expanded: {'a'},
      );
      expect(layout.rows.length, 7);
      expect(layout.collapsed, isEmpty);
      expect(rowFor(layout, 'c5').isLastChild, isTrue);
    });

    test('never collapses top-level comments', () {
      final layout = buildThreadLayout(
        [for (var i = 0; i < 10; i++) r('t$i')],
        collapseAfter: 3,
      );
      expect(layout.rows.length, 10);
      expect(layout.collapsed, isEmpty);
    });
  });

  group('robustness', () {
    test('promotes an orphan rather than dropping it', () {
      // The parent was deleted, or hidden by a block. Losing the reply
      // silently would be worse than showing it at the top level.
      final layout = buildThreadLayout([r('a'), r('b', parent: 'gone')]);
      expect(layout.rows.map((row) => row.reply.id), containsAll(['a', 'b']));
      expect(rowFor(layout, 'b').depth, 0);
    });

    test('survives a reply that claims itself as its parent', () {
      final layout = buildThreadLayout([r('a', parent: 'a')]);
      expect(layout.rows, hasLength(1));
      expect(rowFor(layout, 'a').depth, 0);
    });

    test('handles an empty thread', () {
      expect(buildThreadLayout(const []).rows, isEmpty);
    });
  });
}
