import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crypto/secure_store.dart';
import '../data/supabase_gateway.dart';
import 'providers.dart';

/// What produced a notification — drives its icon/tint in the feed.
enum NoticeType { sent, vote, wallet, news, reply }

/// An in-app notification.
///
/// Two sources, one feed. The wallet records its own moments locally (a send,
/// a vote) because the node has no channel to tell it anything; replies come
/// from the backend, written by a trigger where the reply is written, so they
/// are there whether or not the app was running when they happened.
class AppNotice {
  const AppNotice({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.read = false,
    this.subjectId,
  });

  final String id;
  final NoticeType type;
  final String title;
  final String body;

  /// What this notice is *about* — a transfer id, a post id — as opposed to
  /// [id], which identifies the notice itself.
  ///
  /// Stored so a notification can open the one thing it refers to. The
  /// screens worth deep-linking to take their subject as a route `extra`
  /// object rather than a path parameter, so the id alone is not a route; the
  /// tap handler looks the subject up and falls back to the list when it is
  /// gone (an old notice whose transfer has aged out of the log).
  final String? subjectId;

  /// Unix-millisecond timestamp.
  final int timestamp;
  final bool read;

  /// Where tapping this notice lands when its subject cannot be resolved —
  /// the list the subject would have been in. A notification you cannot act
  /// on is just a receipt.
  String get destination => switch (type) {
        NoticeType.sent => '/activity',
        NoticeType.vote => '/governance',
        NoticeType.wallet => '/settings',
        NoticeType.news || NoticeType.reply => '/news',
      };

  /// Whether this came from the backend rather than being recorded on this
  /// device. Remote notices are re-read on every sync, so they must not be
  /// persisted into the local cache as well — one of the two copies would
  /// always be the stale one.
  bool get isRemote => id.startsWith(remoteIdPrefix);

  static const String remoteIdPrefix = 'remote:';

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  /// Build from a backend row.
  factory AppNotice.fromRemote(RemoteNotice remote) => AppNotice(
        // Namespaced so a backend uuid can never collide with a locally
        // generated timestamp id, and so the merge can tell them apart.
        id: '$remoteIdPrefix${remote.id}',
        type: remote.kind == 'reply' ? NoticeType.reply : NoticeType.news,
        title: remote.title,
        body: remote.body,
        timestamp: remote.createdAt.millisecondsSinceEpoch,
        subjectId: remote.subjectId,
        read: remote.read,
      );

  AppNotice asRead() => AppNotice(
        id: id,
        type: type,
        title: title,
        body: body,
        timestamp: timestamp,
        subjectId: subjectId,
        read: true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'body': body,
        'timestamp': timestamp,
        'read': read,
        'subjectId': subjectId,
      };

  factory AppNotice.fromJson(Map<String, dynamic> json) => AppNotice(
        id: json['id'] as String? ?? '',
        type: NoticeType.values.asNameMap()[json['type']] ?? NoticeType.wallet,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
        read: json['read'] as bool? ?? false,
        // Absent on notices written before subjects were recorded; those fall
        // back to the list, which is what they always did.
        subjectId: json['subjectId'] as String?,
      );
}

/// Notification feed: newest first, capped at [maxEntries].
///
/// Locally recorded notices are persisted; backend ones are not, because they
/// are re-read on every sync and a second copy on disk could only ever be the
/// stale one. [_merge] is what keeps the two in one ordered list.
class NoticesNotifier extends StateNotifier<List<AppNotice>> {
  NoticesNotifier(this._store, this._gateway) : super(const []) {
    _load();
  }

  static const int maxEntries = 50;

  final SecureStore _store;
  final SupabaseGateway _gateway;

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

  /// Only the device's own notices go to disk.
  Future<void> _persist() async {
    await _store.saveNotices(
      jsonEncode([
        for (final n in state)
          if (!n.isRemote) n.toJson(),
      ]),
    );
  }

  /// Replace the backend's half of the feed with what it currently holds.
  ///
  /// Deliberately a wholesale replace rather than an append: the server is the
  /// authority on which replies exist and which have been read, and merging
  /// row-by-row is how the two ends drift.
  Future<void> syncRemote() async {
    if (!_gateway.isSignedIn) return;
    try {
      final remote = await _gateway.fetchNotifications(limit: maxEntries);
      if (!mounted) return;
      _merge([for (final r in remote) AppNotice.fromRemote(r)]);
    } catch (_) {
      // Offline, or not readable. The local half of the feed still stands.
    }
  }

  void _merge(List<AppNotice> remote) {
    final local = [
      for (final n in state)
        if (!n.isRemote) n,
    ];
    state = [...local, ...remote]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (state.length > maxEntries) {
      state = state.take(maxEntries).toList();
    }
  }

  int get unread => state.where((n) => !n.read).length;

  Future<void> add({
    required NoticeType type,
    required String title,
    required String body,
    String? subjectId,
  }) async {
    final notice = AppNotice(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      title: title,
      body: body,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      subjectId: subjectId,
    );
    state = [notice, ...state].take(maxEntries).toList();
    await _persist();
  }

  Future<void> markAllRead() async {
    if (state.every((n) => n.read)) return;
    state = [for (final n in state) n.read ? n : n.asRead()];
    await _persist();
    // The badge is per account, not per handset: reading on one device has to
    // clear it on the others too.
    if (state.any((n) => n.isRemote)) {
      try {
        await _gateway.markNotificationsRead();
      } catch (_) {
        // The local state already reflects it; the next sync reconciles.
      }
    }
  }

  Future<void> clear() async {
    final hadRemote = state.any((n) => n.isRemote);
    state = const [];
    await _persist();
    if (hadRemote) {
      try {
        await _gateway.clearNotifications();
      } catch (_) {
        // They come back on the next sync, which is the honest outcome of a
        // delete that did not reach the server.
      }
    }
  }
}

final noticesProvider =
    StateNotifierProvider<NoticesNotifier, List<AppNotice>>((ref) {
  final notifier = NoticesNotifier(
    ref.watch(secureStoreProvider),
    ref.watch(supabaseGatewayProvider),
  );
  // A reply landing while the app is open should appear without a pull.
  final sub = ref
      .watch(supabaseGatewayProvider)
      .tableChanges('notifications')
      .listen((_) => notifier.syncRemote());
  ref.onDispose(sub.cancel);
  notifier.syncRemote();
  return notifier;
});

/// Unread count for the Home bell badge.
final unreadNoticesProvider = Provider<int>((ref) {
  return ref.watch(noticesProvider).where((n) => !n.read).length;
});
