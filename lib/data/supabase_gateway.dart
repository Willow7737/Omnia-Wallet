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
  Future<String> accessToken() async {
    var session = _client.auth.currentSession;
    if (session == null) {
      throw StateError('Not signed in — sign in with your Omnia account.');
    }
    if (session.isExpired) {
      final refreshed = await _client.auth.refreshSession();
      session = refreshed.session;
    }
    final token = session?.accessToken;
    if (token == null) {
      throw StateError('Your session expired. Please sign in again.');
    }
    return token;
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
}
