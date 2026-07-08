import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/avatar.dart';
import '../../state/providers.dart';
import '../brand/identicon.dart';

/// The user's avatar: their chosen profile photo when set, otherwise the
/// deterministic identicon derived from their DID.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(avatarFileProvider).valueOrNull;
    if (file != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: FileImage(file),
      );
    }
    final did = ref.watch(identityProvider).valueOrNull?.did ?? 'omnia';
    return ClipOval(child: Identicon(seed: did, size: size));
  }
}
