import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';

/// Social providers offered on the sign-in screen (must be enabled in the
/// Supabase project's Auth settings — they are, per the web dashboard).
enum SocialProvider { google, github }

/// Thin seam over `supabase_flutter` so auth logic and tests don't touch the
/// real SDK (which needs platform channels and a one-time global init).
abstract class SupabaseGateway {
  /// Whether Supabase was initialised at app start (config present + init OK).
  bool get isAvailable;

  bool get isSignedIn;

  String? get userEmail;

  /// The signed-in Supabase user's id (`auth.uid()`), or null.
  String? get userId;

  /// Best available username from the account's metadata — GitHub gives
  /// `user_name`/`preferred_username`, Google gives `name`/`full_name`.
  String? get userName;

  /// A valid Supabase access token, refreshing the session if needed.
  /// Throws [StateError] when not signed in.
  Future<String> accessToken();

  /// Launches the OAuth flow in an external browser; completion arrives
  /// asynchronously via the deep link + [signedIn] stream.
  Future<void> signInWithSocial(SocialProvider provider);

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signOut();

  /// Emits whenever a session becomes available (e.g. the OAuth redirect
  /// completed).
  Stream<void> get signedIn;

  /// Emits whenever any row in [table] is inserted, updated or deleted.
  ///
  /// Deliberately carries no payload. A tick is enough to refetch, and a
  /// refetch is correct even when several events arrive at once or one is
  /// dropped — reconciling individual row deltas client-side is a source of
  /// drift that a re-read never has.
  ///
  /// The channel is opened when the stream gets its first listener and torn
  /// down when the last one goes, so a screen nobody is looking at costs
  /// nothing.
  Stream<void> tableChanges(String table);

  /// The signed-in account's stored profile, or null when there is no row or
  /// nobody is signed in.
  ///
  /// Lives on `user_dids` beside the account's DID, which is the same row the
  /// web interface reads and writes — one profile, whichever way you sign in.
  Future<RemoteProfile?> fetchProfile();

  /// Write the parts of the profile that were passed.
  ///
  /// A field left null is left alone rather than cleared, so setting a name
  /// cannot silently drop a picture. [clearAvatar] is the explicit way to
  /// remove one, since null cannot mean both "leave it" and "delete it".
  Future<void> saveProfile({
    String? displayName,
    String? avatarUrl,
    bool clearAvatar = false,
  });

  /// Upload profile-picture bytes and return their public URL.
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  });

  /// Notifications addressed to the signed-in account, newest first.
  ///
  /// Empty when signed out: these are written by the database for a specific
  /// user, so there is nothing to read without a session.
  Future<List<RemoteNotice>> fetchNotifications({int limit = 50});

  /// Mark every unread notification as read, server-side.
  Future<void> markNotificationsRead();

  /// Delete every notification for this account.
  Future<void> clearNotifications();

  /// Record this handset as a delivery address for the signed-in account.
  ///
  /// Upserts on the token, so a handset that signs out and back in as somebody
  /// else moves to the new account rather than notifying both.
  Future<void> registerDevice({
    required String token,
    required String platform,
  });

  /// Forget this handset — called on sign-out, so a shared device stops
  /// receiving the previous account's replies.
  Future<void> unregisterDevice(String token);
}

