/// Global configuration and constants.
///
/// # Environments
///
/// The build targets one of [OmniaEnvironment.testnet] (default) or
/// [OmniaEnvironment.production], selected at build time:
///
///   flutter build appbundle --release --dart-define=OMNIA_ENV=production \
///     --dart-define=OMNIA_PROD_NODE_URL=https://your-prod-node-domain
///
/// Anything other than `production` (case-insensitive) resolves to testnet,
/// so a release build only reaches production endpoints when explicitly asked.
///
/// Endpoint resolution precedence (highest first):
///   1. An explicit per-key define (`OMNIA_NODE_URL`, `OMNIA_SUPABASE_URL`,
///      `OMNIA_SUPABASE_ANON_KEY`) — wins in any environment.
///   2. The active environment's default (production defaults are themselves
///      overridable via `OMNIA_PROD_*` defines, so CI can inject real prod
///      values without a code change).
///
/// The node URL is also user-configurable at runtime from Settings.
library;

/// Deployment environment selected at build time via `--dart-define=OMNIA_ENV`.
enum OmniaEnvironment { testnet, production }

class AppConfig {
  AppConfig._();

  // ---- Environment selection ----

  static const String _envName =
      String.fromEnvironment('OMNIA_ENV', defaultValue: 'testnet');

  /// The active deployment environment.
  static OmniaEnvironment get environment =>
      _envName.trim().toLowerCase() == 'production'
          ? OmniaEnvironment.production
          : OmniaEnvironment.testnet;

  /// Whether this build targets production endpoints.
  static bool get isProduction => environment == OmniaEnvironment.production;

  /// Human-readable label for the active network (for UI surfaces).
  static String get networkLabel => isProduction ? 'Mainnet' : 'Testnet';

  /// Whether the UI should show a visible network indicator. On (only) for
  /// non-production builds, so a testnet build is never mistaken for the real
  /// network.
  static bool get showNetworkBadge => !isProduction;

  // ---- Node endpoint ----

  static const String _testnetNodeUrl = 'https://78.47.43.136.sslip.io';

  /// Production node URL. Inject the real one at build time with
  /// `--dart-define=OMNIA_PROD_NODE_URL=https://<prod-node-domain>`. Until a
  /// dedicated production node domain exists this falls back to the current
  /// live network — replace it with a stable domain before a public launch.
  static const String _productionNodeUrl = String.fromEnvironment(
    'OMNIA_PROD_NODE_URL',
    defaultValue: _testnetNodeUrl,
  );

  static const String _explicitNodeUrl =
      String.fromEnvironment('OMNIA_NODE_URL', defaultValue: '');

  /// Default node base URL for the active environment. An explicit
  /// `--dart-define=OMNIA_NODE_URL` wins; otherwise the environment default.
  /// Also user-overridable at runtime in Settings.
  static String get defaultNodeUrl => _explicitNodeUrl.isNotEmpty
      ? _explicitNodeUrl
      : (isProduction ? _productionNodeUrl : _testnetNodeUrl);

  /// Domain-separation prefix for the login challenge signature.
  /// MUST match `AUTH_MESSAGE_PREFIX` in the node's `wallet_auth.rs`.
  static const String authMessagePrefix = 'omnia-auth:';

  /// Domain-separation prefix for a wallet-signed transfer authorization
  /// (self-sovereign spend, Step 2). MUST match `TRANSFER_MESSAGE_PREFIX`
  /// in the node's `wallet_auth.rs`. Distinct from [authMessagePrefix] so a
  /// login signature can never be replayed as a spend authorization.
  static const String transferMessagePrefix = 'omnia-transfer-v1';

  // ---- Supabase (Mode B sign-in: Google / GitHub / email) ----

  static const String _testnetSupabaseUrl =
      'https://iyajzmgnykgkivabxiuw.supabase.co';

  /// The project's anon (publishable) key — public by design, safe to ship.
  static const String _testnetSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6'
      'Iml5YWp6bWdueWtna2l2YWJ4aXV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0MTM5'
      'MjgsImV4cCI6MjA5Nzk4OTkyOH0.PJT1Ha_XMk_LczAGjt3Wveg_aqzPJQU7m3-MtjAgErY';

  /// Production Supabase project — inject with `OMNIA_PROD_SUPABASE_URL` /
  /// `OMNIA_PROD_SUPABASE_ANON_KEY`. Falls back to the current project until a
  /// dedicated production project is provisioned.
  static const String _productionSupabaseUrl = String.fromEnvironment(
    'OMNIA_PROD_SUPABASE_URL',
    defaultValue: _testnetSupabaseUrl,
  );
  static const String _productionSupabaseAnonKey = String.fromEnvironment(
    'OMNIA_PROD_SUPABASE_ANON_KEY',
    defaultValue: _testnetSupabaseAnonKey,
  );

  static const String _explicitSupabaseUrl =
      String.fromEnvironment('OMNIA_SUPABASE_URL', defaultValue: '');
  static const String _explicitSupabaseAnonKey =
      String.fromEnvironment('OMNIA_SUPABASE_ANON_KEY', defaultValue: '');

  /// The active Supabase project URL for the current environment.
  static String get supabaseUrl => _explicitSupabaseUrl.isNotEmpty
      ? _explicitSupabaseUrl
      : (isProduction ? _productionSupabaseUrl : _testnetSupabaseUrl);

  /// The active Supabase anon key for the current environment.
  static String get supabaseAnonKey => _explicitSupabaseAnonKey.isNotEmpty
      ? _explicitSupabaseAnonKey
      : (isProduction ? _productionSupabaseAnonKey : _testnetSupabaseAnonKey);

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
  static const String kLastSeenNewsKey = 'omnia.wallet.last_seen_news';
  static const String kAvatarPathKey = 'omnia.wallet.avatar_path';

  /// Refresh the JWT this many seconds before it actually expires.
  static const int jwtRefreshSkewSecs = 60;
}
