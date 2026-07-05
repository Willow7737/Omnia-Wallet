import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/crypto/secure_store.dart';
import 'package:omnia_wallet/data/contact.dart';
import 'package:omnia_wallet/state/contacts.dart';

/// In-memory store for the contacts blob only.
class _FakeStore extends SecureStore {
  String? _blob;

  @override
  Future<String?> readContacts() async => _blob;

  @override
  Future<void> saveContacts(String json) async => _blob = json;
}

void main() {
  const a = Contact(label: 'Alice', did: 'did:omnia:aaaa');
  const b = Contact(label: 'Bob', did: 'did:omnia:bbbb');

  group('Contact serialization', () {
    test('round-trips through encode/decode', () {
      final encoded = Contact.encodeList([a, b]);
      final decoded = Contact.decodeList(encoded);
      expect(decoded.length, 2);
      expect(decoded[0].label, 'Alice');
      expect(decoded[1].did, 'did:omnia:bbbb');
    });

    test('decodes null/garbage to empty', () {
      expect(Contact.decodeList(null), isEmpty);
      expect(Contact.decodeList(''), isEmpty);
      expect(Contact.decodeList('not json'), isEmpty);
    });
  });

  group('ContactsController', () {
    test('upsert adds, updates by DID, and persists', () async {
      final store = _FakeStore();
      final c = ContactsController(store);

      await c.upsert(a);
      await c.upsert(b);
      expect(c.state.length, 2);

      // Same DID updates in place (label change), does not duplicate.
      await c.upsert(const Contact(label: 'Alice A.', did: 'did:omnia:aaaa'));
      expect(c.state.length, 2);
      expect(c.byDid('did:omnia:aaaa')?.label, 'Alice A.');

      // Persisted: a fresh controller loads the same data.
      final c2 = ContactsController(store);
      await c2.load();
      expect(c2.state.length, 2);
      expect(c2.byDid('did:omnia:aaaa')?.label, 'Alice A.');
    });

    test('remove deletes by DID', () async {
      final store = _FakeStore();
      final c = ContactsController(store);
      await c.upsert(a);
      await c.upsert(b);
      await c.remove('did:omnia:aaaa');
      expect(c.state.length, 1);
      expect(c.byDid('did:omnia:aaaa'), isNull);
      expect(c.byDid('did:omnia:bbbb'), isNotNull);
    });

    test('labels and dids are trimmed on upsert', () async {
      final c = ContactsController(_FakeStore());
      await c
          .upsert(const Contact(label: '  Carol  ', did: ' did:omnia:cccc '));
      expect(c.state.single.label, 'Carol');
      expect(c.state.single.did, 'did:omnia:cccc');
    });
  });
}