/// One row of the `notifications` table.
class RemoteNotice {
  const RemoteNotice({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.link,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  /// A path like `/post/<uuid>`. The trailing segment is the subject.
  final String? link;

  /// The id at the end of [link], or null.
  ///
  /// The table has no subject column, so the route carries it. Parsing it here
  /// rather than at the call site keeps the one place that knows the shape of
  /// that string next to the field it comes from.
  String? get subjectId {
    final path = link;
    if (path == null || path.isEmpty) return null;
    final last = path.split('/').where((s) => s.isNotEmpty).lastOrNull;
    return (last == null || last.isEmpty) ? null : last;
  }
}

/// What the backend holds about a user's presentation.
class RemoteProfile {
  const RemoteProfile({this.displayName, this.avatarUrl});

  final String? displayName;
  final String? avatarUrl;

  bool get isEmpty =>
      (displayName == null || displayName!.isEmpty) &&
      (avatarUrl == null || avatarUrl!.isEmpty);
}

/// Production implementation backed by `supabase_flutter`.
class SupabaseFlutterGateway implements SupabaseGateway {
  static bool _initialized = false;

  /// Call once before `runApp`. A failure only disables Mode B sign-in —
  /// never blocks app launch (Mode A is fully local).
  static Future<void> init() async {
    if (_initialized || !AppConfig.supabaseConfigured) return;
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // The project uses a legacy JWT anon key, which this parameter still
        // accepts (`publishableKey` is for the new sb_publishable_* keys).
        // ignore: deprecated_member_use
        anonKey: AppConfig.supabaseAnonKey,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('Supabase init failed — sign-in disabled: $e');
    }
  }

  SupabaseClient get _client {
    if (!_initialized) {
      throw StateError('Sign-in is unavailable — Supabase is not configured.');
    }
    return Supabase.instance.client;
  }

  @override
  bool get isAvailable => _initialized;

  @override
  bool get isSignedIn => _initialized && _client.auth.currentSession != null;

  @override
  String? get userEmail =>
      _initialized ? _client.auth.currentUser?.email : null;

  @override
  String? get userId => _initialized ? _client.auth.currentUser?.id : null;

  @override
  String? get userName {
    if (!_initialized) return null;
    final meta = _client.auth.currentUser?.userMetadata;
    if (meta == null) return null;
    for (final key in [
      'user_name',
      'preferred_username',
      'name',
      'full_name',
    ]) {
      final value = meta[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  /// In-flight refresh, so concurrent callers share one request.
  ///
  /// The feed asks for a token far more often than it used to — reaction
  /// counts, reaction writes, replies — and several of those can land in the
  /// same frame. Supabase rotates the refresh token on every use, so two
  /// refreshes racing means the second presents a token the first already
  /// consumed: the server answers "Already Used", gotrue drops the session,
  /// and the user is signed out for no reason they can see. One request at a
  /// time removes that entirely.
  Future<String>? _refreshing;

  @override
  Future<String> accessToken() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw StateError('Not signed in — sign in with your Omnia account.');
    }
    // A token good for at least another minute is worth using as-is. Cutting
    // it fine means a request that is valid when sent and expired when it
    // arrives.
    if (!session.isExpired &&
        (session.expiresAt ?? 0) >
            DateTime.now()
                    .add(const Duration(minutes: 1))
                    .millisecondsSinceEpoch ~/
                1000) {
      return session.accessToken;
    }
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<String> _refresh() async {
    try {
      final refreshed = await _client.auth.refreshSession();
      final token = refreshed.session?.accessToken;
      if (token == null) {
        throw StateError('Your session expired. Please sign in again.');
      }
      return token;
    } on AuthException catch (e) {
      // The refresh token is gone or already spent. There is no recovering
      // from this in the client, and saying so plainly beats a bare
      // "Session expired" that gives no idea what to do.
      throw StateError(
        'Your Omnia session has ended (${e.message}). Sign in again to '
        'continue.',
      );
    }
  }

  @override
  Future<void> signInWithSocial(SocialProvider provider) async {
    await _client.auth.signInWithOAuth(
      provider == SocialProvider.google
          ? OAuthProvider.google
          : OAuthProvider.github,
      redirectTo: AppConfig.oauthRedirectUri,
      // A Custom Tab (SFSafariViewController on iOS), not the standalone
      // browser app.
      //
      // `externalApplication` hands the flow to the browser as a separate
      // task, and when the provider redirects to `io.omnia.wallet://…` the
      // browser cannot close itself — the tab survives, so *every later
      // launch of the browser* reopens that URL and Android asks again
      // whether to open Omnia. It also means the return trip depends on the
      // app still being alive in the background.
      //
      // A Custom Tab is still the real browser — Google refuses embedded
      // webviews, and this is not one — but it belongs to this app's task, is
      // dismissed the moment the redirect fires, and leaves nothing behind.
      authScreenLaunchMode: LaunchMode.inAppBrowserView,
    );
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Stream<void> get signedIn => _client.auth.onAuthStateChange
      .where((s) =>
          s.event == AuthChangeEvent.signedIn ||
          (s.event == AuthChangeEvent.initialSession && s.session != null))
      .map((_) {});

  @override
  Stream<void> tableChanges(String table) {
    // Without Supabase configured there is nothing to listen to, and the feed
    // still reads fine over the anon REST key — so an empty stream, not a
    // throw.
    if (!_initialized) return const Stream<void>.empty();

    late final StreamController<void> controller;
    RealtimeChannel? channel;

    controller = StreamController<void>.broadcast(
      onListen: () {
        channel = _client.channel('public:$table')
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            callback: (_) {
              if (!controller.isClosed) controller.add(null);
            },
          )
          ..subscribe();
      },
      onCancel: () async {
        final open = channel;
        channel = null;
        if (open != null) await _client.removeChannel(open);
      },
    );

    return controller.stream;
  }

  @override
  Future<RemoteProfile?> fetchProfile() async {
    final uid = userId;
    if (!_initialized || uid == null) return null;
    final row = await _client
        .from('user_dids')
        .select('display_name, avatar_url')
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;
    return RemoteProfile(
      displayName: row['display_name'] as String?,
      avatarUrl: row['avatar_url'] as String?,
    );
  }

  @override
  Future<void> saveProfile({
    String? displayName,
    String? avatarUrl,
    bool clearAvatar = false,
  }) async {
    final uid = userId;
    if (!_initialized || uid == null) {
      throw StateError('Not signed in');
    }
    final patch = <String, dynamic>{
      if (displayName != null) 'display_name': displayName,
      if (clearAvatar)
        'avatar_url': null
      else if (avatarUrl != null)
        'avatar_url': avatarUrl,
    };
    if (patch.isEmpty) return;

    // Update rather than upsert: the row is created at signup and carries the
    // account's DID, which is immutable and is what mint-node-jwt looks up. An
    // upsert would have to invent a value for it.
    await _client.from('user_dids').update(patch).eq('user_id', uid);
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final uid = userId;
    if (!_initialized || uid == null) {
      throw StateError('Not signed in');
    }
    // The uid folder is what the storage policy checks; a fresh file name per
    // upload is what stops a CDN — or Flutter's image cache — from serving the
    // previous picture after a change.
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: fileExtension == 'png' ? 'image/png' : 'image/jpeg',
            upsert: true,
          ),
        );
    return _client.storage.from('avatars').getPublicUrl(path);
  }

  @override
  Future<List<RemoteNotice>> fetchNotifications({int limit = 50}) async {
    if (!_initialized || userId == null) return const [];
    // No user_id filter: the SELECT policy already restricts this to the
    // caller's own rows, and repeating it in the query would only mean two
    // places to keep right.
    final rows = await _client
        .from('notifications')
        .select('id, kind, title, body, link, read_at, created_at')
        .order('created_at', ascending: false)
        .limit(limit);

    return [
      for (final row in rows)
        RemoteNotice(
          id: row['id'] as String,
          kind: (row['kind'] as String?) ?? 'news',
          title: (row['title'] as String?) ?? '',
          body: (row['body'] as String?) ?? '',
          link: row['link'] as String?,
          read: row['read_at'] != null,
          createdAt: DateTime.tryParse(row['created_at'] as String? ?? '')
                  ?.toLocal() ??
              DateTime.now(),
        ),
    ];
  }

  @override
  Future<void> markNotificationsRead() async {
    final uid = userId;
    if (!_initialized || uid == null) return;
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', uid)
        .isFilter('read_at', null);
  }

  @override
  Future<void> clearNotifications() async {
    final uid = userId;
    if (!_initialized || uid == null) return;
    await _client.from('notifications').delete().eq('user_id', uid);
  }

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
  }) async {
    final uid = userId;
    if (!_initialized || uid == null) return;
    await _client.from('device_tokens').upsert({
      'token': token,
      'user_id': uid,
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }

  @override
  Future<void> unregisterDevice(String token) async {
    if (!_initialized) return;
    await _client.from('device_tokens').delete().eq('token', token);
  }
}
