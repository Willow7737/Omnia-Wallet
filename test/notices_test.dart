import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omnia_wallet/crypto/secure_store.dart';
import 'package:omnia_wallet/state/notices.dart';

class MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockStorage storage;
  late Map<String, String?> disk;
  late NoticesNotifier notifier;

  setUp(() {
    disk = {};
    storage = MockStorage();
    when(() => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((inv) async {
      disk[inv.namedArguments[#key] as String] =
          inv.namedArguments[#value] as String?;
    });
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((inv) async => disk[inv.namedArguments[#key] as String]);
    notifier = NoticesNotifier(SecureStore(storage));
  });

  group('NoticesNotifier', () {
    test('add prepends, counts unread, and persists', () async {
      await notifier.add(
          type: NoticeType.sent, title: 'Sent 5 UBC', body: 'To did:…');
      await notifier.add(
          type: NoticeType.vote, title: 'Vote recorded', body: 'for');

      expect(notifier.state.length, 2);
      expect(notifier.state.first.title, 'Vote recorded');
      expect(notifier.unread, 2);

      // Persisted round-trip: a fresh notifier loads the same feed.
      final reloaded = NoticesNotifier(SecureStore(storage));
      await Future<void>.delayed(Duration.zero);
      expect(reloaded.state.length, 2);
      expect(reloaded.state.first.type, NoticeType.vote);
    });

    test('markAllRead clears the unread count', () async {
      await notifier.add(type: NoticeType.news, title: 'Hello', body: 'World');
      expect(notifier.unread, 1);
      await notifier.markAllRead();
      expect(notifier.unread, 0);
      expect(notifier.state.single.read, isTrue);
    });

    test('feed is capped at maxEntries', () async {
      for (var i = 0; i < NoticesNotifier.maxEntries + 10; i++) {
        await notifier.add(type: NoticeType.wallet, title: 'n$i', body: 'b$i');
      }
      expect(notifier.state.length, NoticesNotifier.maxEntries);
      // Newest survives the cap.
      expect(notifier.state.first.title, 'n${NoticesNotifier.maxEntries + 9}');
    });

    test('clear empties the feed', () async {
      await notifier.add(type: NoticeType.sent, title: 't', body: 'b');
      await notifier.clear();
      expect(notifier.state, isEmpty);
      expect(notifier.unread, 0);
    });

    test('corrupt persisted JSON is ignored', () async {
      disk['omnia.wallet.notices'] = 'not-json{';
      final n = NoticesNotifier(SecureStore(storage));
      await Future<void>.delayed(Duration.zero);
      expect(n.state, isEmpty);
    });
  });
}
