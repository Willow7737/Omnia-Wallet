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

  group('ThreadRail', () {
    testWidgets('draws a connector below the avatar when asked',
        (tester) async {
      Future<void> pumpRail({required bool railBelow}) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: OmniaTheme.light(),
            home: Scaffold(
              body: SizedBox(
                height: 200,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ThreadRail(
                      size: 34,
                      railBelow: railBelow,
                      avatar: const ColoredBox(color: Color(0xFF000000)),
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pumpRail(railBelow: true);
      final withRail = tester.widgetList(
        find.descendant(
          of: find.byType(ThreadRail),
          matching: find.byType(Container),
        ),
      );
      expect(withRail, isNotEmpty, reason: 'no rail was drawn');

      await pumpRail(railBelow: false);
      expect(
        find.descendant(
          of: find.byType(ThreadRail),
          matching: find.byType(Container),
        ),
        findsNothing,
        reason: 'the last item in a thread must not trail a connector',
      );
    });
  });
}
