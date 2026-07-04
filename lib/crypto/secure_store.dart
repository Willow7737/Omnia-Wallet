import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/config.dart';

/// Thin wrapper over platform-backed secure storage (iOS Keychain /
/// Android Keystore) for the wallet's secret material.
///
/// The Ed25519 seed and mnemonic never leave the device. Only the derived
/// public key / DID and signatures are ever transmitted.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions:
                  IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  Future<bool> hasWallet() async =>
      await _storage.containsKey(key: AppConfig.kSeedKey);

  Future<void> saveWallet({
    required Uint8List seed,
    required String mnemonic,
  }) async {
    await _storage.write(key: AppConfig.kSeedKey, value: hex.encode(seed));
    await _storage.write(key: AppConfig.kMnemonicKey, value: mnemonic);
  }

  Future<Uint8List?> readSeed() async {
    final value = await _storage.read(key: AppConfig.kSeedKey);
    if (value == null) return null;
    return Uint8List.fromList(hex.decode(value));
  }

  Future<String?> readMnemonic() async =>
      _storage.read(key: AppConfig.kMnemonicKey);

  Future<String?> readNodeUrl() async =>
      _storage.read(key: AppConfig.kNodeUrlKey);

  Future<void> saveNodeUrl(String url) async =>
      _storage.write(key: AppConfig.kNodeUrlKey, value: url);

  Future<bool> isAppLockEnabled() async =>
      (await _storage.read(key: AppConfig.kAppLockKey)) == 'true';

  Future<void> setAppLockEnabled(bool enabled) async =>
      _storage.write(key: AppConfig.kAppLockKey, value: enabled.toString());

  /// Irreversibly wipe all wallet material from the device.
  Future<void> wipe() async {
    await _storage.delete(key: AppConfig.kSeedKey);
    await _storage.delete(key: AppConfig.kMnemonicKey);
    await _storage.delete(key: AppConfig.kAppLockKey);
  }
}
