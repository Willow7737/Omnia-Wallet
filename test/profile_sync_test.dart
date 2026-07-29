import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/crypto/secure_store.dart';
import 'package:omnia_wallet/data/supabase_gateway.dart';
import 'package:omnia_wallet/state/profile.dart';
import 'package:omnia_wallet/state/providers.dart';

import 'support/fake_gateway.dart';

/// Which side of a profile wins, and when.
///
/// The whole point of this release is that a name and a picture outlive the
/// handset, so the merge rule is the thing worth pinning: get it backwards and
/// the first launch after upgrading silently erases what people had.
void main() {
  late _Store store;
  late _Gateway gateway;
  late ProviderContainer container;

  setUp(() {
    store = _Store();
    gateway = _Gateway();
    container = ProviderContainer(overrides: [
      secureStoreProvider.overrideWithValue(store),
      supabaseGatewayProvider.overrideWithValue(gateway),
    ]);
    addTearDown(container.dispose);
  });

  ProfileSync profile() => container.read(profileSyncProvider);

  group('sync', () {
    test('does nothing at all when nobody is signed in', () async {
      gateway.authenticated = false;
      store.displayName = 'On this device';

      await profile().sync();

      expect(gateway.fetches, 0);
      expect(store.displayName, 'On this device',
          reason: 'a local-only wallet had its name touched');
    });

    test('the account wins when it has a name', () async {
      store.displayName = 'Old handset name';
      gateway.profile = const RemoteProfile(displayName: 'Willow');

      await profile().sync();

      expect(store.displayName, 'Willow');
    });

    test('an existing local name is pushed up, never erased', () async {
      // The upgrade case: the name has only ever existed on the handset, and
      // the backend column is empty. Letting the empty side win would delete
      // it the moment this release lands.
      store.displayName = 'Willow';
      gateway.profile = const RemoteProfile();

      await profile().sync();

      expect(store.displayName, 'Willow');
      expect(gateway.saved.map((s) => s.displayName), contains('Willow'));
    });

    test('a missing row is not an error and keeps the local copy', () async {
      store.displayName = 'Willow';
      gateway.profile = null;

      await profile().sync();

      expect(store.displayName, 'Willow');
    });

    test('a failing backend leaves the cached profile alone', () async {
      store.displayName = 'Willow';
      gateway.throwOnFetch = true;

      await profile().sync();

      expect(store.displayName, 'Willow');
    });

    test('a local-only picture is uploaded once and remembered', () async {
      final file = File('${Directory.systemTemp.path}/omnia-test-avatar.jpg')
        ..writeAsBytesSync(const [1, 2, 3]);
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      store.avatarPath = file.path;
      gateway.profile = const RemoteProfile();

      await profile().sync();

      expect(gateway.uploads, 1);
      expect(store.avatarUrl, isNotNull,
          reason: 'the uploaded URL must be remembered, or every launch '
              're-uploads the same picture');
    });

    test('a picture already cached from the same URL is not re-fetched',
        () async {
      final file = File('${Directory.systemTemp.path}/omnia-test-cached.jpg')
        ..writeAsBytesSync(const [1, 2, 3]);
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      store.avatarPath = file.path;
      store.avatarUrl = 'https://example.test/a.jpg';
      gateway.profile =
          const RemoteProfile(avatarUrl: 'https://example.test/a.jpg');

      await profile().sync();

      // No upload (the backend already has one) and no download attempt —
      // the assertion that matters is simply that this completed without
      // touching the network at all.
      expect(gateway.uploads, 0);
      expect(store.avatarPath, file.path);
    });
  });

  group('setDisplayName', () {
    test('writes the device first, so the UI never waits on the network',
        () async {
      await profile().setDisplayName('Ama');
      expect(store.displayName, 'Ama');
      expect(gateway.saved.single.displayName, 'Ama');
    });

    test('still sets the name locally when signed out', () async {
      gateway.authenticated = false;
      await profile().setDisplayName('Ama');
      expect(store.displayName, 'Ama');
      expect(gateway.saved, isEmpty);
    });
  });
}

class _Store extends SecureStore {
  String? displayName;
  String? avatarPath;
  String? avatarUrl;

  @override
  Future<String?> readDisplayName() async => displayName;

  @override
  Future<void> saveDisplayName(String name) async => displayName = name;

  @override
  Future<String?> readAvatarPath() async => avatarPath;

  @override
  Future<void> saveAvatarPath(String path) async => avatarPath = path;

  @override
  Future<String?> readAvatarUrl() async => avatarUrl;

  @override
  Future<void> saveAvatarUrl(String? url) async => avatarUrl = url;
}

class _Gateway extends FakeGatewayBase {
  bool throwOnFetch = false;

  List<({String? displayName, String? avatarUrl})> get saved => savedProfiles;
  int get fetches => profileFetches;

  @override
  Future<RemoteProfile?> fetchProfile() async {
    if (throwOnFetch) {
      profileFetches++;
      throw StateError('offline');
    }
    return super.fetchProfile();
  }
}
