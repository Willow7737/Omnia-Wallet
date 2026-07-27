import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:omnia_wallet/core/theme.dart';
import 'package:omnia_wallet/core/ui/button.dart';
import 'package:omnia_wallet/core/ui/thread.dart';

/// The overflow button's position is a *measurement*, and measurements are the
/// only thing that catches this class of bug: the old spelling laid out and
/// painted without a single warning, it just put the button in the wrong
/// place.
void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    required String name,
    double width = 390,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OmniaTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: ThreadHeader(
                name: name,
                timestamp: '2h',
                onMore: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('ThreadHeader', () {
    testWidgets('pins the overflow button to the trailing edge',
        (tester) async {
      await pumpHeader(tester, name: 'omnia');

      final header = tester.getRect(find.byType(ThreadHeader));
      final more = tester.getRect(find.byType(OmniaIconButton));

      // The previous spelling — Flexible + Spacer, both defaulting to flex:1 —
      // split the free space and parked the button near the middle. Allow only
      // the button's own internal padding.
      expect(
        header.right - more.right,
        lessThan(1),
        reason: 'overflow button is not at the trailing edge',
      );
    });

    testWidgets('stays pinned when the name is long', (tester) async {
      await pumpHeader(tester, name: 'a-very-long-display-name-' * 4);

      final header = tester.getRect(find.byType(ThreadHeader));
      final more = tester.getRect(find.byType(OmniaIconButton));

      expect(header.right - more.right, lessThan(1));
      // And the name yields rather than pushing the button off the edge.
      expect(more.left, greaterThan(header.left));
      expect(tester.takeException(), isNull);
    });

    testWidgets('pins identically at two different widths', (tester) async {
      await pumpHeader(tester, name: 'omnia', width: 320);
      final narrow = tester.getRect(find.byType(ThreadHeader)).right -
          tester.getRect(find.byType(OmniaIconButton)).right;

      await pumpHeader(tester, name: 'omnia', width: 500);
      final wide = tester.getRect(find.byType(ThreadHeader)).right -
          tester.getRect(find.byType(OmniaIconButton)).right;

      // A layout that depends on the free space available is exactly the bug;
      // the trailing gap must not vary with width.
      expect(narrow, closeTo(wide, 0.5));
    });
  });

  group('ThreadAction', () {
    testWidgets('sets the count beside its own glyph', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OmniaTheme.light(),
          home: const Scaffold(
            body: Center(
              child: ThreadAction(
                icon: Iconsax.message_copy,
                label: 'Replies',
                count: 12,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final icon = tester.getRect(find.byType(Icon));
      final count = tester.getRect(find.text('12'));

      expect(count.left - icon.right, lessThan(Space.md),
          reason: 'the count has drifted away from its icon');
      expect(count.left, greaterThan(icon.left));
    });

    testWidgets('hides a zero count rather than showing "0"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OmniaTheme.light(),
          home: const Scaffold(
            body: Center(
              child: ThreadAction(
                icon: Iconsax.message_copy,
                label: 'Replies',
                count: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('0'), findsNothing);
    });
  });

  // Connectors paint happily when they are wrong — a rail to nowhere throws
  // nothing and renders fine. The geometry is therefore computed before
  // anything is drawn, and asserted on directly.
  group('ThreadConnectorPlan', () {
    const avatar = 34.0;

    ThreadConnectorPlan plan({
      int depth = 0,
      List<bool> ancestorRails = const [],
      bool hasChildrenBelow = false,
      bool isLastChild = true,
    }) =>
        ThreadConnectorPlan.forRow(
          depth: depth,
          ancestorRails: ancestorRails,
          hasChildrenBelow: hasChildrenBelow,
          isLastChild: isLastChild,
          avatarSize: avatar,
        );

    test('a childless comment trails no rail', () {
      // The reported bug: a comment with no answers still had a connector
      // hanging off it, pointing at the unrelated comment below.
      expect(plan().ownRailX, isNull);
      expect(plan().elbow, isNull);
      expect(plan().railXs, isEmpty);
    });

    test('a comment with answers carries a rail below its avatar', () {
      final p = plan(hasChildrenBelow: true);
      expect(p.ownRailX, avatar / 2);
      // Starting at the avatar's centre would draw the line *through* the
      // face; it has to begin below it.
      expect(p.ownRailTop, greaterThan(avatar));
    });

    test('a reply curves out of its own parent, not some other level', () {
      final p = plan(depth: 2, ancestorRails: const [false, true]);
      final elbow = p.elbow!;

      // Level 1 is the parent, so the turn must start on level 1's centre.
      expect(elbow.x, ThreadGeometry.indent * 1 + avatar / 2);
      // …and arrive at this row's avatar.
      expect(elbow.endX, ThreadGeometry.indent * 2);
      expect(elbow.turnY, avatar / 2);
      expect(elbow.radius, greaterThan(0),
          reason: 'a zero radius is a square corner, not a curve');
    });

    test('the curve never inverts, however tight the space', () {
      // A radius larger than either the horizontal run or the drop would draw
      // an arc that bulges backwards.
      final p = ThreadConnectorPlan.forRow(
        depth: 1,
        ancestorRails: const [false],
        hasChildrenBelow: false,
        isLastChild: true,
        avatarSize: 8,
      );
      final elbow = p.elbow!;
      expect(elbow.radius, lessThanOrEqualTo(elbow.turnY));
      expect(elbow.radius, lessThanOrEqualTo((elbow.endX - elbow.x).abs()));
    });

    test("a middle child leaves its parent's rail running on", () {
      expect(plan(depth: 1, isLastChild: false).parentRailBelowX, avatar / 2);
      // The last child is where the parent's thread ends.
      expect(plan(depth: 1, isLastChild: true).parentRailBelowX, isNull);
    });

    test('a passing rail runs in the column its sibling elbows out of', () {
      // The reported bug: the rail sat one column too far right, so it hung
      // off a reply's avatar and ran down to that reply's *aunt* — making two
      // unrelated replies look like parent and child.
      //
      // ancestorRails[2] means "the ancestor at depth 2 has a later sibling".
      // That sibling is itself at depth 2, and its elbow starts from its own
      // parent's column — depth 1. So the rail belongs at depth 1's centre.
      final p = plan(depth: 3, ancestorRails: const [false, false, true]);
      expect(p.railXs, [ThreadGeometry.indent + avatar / 2]);
    });

    test('never draws a rail for a later top-level comment', () {
      // Index 0 would mean "the top-level comment has another comment after
      // it" — true of nearly every feed, and never a thread connection.
      final p = plan(depth: 2, ancestorRails: const [true, false]);
      expect(p.railXs, isEmpty);
    });

    test('draws no elbow once parent and child share a column', () {
      // Past the indent cap they sit at the same x. An elbow there has no gap
      // to cross, so it hooked out to the right and came back through the
      // avatar — visible as a stray tick beside deeply nested replies.
      final capped = plan(
        depth: ThreadGeometry.maxIndent + 1,
        ancestorRails: List.filled(ThreadGeometry.maxIndent + 1, false),
        isLastChild: false,
      );
      expect(capped.elbow, isNull);
      expect(capped.parentRailBelowX, isNull);

      // One level shallower there is still a gap, so the elbow stays.
      expect(
        plan(
          depth: ThreadGeometry.maxIndent,
          ancestorRails: List.filled(ThreadGeometry.maxIndent, false),
        ).elbow,
        isNotNull,
      );
    });

    test('keeps ancestor rails out of the row they run beside', () {
      // At and past the cap, several levels resolve to the same column; a
      // rail there would be painted over this row's own avatar.
      final deep = plan(
        depth: ThreadGeometry.maxIndent + 2,
        ancestorRails: List.filled(ThreadGeometry.maxIndent + 2, true),
      );
      final ownLeft = ThreadGeometry.indentFor(ThreadGeometry.maxIndent + 2);
      for (final x in deep.railXs) {
        expect(x, lessThan(ownLeft));
      }
      // …and none of them is drawn twice.
      expect(deep.railXs.toSet(), hasLength(deep.railXs.length));
    });

    test('stops indenting past the maximum depth', () {
      // Otherwise a long back-and-forth walks off the right-hand edge.
      final deep = plan(depth: 9, hasChildrenBelow: true).ownRailX;
      final capped = plan(
        depth: ThreadGeometry.maxIndent,
        hasChildrenBelow: true,
      ).ownRailX;
      expect(deep, capped);
    });
  });
}
