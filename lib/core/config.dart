/// Global configuration and constants.
///
/// The node base URL can be overridden at build/run time with:
///   flutter run --dart-define=OMNIA_NODE_URL=http://10.0.2.2:9090
/// and is also user-configurable at runtime from the Settings screen
/// (persisted via secure storage).
library;

class AppConfig {
  AppConfig._();

  /// Default node base URL. `10.0.2.2` is the Android emulator's alias for the
  /// host machine's `localhost`; override via --dart-define for real devices.
  static const String defaultNodeUrl = String.fromEnvironment(
    'OMNIA_NODE_URL',
    defaultValue: 'http://10.0.2.2:9090',
  );

  /// Domain-separation prefix for the login challenge signature.
  /// MUST match `AUTH_MESSAGE_PREFIX` in the node's `wallet_auth.rs`.
  static const String authMessagePrefix = 'omnia-auth:';

  /// Secure-storage keys.
  static const String kSeedKey = 'omnia.wallet.seed';
  static const String kMnemonicKey = 'omnia.wallet.mnemonic';
  static const String kNodeUrlKey = 'omnia.wallet.node_url';

  /// Refresh the JWT this many seconds before it actually expires.
  static const int jwtRefreshSkewSecs = 60;
}
