import 'package:flutter/material.dart';
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
