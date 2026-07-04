import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/crypto/secure_store.dart';
import 'package:omnia_wallet/features/lock/app_lock.dart';

/// In-memory [SecureStore] that only implements the app-lock flag. The base
/// constructor builds a FlutterSecureStorage but the platform channel is never
/// touched because these methods are overridden.
class _FakeStore extends SecureStore {
  _FakeStore(this._enabled);
  bool _enabled;

  @override
  Future<bool> isAppLockEnabled() async => _enabled;

  @override
  Future<void> setAppLockEnabled(bool enabled) async => _enabled = enabled;
}

void main() {
  AppLockController build(
    bool enabled,
    UnlockResult authResult, {
    List<String>? calls,
  }) {
    return AppLockController(
      store: _FakeStore(enabled),
      authenticate: (reason) async {
        calls?.add(reason);
        return authResult;
      },
    );
  }

  test('load() starts locked when the preference is on', () async {
    final c = build(true, UnlockResult.success);
    await c.load();
    expect(c.state.enabled, isTrue);
    expect(c.state.locked, isTrue);
  });

  test('load() stays unlocked when the preference is off', () async {
    final c = build(false, UnlockResult.success);
    await c.load();
    expect(c.state.enabled, isFalse);
    expect(c.state.locked, isFalse);
  });

  test('enabling requires a successful auth check', () async {
    final store = _FakeStore(false);
    final c = AppLockController(
      store: store,
      authenticate: (_) async => UnlockResult.failed,
    );
    final result = await c.setEnabled(true);
    expect(result, UnlockResult.failed);
    expect(c.state.enabled, isFalse);
    expect(await store.isAppLockEnabled(), isFalse);
  });

  test('enabling persists and unlocks on success', () async {
    final store = _FakeStore(false);
    final c = AppLockController(
      store: store,
      authenticate: (_) async => UnlockResult.success,
    );
    final result = await c.setEnabled(true);
    expect(result, UnlockResult.success);
    expect(c.state.enabled, isTrue);
    expect(c.state.locked, isFalse);
    expect(await store.isAppLockEnabled(), isTrue);
  });

  test('disabling does not require auth', () async {
    final calls = <String>[];
    final c = build(true, UnlockResult.success, calls: calls);
    await c.load();
    final result = await c.setEnabled(false);
    expect(result, UnlockResult.success);
    expect(c.state.enabled, isFalse);
    expect(calls, isEmpty); // no biometric prompt to turn it off
  });

  test('lockIfEnabled only locks when enabled', () async {
    final on = build(true, UnlockResult.success);
    await on.load(); // enabled + locked
    await on.unlock(); // now unlocked
    expect(on.state.locked, isFalse);
    on.lockIfEnabled();
    expect(on.state.locked, isTrue);

    final off = build(false, UnlockResult.success);
    await off.load();
    off.lockIfEnabled();
    expect(off.state.locked, isFalse);
  });

  test('unlock clears the lock only on success', () async {
    final ok = build(true, UnlockResult.success);
    await ok.load();
    expect(ok.state.locked, isTrue);
    expect(await ok.unlock(), UnlockResult.success);
    expect(ok.state.locked, isFalse);

    final bad = build(true, UnlockResult.failed);
    await bad.load();
    expect(await bad.unlock(), UnlockResult.failed);
    expect(bad.state.locked, isTrue);
  });
}
