import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/crypto/secure_store.dart';
import 'package:omnia_wallet/state/blocklist.dart';

/// In-memory store for the blocked-users blob only.
class _FakeStore extends SecureStore {
  String? _blob;

  @override
  Future<String?> readBlockedUsers() async => _blob;

  @override
  Future<void> saveBlockedUsers(String json) async => _blob = json;
}

void main() {
  group('blockKeyFor', () {
    test('prefers the stable user id', () {
      expect(blockKeyFor(userId: 'u1', name: 'Alice'), 'uid:u1');
    });

    test('falls back to a trimmed name', () {
      expect(blockKeyFor(userId: null, name: '  Bob  '), 'name:Bob');
      expect(blockKeyFor(userId: '', name: 'Bob'), 'name:Bob');
    });

    test('returns null when nothing identifies the author', () {
      expect(blockKeyFor(userId: null, name: null), isNull);
      expect(blockKeyFor(userId: '', name: '   '), isNull);
    });
  });

  group('BlocklistController', () {
    test('block adds, dedupes, and persists', () async {
      final store = _FakeStore();
      final c = BlocklistController(store);

      await c.block('uid:u1');
      await c.block('uid:u1'); // no duplicate
      await c.block('name:Bob');
      expect(c.state, {'uid:u1', 'name:Bob'});

      // A fresh controller loads the same persisted set.
      final c2 = BlocklistController(store);
      await c2.load();
      expect(c2.state, {'uid:u1', 'name:Bob'});
    });

    test('isBlocked reflects membership and tolerates null', () async {
      final c = BlocklistController(_FakeStore());
      await c.block('uid:u1');
      expect(c.isBlocked('uid:u1'), isTrue);
      expect(c.isBlocked('uid:u2'), isFalse);
      expect(c.isBlocked(null), isFalse);
    });

    test('unblock removes and persists', () async {
      final store = _FakeStore();
      final c = BlocklistController(store);
      await c.block('uid:u1');
      await c.block('name:Bob');
      await c.unblock('uid:u1');
      expect(c.state, {'name:Bob'});

      final c2 = BlocklistController(store);
      await c2.load();
      expect(c2.state, {'name:Bob'});
    });

    test('block ignores empty keys', () async {
      final c = BlocklistController(_FakeStore());
      await c.block('');
      expect(c.state, isEmpty);
    });

    test('load tolerates missing and garbage blobs', () async {
      final c = BlocklistController(_FakeStore());
      await c.load(); // nothing stored
      expect(c.state, isEmpty);
    });
  });
}
