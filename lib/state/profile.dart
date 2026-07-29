import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../crypto/secure_store.dart';
import '../data/supabase_gateway.dart';
import 'avatar.dart';
import 'providers.dart';

/// Keeps the display name and profile picture on the account rather than on
/// the handset.
///
/// Both used to live only in secure storage, which is wiped when a wallet is
/// removed — so re-adding one, even to the same account, came back nameless
/// and faceless. They now live on `user_dids` (beside the DID, and the same
/// row the web interface uses), with the device keeping a copy so the app
/// still shows a name and a face while offline.
///
/// The local copy is a cache, not a second source of truth. Which side wins is
/// decided once, in [_merge], rather than at each call site.
class ProfileSync {
  ProfileSync(this._ref);

  final Ref _ref;

  SecureStore get _store => _ref.read(secureStoreProvider);
  SupabaseGateway get _gateway => _ref.read(supabaseGatewayProvider);

  /// Reconcile the device's copy with the account's, in both directions.
  ///
  /// Called at launch and whenever a session arrives. Failure is deliberately
  /// silent: a profile that could not be fetched is not worth a error in front
  /// of somebody who just opened the app, and the local copy is still good.
  Future<void> sync() async {
    if (!_gateway.isSignedIn) return;
    try {
      final remote = await _gateway.fetchProfile();
      await _merge(remote);
    } catch (_) {
      // Offline, or the row is not readable. The cached copy stands.
    }
  }

  /// The rule: the account wins where it has an answer, and where it does not,
  /// whatever this device already had is pushed up.
  ///
  /// That second half is what carries existing users across. Their name only
  /// ever existed on the handset, and a merge that let the empty backend win
  /// would erase it at the moment this release lands.
  Future<void> _merge(RemoteProfile? remote) async {
    final localName = await _store.readDisplayName();
    final remoteName = remote?.displayName;

    if (remoteName != null && remoteName.isNotEmpty) {
      if (remoteName != localName) {
        await _store.saveDisplayName(remoteName);
        _ref.invalidate(displayNameProvider);
      }
    } else if (localName != null && localName.isNotEmpty) {
      await _pushName(localName);
    }

    final remoteAvatar = remote?.avatarUrl;
    if (remoteAvatar != null && remoteAvatar.isNotEmpty) {
      await _pullAvatar(remoteAvatar);
    } else {
      await _pushLocalAvatarIfAny();
    }
  }

  Future<void> _pushName(String name) async {
    try {
      await _gateway.saveProfile(displayName: name);
    } catch (_) {
      // Best effort — the next sync tries again.
    }
  }

  /// Download the account's picture into the same local file the UI already
  /// reads, so nothing else in the app has to know a network image exists.
  Future<void> _pullAvatar(String url) async {
    final cachedUrl = await _store.readAvatarUrl();
    final cachedPath = await _store.readAvatarPath();
    final haveFile = cachedPath != null &&
        cachedPath.isNotEmpty &&
        File(cachedPath).existsSync();
    if (cachedUrl == url && haveFile) return;

    try {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return;
      await _writeAvatarFile(Uint8List.fromList(bytes), url: url);
    } catch (_) {
      // Leave the cache alone; a later sync retries.
    }
  }

  /// A picture chosen before this release exists only on the handset. Upload
  /// it once so it survives the next reinstall.
  Future<void> _pushLocalAvatarIfAny() async {
    final path = await _store.readAvatarPath();
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!file.existsSync()) return;
    try {
      final url = await _gateway.uploadAvatar(
        bytes: await file.readAsBytes(),
        fileExtension: 'jpg',
      );
      await _gateway.saveProfile(avatarUrl: url);
      await _store.saveAvatarUrl(url);
    } catch (_) {
      // Best effort.
    }
  }

  /// Set the display name everywhere: on the device now, on the account when
  /// there is one.
  Future<void> setDisplayName(String name) async {
    await _store.saveDisplayName(name);
    _ref.invalidate(displayNameProvider);
    if (!_gateway.isSignedIn) return;
    await _gateway.saveProfile(displayName: name);
  }

  /// Pick a photo, cache it locally, and upload it to the account.
  ///
  /// Returns false when the picker was dismissed. The local write happens
  /// first and is never undone by an upload failure — the picture the reader
  /// just chose is on screen either way, and the next sync pushes it.
  Future<bool> pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return false;

    final bytes = await picked.readAsBytes();
    await _writeAvatarFile(bytes, url: null);

    if (_gateway.isSignedIn) {
      try {
        final url = await _gateway.uploadAvatar(
          bytes: bytes,
          fileExtension: 'jpg',
        );
        await _gateway.saveProfile(avatarUrl: url);
        await _store.saveAvatarUrl(url);
      } catch (_) {
        // Kept locally; _pushLocalAvatarIfAny retries on the next sync.
      }
    }
    return true;
  }

  /// Write bytes to a fresh file, drop the previous one, and repoint the UI.
  ///
  /// The name carries a timestamp because Flutter caches decoded images by
  /// file path — reusing one showed the old photo until the app restarted.
  Future<void> _writeAvatarFile(Uint8List bytes, {required String? url}) async {
    final dir = await getApplicationDocumentsDirectory();
    final previous = await _store.readAvatarPath();
    final path =
        '${dir.path}/omnia_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(bytes);
    await _store.saveAvatarPath(path);
    await _store.saveAvatarUrl(url);

    if (previous != null && previous.isNotEmpty && previous != path) {
      try {
        await File(previous).delete();
      } catch (_) {
        // Already gone — fine.
      }
    }
    _ref.invalidate(avatarFileProvider);
  }
}

final profileSyncProvider = Provider<ProfileSync>(ProfileSync.new);
