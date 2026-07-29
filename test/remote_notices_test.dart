import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:omnia_wallet/crypto/secure_store.dart';
import 'package:omnia_wallet/data/supabase_gateway.dart';
import 'package:omnia_wallet/state/notices.dart';

import 'support/fake_gateway.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

/// The notification feed has two sources now — this device, and the account —
/// and the rules for combining them are the part that can go quietly wrong.
void main() {
  late _MockStorage storage;
  late Map<String, String> disk;
  late FakeGatewayBase gateway;
  late NoticesNotifier notifier;

  RemoteNotice remote(
    String id, {
    String kind = 'reply',
    String link = '/post/post-1',
    bool read = false,
    Duration ago = Duration.zero,
  }) =>
      RemoteNotice(
        id: id,
        kind: kind,
        title: 'Willow replied to you',
        body: 'a reply',
        link: link,
        read: read,
        createdAt: DateTime.now().subtract(ago),
      );

  setUp(() {
    storage = _MockStorage();
    disk = {};
    when(() =>
            storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((inv) async {
      final value = inv.namedArguments[#value] as String?;
      if (value == null) {
        disk.remove(inv.namedArguments[#key] as String);
      } else {
        disk[inv.namedArguments[#key] as String] = value;
      }
    });
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((inv) async => disk[inv.namedArguments[#key] as String]);
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer(
        (inv) async => disk.remove(inv.namedArguments[#key] as String));

    gateway = FakeGatewayBase();
    notifier = NoticesNotifier(SecureStore(storage), gateway);
  });

  test('a reply notification becomes a tappable notice', () async {
    gateway.notifications = [remote('n1')];

    await notifier.syncRemote();

    final notice = notifier.state.single;
    expect(notice.type, NoticeType.reply);
    expect(notice.title, 'Willow replied to you');
    // The table has no subject column, so the route carries the post id and
    // the notice has to be able to open it.
    expect(notice.subjectId, 'post-1');
    expect(notice.destination, '/news');
  });

  test('nothing is fetched when signed out', () async {
    gateway.authenticated = false;
    await notifier.syncRemote();
    expect(gateway.notificationFetches, 0);
    expect(notifier.state, isEmpty);
  });

  test('backend notices are never written to the local cache', () async {
    // Both halves are in one list on screen, but only one belongs on disk.
    // Persisting the remote half means the next launch shows every reply
    // twice — once from the cache, once from the sync.
    await notifier.add(type: NoticeType.sent, title: 'Sent 39 UBC', body: 'x');
    gateway.notifications = [remote('n1')];
    await notifier.syncRemote();

    expect(notifier.state.length, 2);

    final cached = (jsonDecode(disk['omnia.wallet.notices']!) as List)
        .cast<Map<String, dynamic>>();
    expect(cached.length, 1);
    expect(cached.single['title'], 'Sent 39 UBC');
  });

  test('a second sync replaces the backend half rather than stacking it',
      () async {
    gateway.notifications = [remote('n1')];
    await notifier.syncRemote();
    await notifier.syncRemote();
    await notifier.syncRemote();

    expect(notifier.state.length, 1, reason: 'the same reply arrived 3 times');
  });

  test('a deleted backend notice disappears on the next sync', () async {
    gateway.notifications = [remote('n1'), remote('n2')];
    await notifier.syncRemote();
    expect(notifier.state.length, 2);

    gateway.notifications = [remote('n1')];
    await notifier.syncRemote();
    expect(notifier.state.single.id, endsWith('n1'));
  });

  test('the two sources interleave by time, not by origin', () async {
    await notifier.add(type: NoticeType.sent, title: 'newest local', body: '');
    gateway.notifications = [
      remote('old', ago: const Duration(days: 2)),
      remote('newest', ago: const Duration(seconds: 1)),
    ];

    await notifier.syncRemote();

    // The local notice was recorded just now, so it leads; the day-old reply
    // trails. A feed grouped by source would put both replies together.
    expect(notifier.state.first.title, 'newest local');
    expect(notifier.state.last.id, endsWith('old'));
  });

  test('reading clears the badge on the account too', () async {
    gateway.notifications = [remote('n1')];
    await notifier.syncRemote();
    expect(notifier.unread, 1);

    await notifier.markAllRead();

    expect(notifier.unread, 0);
    expect(gateway.markedRead, 1,
        reason: 'reading on one device must clear it on the others');
  });

  test('an already-read backend notice does not light the badge', () async {
    gateway.notifications = [remote('n1', read: true)];
    await notifier.syncRemote();
    expect(notifier.unread, 0);
  });

  test('clearing deletes on the account as well as here', () async {
    gateway.notifications = [remote('n1')];
    await notifier.syncRemote();

    await notifier.clear();

    expect(notifier.state, isEmpty);
    expect(gateway.cleared, 1);
  });

  test('clearing a purely local feed does not call the backend', () async {
    await notifier.add(type: NoticeType.sent, title: 'Sent', body: '');
    await notifier.clear();
    expect(gateway.cleared, 0);
  });
}
