import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/core/config.dart';

void main() {
  group('AppConfig environment', () {
    // These assertions describe the *default* build (no --dart-define), which
    // must resolve to testnet so a build only reaches production endpoints
    // when explicitly asked via --dart-define=OMNIA_ENV=production.
    test('defaults to testnet', () {
      expect(AppConfig.environment, OmniaEnvironment.testnet);
      expect(AppConfig.isProduction, isFalse);
    });

    test('shows a network badge and Testnet label off production', () {
      expect(AppConfig.showNetworkBadge, isTrue);
      expect(AppConfig.networkLabel, 'Testnet');
    });

    test('node URL resolves to a non-empty https endpoint', () {
      expect(AppConfig.defaultNodeUrl, isNotEmpty);
      expect(AppConfig.defaultNodeUrl, startsWith('https://'));
    });

    test('Supabase is configured (url + anon key present)', () {
      expect(AppConfig.supabaseConfigured, isTrue);
      expect(AppConfig.supabaseUrl, startsWith('https://'));
      expect(AppConfig.supabaseAnonKey, isNotEmpty);
    });
  });
}
