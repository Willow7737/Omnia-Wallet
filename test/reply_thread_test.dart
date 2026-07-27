import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/core/theme.dart';
import 'package:omnia_wallet/core/ui/thread.dart';
import 'package:omnia_wallet/data/news.dart';
import 'package:omnia_wallet/features/news/reply_thread.dart';

/// The thread widget's job is to turn the layout into rows without losing any
/// of them and without indenting past the edge of the screen. The connector
/// geometry itself is pinned in `thread_layout_test.dart`; this is about what
/// actually gets built.
void main() {
  NewsReply r(String id, {String? parent, String? userId}) => NewsReply(
        id: id,
        postId: 'p',
        authorName: id,
        authorDid: 'did:omnia:$id',
        body: 'body of $id',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        parentId: parent,
        userId: userId,
      );

  Future<void> pump(
    WidgetTester tester,
    List<NewsReply> replies, {
    Set<String> blocked = const {},
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
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
                blocked: blocked,
                canInteract: true,
                onReply: (_) {},
                onMenu: (_, {required bool isMine}) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Answers are folded until asked for, so a test about nesting has to open
  /// the thread the way a reader would — one "Show replies" at a time.
  Future<void> openAll(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      final more = find.text('Show replies');
      if (more.evaluate().isEmpty) return;
      await tester.tap(more.first);
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  testWidgets('renders a reply to a reply to a reply', (tester) async {
    // Unbounded nesting was the ask; the old widget only handled one level and
    // silently flattened everything below it.
    await pump(tester, [
      r('a'),
      r('b', parent: 'a'),
      r('c', parent: 'b'),
      r('d', parent: 'c'),
    ]);
    await openAll(tester);

    expect(find.byType(ThreadItem), findsNWidgets(4));
    for (final id in ['a', 'b', 'c', 'd']) {
      expect(find.text('body of $id'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('each level starts further right than the one above',
      (tester) async {
    await pump(tester, [r('a'), r('b', parent: 'a'), r('c', parent: 'b')]);
    await openAll(tester);

    final a = tester.getRect(find.text('body of a')).left;
    final b = tester.getRect(find.text('body of b')).left;
    final c = tester.getRect(find.text('body of c')).left;
    expect(b, greaterThan(a));
    expect(c, greaterThan(b));
  });

  testWidgets('a deep thread stops indenting instead of running off the edge',
      (tester) async {
    final chain = <NewsReply>[r('n0')];
    for (var i = 1; i < 12; i++) {
      chain.add(r('n$i', parent: 'n${i - 1}'));
    }
    await pump(tester, chain, width: 320);
    await openAll(tester);

    final deepest = tester.getRect(find.text('body of n11'));
    expect(deepest.right, lessThanOrEqualTo(320),
        reason: 'the deepest reply has run off the screen');
    expect(tester.takeException(), isNull);
  });

  testWidgets('holds back a long run of answers behind a "show more" row',
      (tester) async {
    await pump(tester, [
      r('a'),
      for (var i = 0; i < 6; i++) r('answer$i', parent: 'a'),
    ]);

    // Folded by default — none of the answers are on screen.
    expect(find.text('body of answer0'), findsNothing);
    expect(find.text('body of answer5'), findsNothing);
    expect(find.text('Show replies'), findsOneWidget);

    await tester.tap(find.text('Show replies'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('body of answer0'), findsOneWidget);
    expect(find.text('body of answer5'), findsOneWidget);
  });

  testWidgets('a blocked author takes their sub-thread with them',
      (tester) async {
    await pump(
      tester,
      [r('a'), r('b', parent: 'a', userId: 'u-blocked'), r('c')],
      blocked: {'uid:u-blocked'},
    );

    expect(find.text('body of b'), findsNothing);
    // And the replies either side are untouched.
    expect(find.text('body of a'), findsOneWidget);
    expect(find.text('body of c'), findsOneWidget);
  });

  testWidgets('says so when there is nothing to show', (tester) async {
    await pump(tester, const []);
    expect(find.text('No replies yet'), findsOneWidget);
  });

  testWidgets('survives a narrow screen at a large text size', (tester) async {
    // The worst case for a threaded layout: every level takes width away, and
    // large text takes the rest. This is where an un-shrinkable label or
    // action row overflows.
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: OmniaTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 1600),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ThreadedReplies(
                  replies: [
                    r('a'),
                    r('b', parent: 'a'),
                    r('c', parent: 'b'),
                    r('d', parent: 'c'),
                    for (var i = 0; i < 6; i++) r('e$i', parent: 'd'),
                  ],
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
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
