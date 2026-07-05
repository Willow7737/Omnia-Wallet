import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crypto/secure_store.dart';
import '../data/contact.dart';
import 'providers.dart';

/// Manages the local address book. Contacts live only on this device (secure
/// storage) — nothing is sent to the node.
class ContactsController extends StateNotifier<List<Contact>> {
  ContactsController(this._store) : super(const []);

  final SecureStore _store;

  Future<void> load() async {
    state = Contact.decodeList(await _store.readContacts());
  }

  Future<void> _persist() async {
    await _store.saveContacts(Contact.encodeList(state));
  }

  /// Add or update by DID. Labels are trimmed; a blank label falls back to the
  /// DID's short form handled at display time.
  Future<void> upsert(Contact contact) async {
    final normalized = contact.copyWith(
      label: contact.label.trim(),
      did: contact.did.trim(),
    );
    final idx = state.indexWhere((c) => c.did == normalized.did);
    state = [
      if (idx >= 0)
        for (var i = 0; i < state.length; i++)
          if (i == idx) normalized else state[i]
      else ...[...state, normalized],
    ];
    await _persist();
  }

  Future<void> remove(String did) async {
    state = state.where((c) => c.did != did).toList();
    await _persist();
  }

  Contact? byDid(String did) {
    for (final c in state) {
      if (c.did == did) return c;
    }
    return null;
  }
}

final contactsProvider =
    StateNotifierProvider<ContactsController, List<Contact>>((ref) {
  final controller = ContactsController(ref.watch(secureStoreProvider));
  controller.load();
  return controller;
});
