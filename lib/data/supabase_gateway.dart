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
      authScreenLaunchMode: LaunchMode.externalApplication,
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
}
