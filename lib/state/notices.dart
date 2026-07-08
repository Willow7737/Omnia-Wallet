import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crypto/secure_store.dart';
import 'providers.dart';

/// What produced a notification — drives its icon/tint in the feed.
enum NoticeType { sent, vote, wallet, news }

/// An in-app notification. Stored locally (newest first, capped) — the node
/// has no push channel, so the wallet records its own noteworthy moments.
class AppNotice {
  const AppNotice({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.read = false,
  });

  final String id;
  final NoticeType type;
  final String title;
  final String body;

  /// Unix-millisecond timestamp.
  final int timestamp;
  final bool read;

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  AppNotice asRead() => AppNotice(
        id: id,
        type: type,
        title: title,
        body: body,
        timestamp: timestamp,
        read: true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'body': body,
        'timestamp': timestamp,
        'read': read,
      };

  factory AppNotice.fromJson(Map<String, dynamic> json) => AppNotice(
        id: json['id'] as String? ?? '',
        type: NoticeType.values.asNameMap()[json['type']] ?? NoticeType.wallet,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
        read: json['read'] as bool? ?? false,
      );
}

/// Notification feed: newest first, persisted, capped at [maxEntries].
class NoticesNotifier extends StateNotifier<List<AppNotice>> {
  NoticesNotifier(this._store) : super(const []) {
    _load();
  }

  static const int maxEntries = 50;

  final SecureStore _store;

  Future<void> _load() async {
    final raw = await _store.readNotices();
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(AppNotice.fromJson)
          .toList();
      if (mounted) state = list;
    } catch (_) {
      // Corrupt cache — start fresh rather than crash.
    }
  }

  Future<void> _persist() async {
    await _store.saveNotices(jsonEncode(state.map((n) => n.toJson()).toList()));
  }

  int get unread => state.where((n) => !n.read).length;

  Future<void> add({
    required NoticeType type,
    required String title,
    required String body,
  }) async {
    final notice = AppNotice(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      title: title,
      body: body,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    state = [notice, ...state].take(maxEntries).toList();
    await _persist();
  }

  Future<void> markAllRead() async {
    if (state.every((n) => n.read)) return;
    state = [for (final n in state) n.read ? n : n.asRead()];
    await _persist();
  }

  Future<void> clear() async {
    state = const [];
    await _persist();
  }
}

final noticesProvider =
    StateNotifierProvider<NoticesNotifier, List<AppNotice>>((ref) {
  return NoticesNotifier(ref.watch(secureStoreProvider));
});

/// Unread count for the Home bell badge.
final unreadNoticesProvider = Provider<int>((ref) {
  return ref.watch(noticesProvider).where((n) => !n.read).length;
});
