import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crypto/secure_store.dart';
import 'providers.dart';

/// Locally-maintained set of blocked authors (content moderation).
///
/// Blocking is **client-side only** — the blocked identifiers live in secure
/// storage on this device and are never sent to the node or Supabase. A
/// blocked author's posts and replies are hidden from this user's feed.
///
/// Identifiers are opaque strings: prefer the author's stable Supabase
/// `user_id` when known, otherwise fall back to their display name. Use
/// [blockKeyFor] to derive a consistent key for a reply/author.
class BlocklistController extends StateNotifier<Set<String>> {
  BlocklistController(this._store) : super(const {});

  final SecureStore _store;

  Future<void> load() async {
    final raw = await _store.readBlockedUsers();
    if (raw == null || raw.isEmpty) {
      state = const {};
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        state = decoded.whereType<String>().toSet();
      }
    } catch (_) {
      state = const {};
    }
  }

  Future<void> _persist() async {
    await _store.saveBlockedUsers(jsonEncode(state.toList()));
  }

  bool isBlocked(String? key) => key != null && state.contains(key);

  Future<void> block(String key) async {
    if (key.isEmpty || state.contains(key)) return;
    state = {...state, key};
    await _persist();
  }

  Future<void> unblock(String key) async {
    if (!state.contains(key)) return;
    state = state.where((k) => k != key).toSet();
    await _persist();
  }
}

/// Derive a stable block key from a Supabase user id (preferred) or a name.
String? blockKeyFor({String? userId, String? name}) {
  if (userId != null && userId.isNotEmpty) return 'uid:$userId';
  if (name != null && name.trim().isNotEmpty) return 'name:${name.trim()}';
  return null;
}

final blocklistProvider =
    StateNotifierProvider<BlocklistController, Set<String>>((ref) {
  final controller = BlocklistController(ref.watch(secureStoreProvider));
  controller.load();
  return controller;
});
