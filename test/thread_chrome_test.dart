import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/core/config.dart';
import 'package:omnia_wallet/core/theme.dart';
import 'package:omnia_wallet/core/ui/list_row.dart';
import 'package:omnia_wallet/core/ui/thread.dart';
import 'package:omnia_wallet/data/news.dart';
import 'package:omnia_wallet/features/news/reply_thread.dart';

/// The rules around a thread's chrome: where a rule belongs, and who may wear
/// a tick.
void main() {
  NewsReply r(String id, {String? parent, String? name}) => NewsReply(
        id: id,
        postId: 'p',
        authorName: name ?? id,
        authorDid: 'did:omnia:$id',
        body: id,
        createdAt: DateTime.now(),
        parentId: parent,
      );

  Future<void> pump(WidgetTester tester, List<NewsReply> replies) async {
    tester.view.physicalSize = const Size(420, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: OmniaTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ThreadedReplies(
                replies: replies,
                myUserId: null,
                blocked: const {},
                canInteract: true,
                onReply: (_) {},
                onMenu: (_, {required bool isMine}) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('separators', () {
    testWidgets('a rule sits between comments and nowhere else',
        (tester) async {
      // Three comments, one of which has two replies. A thread is one
      // conversation: slicing it with rules would contradict the connectors.
      await pump(tester, [
        r('a'),
        r('a1', parent: 'a'),
        r('a2', parent: 'a1'),
        r('b'),
        r('c'),
      ]);

      // Two gaps between three comments.
      expect(find.byType(Hairline), findsNWidgets(2));
    });

    testWidgets('no rule above the first comment', (tester) async {
      await pump(tester, [r('only')]);
      expect(find.byType(Hairline), findsNothing);
    });

    testWidgets('replies alone never introduce a rule', (tester) async {
      await pump(tester, [
        r('a'),
        for (var i = 0; i < 3; i++) r('a$i', parent: 'a'),
      ]);
      expect(find.byType(Hairline), findsNothing);
    });
  });

  group('show replies marker', () {
    testWidgets('is a thread row, so rails passing it are drawn',
        (tester) async {
      // The reported gap: the marker was a plain indented label, so an
      // ancestor's rail simply stopped above it and picked up again below —
      // the thread visibly broke across the row.
      await pump(tester, [
        r('parent'),
        r('a', parent: 'parent'),
        r('a1', parent: 'a'),
        r('b', parent: 'parent'),
      ]);
      await tester.tap(find.text('Show replies').first);
      await tester.pump(const Duration(milliseconds: 300));

      final marker = find.byType(ThreadMoreReplies);
      expect(marker, findsOneWidget);

      final item = tester.widget<ThreadItem>(
        find.descendant(of: marker, matching: find.byType(ThreadItem)),
      );
      // `a` still has `b` to come, so its parent's rail must pass this row.
      expect(item.ancestorRails, isNotEmpty);
      expect(item.ancestorRails.last, isTrue,
          reason: 'no rail is carried across the marker');
    });

    testWidgets('stands in the column of the replies it hides', (tester) async {
      await pump(tester, [r('parent'), r('a', parent: 'parent')]);

      final marker = find.byType(ThreadMoreReplies);
      final item = tester.widget<ThreadItem>(
        find.descendant(of: marker, matching: find.byType(ThreadItem)),
      );
      expect(item.depth, 1, reason: 'drawn at the depth of the hidden replies');

      // The faces start where those replies' avatars will, and the label
      // clears the whole stack plus the usual gutter.
      final facesLeft = Space.lg + ThreadGeometry.indentFor(1);
      final label = tester.getRect(find.text('Show replies'));
      expect(
        label.left,
        closeTo(facesLeft + ThreadMoreReplies.stackWidth(1) + Space.md, 1),
      );
    });

    test('draws its rails in the thread\'s columns, not its own', () {
      // The reported break: columns were measured from the row's own leading
      // element, and a marker's faces are 18pt where an avatar is 34. Every
      // rail landed 8pt to the left — a stub hanging beside the thread
      // instead of continuing it, with the elbow starting off the parent's
      // line.
      ThreadConnectorPlan planFor(double avatarSize) =>
          ThreadConnectorPlan.forRow(
            depth: 2,
            ancestorRails: const [false, true],
            hasChildrenBelow: false,
            isLastChild: true,
            avatarSize: avatarSize,
          );

      final reply = planFor(ThreadGeometry.avatar);
      final marker = planFor(18);

      expect(marker.railXs, isNotEmpty);
      expect(marker.railXs, reply.railXs);
      expect(marker.elbow!.x, reply.elbow!.x,
          reason: 'the elbow must leave the parent\'s actual rail');
      expect(marker.elbow!.endX, reply.elbow!.endX);

      // Only the height of the turn is this row's own business: it arrives at
      // the middle of whatever it is pointing at.
      expect(marker.elbow!.turnY, 9);
      expect(reply.elbow!.turnY, 17);
    });
  });

  group('rails run unbroken', () {
    testWidgets('consecutive rows leave no unpainted band between them',
        (tester) async {
      // Each row used to take its breathing room as an outer padding, so the
      // connector strip started 8pt below the row's top. An ancestor rail
      // crossing that band simply was not painted, and a thread three deep
      // came out as a dashed line — one gap per row boundary.
      await pump(tester, [
        r('a'),
        r('a1', parent: 'a'),
        r('a2', parent: 'a1'),
        r('b', parent: 'a'),
      ]);
      for (var i = 0; i < 3; i++) {
        final more = find.text('Show replies');
        if (more.evaluate().isEmpty) break;
        await tester.tap(more.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      final strips = tester
          .widgetList<CustomPaint>(find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is ThreadConnectorPainter,
          ))
          .toList();
      expect(strips.length, greaterThan(2));

      final rects = tester
          .renderObjectList<RenderBox>(find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ThreadConnectorPainter,
      ))
          .map((box) {
        final top = box.localToGlobal(Offset.zero).dy;
        return (top: top, bottom: top + box.size.height);
      }).toList()
        ..sort((a, b) => a.top.compareTo(b.top));

      for (var i = 1; i < rects.length; i++) {
        expect(
          rects[i].top,
          lessThanOrEqualTo(rects[i - 1].bottom + 0.01),
          reason: 'a ${rects[i].top - rects[i - 1].bottom}pt band between rows '
              '${i - 1} and $i is never painted, so any rail crossing it '
              'breaks',
        );
      }
    });

    testWidgets("a passing parent's rail is painted for the whole row",
        (tester) async {
      // The elbow's arc curves out of the parent's column partway down, so
      // starting the continuing rail at the turn left a notch the size of the
      // corner radius in a line that runs straight past.
      const key = ValueKey('strip');
      await tester.pumpWidget(
        MaterialApp(
          theme: OmniaTheme.light(),
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 200,
                child: ThreadItem(
                  depth: 1,
                  ancestorRails: const [false],
                  hasChildrenBelow: false,
                  // Not the last child, so the parent's rail passes this row.
                  isLastChild: false,
                  topGap: Space.sm,
                  avatar: const SizedBox(width: 34, height: 34),
                  child: const SizedBox(height: 60),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final image = await tester.runAsync(
        () => (tester.renderObject(find.byKey(key)) as RenderRepaintBoundary)
            .toImage(),
      );
      final data = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      final pixels = data!.buffer.asUint8List();
      final width = image!.width;
      int channel(int x, int y, int c) => pixels[(y * width + x) * 4 + c];

      // Compare against the same scanline well clear of any connector rather
      // than against transparency: the Scaffold paints an opaque background,
      // so every pixel has full alpha and an alpha test would pass on a blank
      // image.
      const clear = 150;
      bool inked(int x, int y) => [0, 1, 2]
          .any((c) => (channel(x, y, c) - channel(clear, y, c)).abs() > 12);

      // Walk the parent's column down the height of the avatar and the turn,
      // which is where the arc leaves the column. Below that both the old and
      // new code draw the same line.
      final x = ThreadGeometry.columnFor(0).round();
      var longestGap = 0;
      var gap = 0;
      for (var y = 0; y < (Space.sm + ThreadGeometry.avatar).round(); y++) {
        gap = inked(x, y) ? 0 : gap + 1;
        if (gap > longestGap) longestGap = gap;
      }
      expect(longestGap, lessThanOrEqualTo(2),
          reason: 'a ${longestGap}px break in a rail that runs straight past');
    });

    test("a passing parent rail is not notched by its child's elbow", () async {
      // The elbow's path leaves the parent's column at `turnY - radius` to
      // make its curve. Starting the continuation at `turnY` therefore left a
      // hole one radius tall in a rail that runs straight past this row —
      // invisible to any assertion on the plan, because both pieces are
      // present and correct. Only the pixels show it.
      const size = Size(160, 90);
      final recorder = ui.PictureRecorder();
      ThreadConnectorPainter(
        depth: 1,
        ancestorRails: const [false],
        hasChildrenBelow: false,
        // A middle child: the parent has another answer still to come.
        isLastChild: false,
        avatarSize: ThreadGeometry.avatar,
        topGap: Space.sm,
        color: const Color(0xFF000000),
      ).paint(Canvas(recorder), size);
      final image = await recorder
          .endRecording()
          .toImage(size.width.toInt(), size.height.toInt());
      final data = await image.toByteData();

      final x = ThreadGeometry.columnFor(0).round();
      int alphaAt(int y) =>
          data!.getUint8(((y * size.width.toInt()) + x) * 4 + 3);

      final blank = [
        for (var y = 0; y < size.height.toInt(); y++)
          if (alphaAt(y) < 20) y,
      ];
      expect(
        blank,
        isEmpty,
        reason: 'the parent rail has holes at y=$blank, so it reads as a '
            'dashed line rather than one that carries on past this reply',
      );
    });

    test('a row given a top gap moves its elbow down to keep it on the avatar',
        () {
      // The gap has to shift what the strip draws, not just what it lays out,
      // or the elbow arrives above the face it is pointing at.
      ThreadConnectorPlan planWith(double gap) => ThreadConnectorPlan.forRow(
            depth: 1,
            ancestorRails: const [false],
            hasChildrenBelow: true,
            isLastChild: true,
            avatarSize: ThreadGeometry.avatar,
            topGap: gap,
          );

      final flush = planWith(0);
      final gapped = planWith(Space.sm);

      expect(gapped.elbow!.turnY, flush.elbow!.turnY + Space.sm);
      expect(gapped.ownRailTop, flush.ownRailTop + Space.sm);
      // Columns are unaffected — a vertical nudge must not move anything
      // sideways.
      expect(gapped.elbow!.x, flush.elbow!.x);
      expect(gapped.ownRailX, flush.ownRailX);
    });
  });

  group('verified', () {
    test('only the official post author qualifies', () {
      expect(AppConfig.isVerifiedAuthor('omnia'), isTrue);
      expect(AppConfig.isVerifiedAuthor('Omnia'), isTrue);
      expect(AppConfig.isVerifiedAuthor('  omnia  '), isTrue);
      expect(AppConfig.isVerifiedAuthor('omnia team'), isFalse);
      expect(AppConfig.isVerifiedAuthor('0mnia'), isFalse);
      expect(AppConfig.isVerifiedAuthor(null), isFalse);
    });

    testWidgets('a reply cannot wear a tick by taking the name',
        (tester) async {
      // A reply's author_name is free text chosen by whoever is signed in.
      // If replies were verified by name, setting a display name to "omnia"
      // would be all it took to impersonate the team.
      await pump(tester, [r('imposter', name: 'omnia')]);

      expect(find.text('omnia'), findsOneWidget);
      expect(find.byType(VerifiedBadge), findsNothing,
          reason: 'a reply author verified itself by changing its name');
    });

    testWidgets('the badge renders when asked', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OmniaTheme.light(),
          home: const Scaffold(
            body: ThreadHeader(name: 'omnia', timestamp: '8h', verified: true),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(VerifiedBadge), findsOneWidget);
    });
  });
}
