import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/avatar.dart';
import '../../state/providers.dart';
import '../brand/identicon.dart';
import '../theme.dart';

/// The signed-in user's avatar: their chosen photo when set, otherwise the
/// identicon derived from their DID.
///
/// Always circular with a hairline ring. The ring is what stops a light
/// identicon from bleeding into a light page — Bluesky puts the same
/// `border_contrast_low` outline on every avatar for exactly that reason.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, required this.size, this.ring = true});

  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final file = ref.watch(avatarFileProvider).valueOrNull;
    final did = ref.watch(identityProvider).valueOrNull?.did ?? 'omnia';

    final Widget inner = file != null
        ? Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            // A stale path (photo deleted from disk) must degrade to the
            // identicon, not to a grey error box.
            errorBuilder: (_, __, ___) => Identicon(seed: did, size: size),
          )
        : Identicon(seed: did, size: size);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: o.bg50,
        border: ring ? Border.all(color: o.borderLow) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: inner,
    );
  }
}

/// A circular avatar for any DID (a counterparty in a transfer, a contact) —
/// no Riverpod, no photo, just the deterministic identicon.
class DidAvatar extends StatelessWidget {
  const DidAvatar({super.key, required this.did, this.size = 40});

  final String did;
  final double size;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: o.borderLow),
      ),
      clipBehavior: Clip.antiAlias,
      child: Identicon(seed: did, size: size),
    );
  }
}

/// A tinted circular glyph — the leading element on activity and notification
/// rows, where the subject is an event rather than a person.
class IconAvatar extends StatelessWidget {
  const IconAvatar({
    super.key,
    required this.icon,
    required this.tint,
    this.size = 40,
    this.iconSize = 19,
  });

  final IconData icon;
  final Color tint;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: iconSize, color: tint),
    );
  }
}
