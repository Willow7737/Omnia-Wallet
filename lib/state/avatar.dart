import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// The user's chosen profile photo (a local file), or null when unset —
/// the UI falls back to the DID identicon.
///
/// The file is a cache of what the account holds; [ProfileSync] owns writing
/// it, so that picking, uploading and restoring stay one decision.
final avatarFileProvider = FutureProvider<File?>((ref) async {
  final path = await ref.watch(secureStoreProvider).readAvatarPath();
  if (path == null || path.isEmpty) return null;
  final file = File(path);
  return await file.exists() ? file : null;
});
