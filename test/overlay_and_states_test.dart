import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:omnia_wallet/core/theme.dart';
import 'package:omnia_wallet/core/ui/sheet.dart';
import 'package:omnia_wallet/core/ui/states.dart';

void main() {
  group('toast', () {
    testWidgets('sits under a Material, so text is not yellow-underlined',
        (tester) async {
      // The toast is inserted straight into the root Overlay. Text with no
      // Material above it is painted by the framework with a double yellow
      // underline — which is exactly what showed up on screen.
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          theme: OmniaTheme.light(),
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      showOmniaToast(ctx, message: 'Sign in to react', error: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final text = find.text('Sign in to react');
      expect(text, findsOneWidget);
      expect(
        find.ancestor(of: text, matching: find.byType(Material)),
        findsWidgets,
        reason: 'toast text has no Material ancestor',
      );

      // And the style itself carries no decoration.
      final widget = tester.widget<Text>(text);
      expect(
          widget.style?.decoration ?? TextDecoration.none, TextDecoration.none);

      // The toast dismisses itself on a timer; let it, or the test ends with
      // one still pending.
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    });
  });

  group('OmniaEmptyState', () {
    Future<void> pumpIn(WidgetTester tester, Widget Function(Widget) wrap) =>
        tester.pumpWidget(
          MaterialApp(
            theme: OmniaTheme.light(),
            home: Scaffold(
              body: wrap(
                const OmniaEmptyState(
                  icon: Iconsax.notification_copy,
                  title: 'Nothing yet',
                  message: 'Sends, votes and news will show up here.',
                ),
              ),
            ),
          ),
        );

    testWidgets('centres itself when it is given a whole screen',
        (tester) async {
      // Filling a body with a fixed top padding stranded the block in the
      // upper third with a large void beneath it.
      await pumpIn(tester, (child) => child);
      await tester.pump();

      final body = tester.getRect(find.byType(Scaffold));
      final title = tester.getRect(find.text('Nothing yet'));
      final above = title.top - body.top;
      final below = body.bottom - title.bottom;

      expect((above - below).abs(), lessThan(body.height * 0.12),
          reason: 'the empty state is not vertically centred');
    });

    testWidgets('takes only the room it needs inside a scroll view',
        (tester) async {
      // The same widget also lives inside lists, where height is unbounded
      // and centring is neither possible nor wanted.
      await pumpIn(tester, (child) => ListView(children: [child]));
      await tester.pump();

      expect(find.text('Nothing yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('clears space a tab bar floats over', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OmniaTheme.light(),
          home: const Scaffold(
            body: OmniaEmptyState(
              icon: Iconsax.notification_copy,
              title: 'Nothing yet',
              bottomInset: 200,
            ),
          ),
        ),
      );
      await tester.pump();

      final body = tester.getRect(find.byType(Scaffold));
      final title = tester.getRect(find.text('Nothing yet'));
      // Centred in the space above the bar, so it sits above the midpoint.
      expect(title.center.dy, lessThan(body.center.dy));
    });
  });
}
