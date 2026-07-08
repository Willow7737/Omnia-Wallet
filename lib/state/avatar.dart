import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../crypto/secure_store.dart';
import 'providers.dart';

/// The user's chosen profile photo (a local file), or null when unset —
/// the UI falls back to the DID identicon.
final avatarFileProvider = FutureProvider<File?>((ref) async {
  final path = await ref.watch(secureStoreProvider).readAvatarPath();
  if (path == null || path.isEmpty) return null;
  final file = File(path);
  return await file.exists() ? file : null;
});

/// Pick a photo from the gallery and persist it as the profile picture.
/// Returns true when a new photo was saved (caller should invalidate
/// [avatarFileProvider]).
Future<bool> pickAndSaveAvatar(SecureStore store) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 800,
    imageQuality: 85,
  );
  if (picked == null) return false;

  final dir = await getApplicationDocumentsDirectory();
  final oldPath = await store.readAvatarPath();
  // A fresh file name per change busts Flutter's image cache.
  final path =
      '${dir.path}/omnia_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
  await File(path).writeAsBytes(await picked.readAsBytes());
  await store.saveAvatarPath(path);
  if (oldPath != null && oldPath.isNotEmpty) {
    try {
      await File(oldPath).delete();
    } catch (_) {
      // Old file already gone — fine.
    }
  }
  return true;
}
