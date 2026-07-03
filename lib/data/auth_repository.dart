import 'dart:typed_data';

import '../core/config.dart';
import '../crypto/key_manager.dart';
import '../crypto/secure_store.dart';
import 'api_client.dart';
import 'models.dart';

/// Owns the wallet's identity and node session.
///
/// The private seed lives in [SecureStore]; this repository loads it only to
/// sign the login challenge, then caches the resulting JWT in memory. On
/// expiry (or a 401) it transparently re-runs challenge -> sign -> login.
class AuthRepository {
  AuthRepository({
    required SecureStore store,
    required ApiClient api,
    KeyManager keyManager = const KeyManager(),
  })  : _store = store,
        _api = api,
        _keys = keyManager;

  final SecureStore _store;
  final ApiClient _api;
  final KeyManager _keys;

  WalletIdentity? _identity;
  Session? _session;

  WalletIdentity? get identity => _identity;

  /// Load the on-device identity (public key + DID) if a wallet exists.
  Future<WalletIdentity?> loadIdentity() async {
    final seed = await _store.readSeed();
    if (seed == null) return null;
    _identity = _keys.identityFromSeed(seed);
    return _identity;
  }

  Future<bool> hasWallet() => _store.hasWallet();

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
    _identity = _keys.identityFromSeed(seed);
    _session = null;
  }

  /// Return a valid session token, refreshing via challenge/login if needed.
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
    final seed = await _store.readSeed();
    if (seed == null) {
      throw StateError('No wallet on device — create or import one first');
    }
    final identity = _keys.identityFromSeed(seed);
    _identity = identity;

    final challenge = await _api.requestChallenge(identity.publicKeyHex);
    final signatureHex = _signChallenge(seed, challenge.message);
    final login = await _api.login(
      publicKeyHex: identity.publicKeyHex,
      signatureHex: signatureHex,
      nonce: challenge.nonce,
    );

    return Session(
      did: login.did,
      token: login.token,
      expiresAt: DateTime.now().add(Duration(seconds: login.expiresIn)),
    );
  }

  String _signChallenge(Uint8List seed, String message) =>
      _keys.signHex(seed, message);

  Future<void> logout() async {
    _session = null;
    _identity = null;
    await _store.wipe();
  }
}
