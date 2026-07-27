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
