import 'dart:typed_data';

import '../core/auth_mode.dart';
import '../core/config.dart';
import '../crypto/key_manager.dart';
import '../crypto/secure_store.dart';
import 'api_client.dart';
import 'mint_jwt_client.dart';
import 'models.dart';
import 'supabase_gateway.dart';

/// Owns the wallet's identity and node session, in either auth mode.
///
/// **Mode A (self-custody):** the private seed lives in [SecureStore]; it's
/// loaded only to sign the login challenge, and the resulting JWT is cached
/// in memory. On expiry (or a 401) the challenge → sign → login flow re-runs
/// transparently.
///
/// **Mode B (Supabase):** the signed-in Supabase session's access token is
/// exchanged at the `mint-node-jwt` edge function for a node JWT bound to the
/// account's server-side DID. No private key exists on the device.
class AuthRepository {
  AuthRepository({
    required SecureStore store,
    required ApiClient api,
    KeyManager keyManager = const KeyManager(),
    MintJwtClient? mintClient,
    SupabaseGateway? supabase,
  })  : _store = store,
        _api = api,
        _keys = keyManager,
        _mint = mintClient,
        _supabase = supabase;

  final SecureStore _store;
  final ApiClient _api;
  final KeyManager _keys;
  final MintJwtClient? _mint;
  final SupabaseGateway? _supabase;

  WalletIdentity? _identity;
  Session? _session;

  WalletIdentity? get identity => _identity;

  Future<AuthMode> authMode() => _store.readAuthMode();

  /// Load the identity for the active mode, or null if none exists yet.
  Future<WalletIdentity?> loadIdentity() async {
    if (await authMode() == AuthMode.supabase) {
      final did = await _store.readSupabaseDid();
      if (did == null) return null;
      return _identity = WalletIdentity(did: did, mode: AuthMode.supabase);
    }
    final seed = await _store.readSeed();
    if (seed == null) return null;
    return _identity = _keys.identityFromSeed(seed);
  }

  /// Whether any identity exists on this device (on-device key OR a linked
  /// Supabase account).
  Future<bool> hasWallet() async {
    if (await _store.hasWallet()) return true;
    return await authMode() == AuthMode.supabase;
  }

  /// Create a brand-new wallet, returning the mnemonic to back up.
  Future<String> createWallet() async {
    final mnemonic = _keys.generateMnemonic();
    await _persistFromMnemonic(mnemonic);
    return mnemonic;
  }

  /// Import an existing wallet from a mnemonic. Throws [FormatException] if
  /// the phrase is invalid.
  Future<void> importWallet(String mnemonic) async {
    if (!_keys.validateMnemonic(mnemonic)) {
      throw const FormatException('Invalid recovery phrase');
    }
    await _persistFromMnemonic(mnemonic);
  }

  Future<void> _persistFromMnemonic(String mnemonic) async {
    final seed = _keys.seedFromMnemonic(mnemonic);
    await _store.saveWallet(seed: seed, mnemonic: mnemonic);
    await _store.saveAuthMode(AuthMode.selfCustody);
    _identity = _keys.identityFromSeed(seed);
    _session = null;
  }

  /// Finish a Mode B sign-in: the Supabase session already exists (OAuth
  /// redirect or email/password); exchange it for a node JWT + DID and persist
  /// the mode. Rolls the mode back on failure so the app doesn't get stuck
  /// looking "signed in" with no working session.
  Future<Session> completeSupabaseSignIn() async {
    await _store.saveAuthMode(AuthMode.supabase);
    try {
      return _session = await _authenticateSupabase();
    } catch (_) {
      await _store.saveAuthMode(AuthMode.selfCustody);
      rethrow;
    }
  }

  /// Return a valid session token, refreshing if needed.
  Future<Session> ensureSession() async {
    final current = _session;
    if (current != null &&
        !current
            .isExpiredWithin(Duration(seconds: AppConfig.jwtRefreshSkewSecs))) {
      return current;
    }
    return _session = await _authenticate();
  }

  /// Force a fresh login (e.g. after a 401).
  Future<Session> refresh() async => _session = await _authenticate();

  Future<Session> _authenticate() async {
    if (await authMode() == AuthMode.supabase) {
      return _authenticateSupabase();
    }
    final seed = await _store.readSeed();
    if (seed == null) {
      throw StateError('No wallet on device — create or import one first');
    }
    final identity = _keys.identityFromSeed(seed);
    _identity = identity;

    final challenge = await _api.requestChallenge(identity.publicKeyHex!);
    final signatureHex = _signChallenge(seed, challenge.message);
    final login = await _api.login(
      publicKeyHex: identity.publicKeyHex!,
      signatureHex: signatureHex,
      nonce: challenge.nonce,
    );

    return Session(
      did: login.did,
      token: login.token,
      expiresAt: DateTime.now().add(Duration(seconds: login.expiresIn)),
    );
  }

  Future<Session> _authenticateSupabase() async {
    final gateway = _supabase;
    final mint = _mint;
    if (gateway == null || mint == null) {
      throw StateError('Supabase sign-in is not configured in this build.');
    }
    final accessToken = await gateway.accessToken();
    final minted = await mint.mint(accessToken);
    await _store.saveSupabaseDid(minted.did);
    _identity = WalletIdentity(did: minted.did, mode: AuthMode.supabase);
    return Session(
      did: minted.did,
      token: minted.token,
      expiresAt: DateTime.now().add(Duration(seconds: minted.expiresIn)),
    );
  }

  String _signChallenge(Uint8List seed, String message) =>
      _keys.signHex(seed, message);

  Future<void> logout() async {
    _session = null;
    _identity = null;
    if (await authMode() == AuthMode.supabase) {
      try {
        await _supabase?.signOut();
      } catch (_) {
        // Best-effort: local wipe below is what actually matters.
      }
    }
    await _store.wipe();
  }
}
