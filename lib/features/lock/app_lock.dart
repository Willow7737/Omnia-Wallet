import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../crypto/secure_store.dart';
import '../../state/providers.dart';

/// Result of an unlock attempt.
enum UnlockResult { success, failed, unavailable }

/// Signature for the biometric/device-credential prompt, injected so the
/// controller can be unit-tested without the platform channel.
typedef Authenticator = Future<UnlockResult> Function(String reason);

@immutable
class AppLockState {
  const AppLockState({required this.enabled, required this.locked});

  /// Whether the user turned app lock on.
  final bool enabled;

  /// Whether the app is currently locked (obscured behind the lock screen).
  final bool locked;

  const AppLockState.initial()
      : enabled = false,
        locked = false;

  AppLockState copyWith({bool? enabled, bool? locked}) => AppLockState(
        enabled: enabled ?? this.enabled,
        locked: locked ?? this.locked,
      );
}

/// Owns the app-lock preference and the current locked/unlocked state, and
/// drives the biometric prompt.
class AppLockController extends StateNotifier<AppLockState> {
  AppLockController(
      {required SecureStore store, required Authenticator authenticate})
      : _store = store,
        _authenticate = authenticate,
        super(const AppLockState.initial());

  final SecureStore _store;
  final Authenticator _authenticate;

  /// Load the persisted preference. If lock is on, the app starts locked.
  Future<void> load() async {
    final enabled = await _store.isAppLockEnabled();
    state = AppLockState(enabled: enabled, locked: enabled);
  }

  /// Turn app lock on/off. Enabling requires a successful auth check so the
  /// user can't lock themselves out with a credential they can't satisfy.
  Future<UnlockResult> setEnabled(bool enabled) async {
    if (enabled) {
      final result = await _authenticate('Enable app lock');
      if (result != UnlockResult.success) return result;
    }
    await _store.setAppLockEnabled(enabled);
    state = state.copyWith(enabled: enabled, locked: false);
    return UnlockResult.success;
  }

  /// Called when the app returns from the background — locks if enabled.
  void lockIfEnabled() {
    if (state.enabled && !state.locked) {
      state = state.copyWith(locked: true);
    }
  }

  /// Prompt for biometrics and unlock on success.
  Future<UnlockResult> unlock() async {
    final result = await _authenticate('Unlock your wallet');
    if (result == UnlockResult.success) {
      state = state.copyWith(locked: false);
    }
    return result;
  }
}

/// Default authenticator backed by `local_auth`. Treats "no biometrics
/// enrolled / not supported" as [UnlockResult.unavailable] so the UI can offer
/// a graceful path rather than trapping the user.
Future<UnlockResult> localAuthAuthenticate(String reason) async {
  final auth = LocalAuthentication();
  try {
    if (!await auth.isDeviceSupported()) return UnlockResult.unavailable;
    final ok = await auth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(stickyAuth: true),
    );
    return ok ? UnlockResult.success : UnlockResult.failed;
  } catch (_) {
    return UnlockResult.unavailable;
  }
}

final appLockProvider =
    StateNotifierProvider<AppLockController, AppLockState>((ref) {
  return AppLockController(
    store: ref.watch(secureStoreProvider),
    authenticate: localAuthAuthenticate,
  );
});
