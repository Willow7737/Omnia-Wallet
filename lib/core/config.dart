/// Global configuration and constants.
///
/// The node base URL can be overridden at build/run time with:
///   flutter run --dart-define=OMNIA_NODE_URL=http://10.0.2.2:9090
/// and is also user-configurable at runtime from the Settings screen
/// (persisted via secure storage).
library;

class AppConfig {
  AppConfig._();

  /// Default node base URL. Points at the live Omnia node; override at build
  /// time with `--dart-define=OMNIA_NODE_URL=...` or at runtime in Settings.
  static const String defaultNodeUrl = String.fromEnvironment(
    'OMNIA_NODE_URL',
    defaultValue: 'https://78.47.43.136.sslip.io',
  );

  /// Domain-separation prefix for the login challenge signature.
  /// MUST match `AUTH_MESSAGE_PREFIX` in the node's `wallet_auth.rs`.
  static const String authMessagePrefix = 'omnia-auth:';

  // ---- Supabase (Mode B sign-in: Google / GitHub / email) ----

  /// The Omnia Supabase project (same one the web dashboard uses).
  static const String supabaseUrl = String.fromEnvironment(
    'OMNIA_SUPABASE_URL',
    defaultValue: 'https://iyajzmgnykgkivabxiuw.supabase.co',
  );

  /// The project's anon (publishable) key — public by design, safe to ship.
  static const String supabaseAnonKey = String.fromEnvironment(
    'OMNIA_SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6'
        'Iml5YWp6bWdueWtna2l2YWJ4aXV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0MTM5'
        'MjgsImV4cCI6MjA5Nzk4OTkyOH0.PJT1Ha_XMk_LczAGjt3Wveg_aqzPJQU7m3-MtjAgErY',
  );

  static bool get supabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Edge function that verifies a Supabase session and mints a node JWT.
  static const String mintJwtPath = '/functions/v1/mint-node-jwt';

  /// Deep-link redirect for mobile OAuth. Must be listed under
  /// Supabase → Auth → URL Configuration → Redirect URLs.
  static const String oauthRedirectUri = 'io.omnia.wallet://login-callback/';

  /// Secure-storage keys.
  static const String kSeedKey = 'omnia.wallet.seed';
  static const String kMnemonicKey = 'omnia.wallet.mnemonic';
  static const String kNodeUrlKey = 'omnia.wallet.node_url';
  static const String kAppLockKey = 'omnia.wallet.app_lock';
  static const String kContactsKey = 'omnia.wallet.contacts';
  static const String kDisplayNameKey = 'omnia.wallet.display_name';
  static const String kAuthModeKey = 'omnia.wallet.auth_mode';
  static const String kSupabaseDidKey = 'omnia.wallet.supabase_did';
  static const String kNoticesKey = 'omnia.wallet.notices';

  /// Refresh the JWT this many seconds before it actually expires.
  static const int jwtRefreshSkewSecs = 60;
}
