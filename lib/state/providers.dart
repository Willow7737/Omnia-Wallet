import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth_mode.dart';
import '../core/config.dart';
import '../crypto/key_manager.dart';
import '../crypto/secure_store.dart';
import '../data/api_client.dart';
import '../data/auth_repository.dart';
import '../data/mint_jwt_client.dart';
import '../data/models.dart';
import '../data/supabase_gateway.dart';
import '../data/wallet_repository.dart';

/// The active node base URL. Seeded from --dart-define / storage in `main`.
final nodeUrlProvider =
    StateProvider<String>((ref) => AppConfig.defaultNodeUrl);

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

final keyManagerProvider = Provider<KeyManager>((ref) => const KeyManager());

final apiClientProvider = Provider<ApiClient>((ref) {
  final url = ref.watch(nodeUrlProvider);
  return ApiClient(baseUrl: url);
});

/// Seam over supabase_flutter (Mode B). Overridable in tests.
final supabaseGatewayProvider =
    Provider<SupabaseGateway>((ref) => SupabaseFlutterGateway());

final mintJwtClientProvider = Provider<MintJwtClient>((ref) => MintJwtClient());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    store: ref.watch(secureStoreProvider),
    api: ref.watch(apiClientProvider),
    keyManager: ref.watch(keyManagerProvider),
    mintClient: ref.watch(mintJwtClientProvider),
    supabase: ref.watch(supabaseGatewayProvider),
  );
});

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(
    auth: ref.watch(authRepositoryProvider),
    api: ref.watch(apiClientProvider),
  );
});

/// Whether an identity already exists on this device — an on-device wallet
/// key (Mode A) or a linked Supabase account (Mode B).
final hasWalletProvider = FutureProvider<bool>((ref) async {
  return ref.watch(authRepositoryProvider).hasWallet();
});

/// The active auth mode (defaults to self-custody).
final authModeProvider = FutureProvider<AuthMode>((ref) async {
  return ref.watch(secureStoreProvider).readAuthMode();
});

/// The identity for the active mode, or null if none yet.
final identityProvider = FutureProvider<WalletIdentity?>((ref) async {
  return ref.watch(authRepositoryProvider).loadIdentity();
});

/// The signed-in Supabase account's email, if any (Mode B).
final supabaseEmailProvider = Provider<String?>((ref) {
  final gateway = ref.watch(supabaseGatewayProvider);
  return gateway.isAvailable ? gateway.userEmail : null;
});

/// User-chosen display name (local only), or null if unset.
final displayNameProvider = FutureProvider<String?>((ref) async {
  return ref.watch(secureStoreProvider).readDisplayName();
});

/// Current balance. Auto-refreshes when invalidated after a send.
final balanceProvider = FutureProvider<Balance>((ref) async {
  return ref.watch(walletRepositoryProvider).balance();
});

/// Transaction history.
final historyProvider = FutureProvider<List<TransferRecord>>((ref) async {
  return ref.watch(walletRepositoryProvider).history();
});

/// Public node status (health/version/peers). No auth required.
final nodeInfoProvider = FutureProvider<NodeInfo>((ref) async {
  return ref.watch(apiClientProvider).getNodeInfo();
});
