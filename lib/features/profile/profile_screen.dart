import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../core/ui/avatar.dart';
import '../../core/ui/button.dart';
import '../../core/ui/header.dart';
import '../../core/ui/list_row.dart';
import '../../core/ui/press.dart';
import '../../core/ui/sheet.dart';
import '../../core/ui/states.dart';
import '../../state/avatar.dart';
import '../../state/providers.dart';
import '../shell/app_shell.dart';

/// The Profile tab: identity at a glance, then everything that hangs off it.
///
/// Laid out like a Bluesky profile — a banner-height accent wash, the avatar
/// overlapping its lower edge, the name and handle beneath, then flat rows.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final identityAsync = ref.watch(identityProvider);
    final displayName = ref.watch(displayNameProvider).valueOrNull;
    final email = ref.watch(supabaseEmailProvider);

    return Scaffold(
      backgroundColor: o.bg,
      appBar: OmniaHeader(
        title: 'Profile',
        showBack: false,
        actions: [
          OmniaIconButton(
            icon: Iconsax.setting_2_copy,
            tooltip: 'Settings',
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
      body: identityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => OmniaErrorState(
          message: friendlyError(e).message,
          onRetry: () => ref.invalidate(identityProvider),
        ),
        data: (identity) {
          if (identity == null) {
            return const OmniaEmptyState(
              icon: Iconsax.empty_wallet_copy,
              title: 'No wallet found',
            );
          }
          final name = (displayName == null || displayName.isEmpty)
              ? Fmt.shortDid(identity.did)
              : displayName;

          return ListView(
            padding: EdgeInsets.only(bottom: tabBarInset(context) + Space.xl),
            children: [
              _ProfileHeader(
                name: name,
                did: identity.did,
                email: email,
                hasName: displayName != null && displayName.isNotEmpty,
                onEditName: () => _editName(context, ref, displayName ?? ''),
                onEditPhoto: () => _changePhoto(context, ref),
              ),
              const Hairline(),

              OmniaRow(
                title: 'What is Omnia?',
                subtitle: 'A plain-language guide to the app and UBC',
                icon: Iconsax.message_question_copy,
                chevron: true,
                onTap: () => context.push('/about'),
              ),
              const Hairline(indent: Space.lg),
              OmniaRow(
                title: 'Show my QR code',
                subtitle: 'Let someone scan your DID',
                icon: Iconsax.scan_copy,
                chevron: true,
                onTap: () => context.push('/receive'),
              ),
              const Hairline(indent: Space.lg),
              OmniaRow(
                title: 'Address book',
                subtitle: 'Saved recipient DIDs',
                icon: Iconsax.profile_2user_copy,
                chevron: true,
                onTap: () => context.push('/contacts'),
              ),
              const Hairline(indent: Space.lg),
              OmniaRow(
                title: 'Governance',
                subtitle: 'Proposals and voting',
                icon: Iconsax.chart_2_copy,
                chevron: true,
                onTap: () => context.push('/governance'),
              ),
              const Hairline(indent: Space.lg),
              OmniaRow(
                title: 'Safety',
                subtitle: 'Guidelines and blocked accounts',
                icon: Iconsax.shield_tick_copy,
                chevron: true,
                onTap: () => context.push('/safety'),
              ),
              const Hairline(),

              const OmniaSectionLabel('Identity'),
              OmniaRow(
                title: 'Your DID',
                subtitle: identity.did,
                icon: Iconsax.personalcard_copy,
                trailingIcon: Iconsax.copy_copy,
                onTap: () {
                  Haptics.selection();
                  Clipboard.setData(ClipboardData(text: identity.did));
                  showOmniaToast(
                    context,
                    message: 'DID copied',
                    icon: Iconsax.copy_success_copy,
                  );
                },
              ),
              if (email != null) ...[
                const Hairline(indent: Space.lg),
                OmniaRow(
                  title: 'Signed in as',
                  subtitle: email,
                  icon: Iconsax.sms_copy,
                ),
              ],
              const Hairline(),

              const OmniaSectionLabel('Advanced'),
              OmniaRow(
                title: 'Network',
                subtitle: 'Node status, version, peers',
                icon: Iconsax.global_copy,
                chevron: true,
                onTap: () => context.push('/network'),
              ),
              const Hairline(indent: Space.lg),
              OmniaRow(
                title: 'Settings',
                subtitle: 'Appearance, security, node',
                icon: Iconsax.setting_2_copy,
                chevron: true,
                onTap: () => context.push('/settings'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changePhoto(BuildContext context, WidgetRef ref) async {
    try {
      final saved = await pickAndSaveAvatar(ref.read(secureStoreProvider));
      if (!saved) return;
      ref.invalidate(avatarFileProvider);
      Haptics.success();
      if (context.mounted) {
        showOmniaToast(context, message: 'Profile photo updated');
      }
    } catch (e) {
      if (!context.mounted) return;
      Haptics.error();
      showOmniaToast(context, message: friendlyError(e).message, error: true);
    }
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final name = await showOmniaInput(
      context,
      title: 'Display name',
      subtitle: 'Shown only on this device.',
      initialValue: current,
      hintText: 'How should we call you?',
      textCapitalization: TextCapitalization.words,
    );
    if (name == null) return;
    await ref.read(secureStoreProvider).saveDisplayName(name);
    ref.invalidate(displayNameProvider);
  }
}

/// Avatar over an accent wash, name, handle, and the two identity actions.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.did,
    required this.email,
    required this.hasName,
    required this.onEditName,
    required this.onEditPhoto,
  });

  final String name;
  final String did;
  final String? email;
  final bool hasName;
  final VoidCallback onEditName;
  final VoidCallback onEditPhoto;

  static const double _bannerHeight = 96;
  static const double _avatarSize = 84;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner + overlapping avatar. The stack is sized to the banner plus
        // the half of the avatar that hangs below it.
        SizedBox(
          height: _bannerHeight + _avatarSize / 2 + Space.sm,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: _bannerHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      o.accent.withValues(alpha: o.isDark ? 0.28 : 0.18),
                      o.accent.withValues(alpha: 0.04),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: Space.lg,
                top: _bannerHeight - _avatarSize / 2,
                child: Pressable(
                  onTap: onEditPhoto,
                  feel: PressFeel.firm,
                  semanticLabel: 'Change profile photo',
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: o.bg,
                          shape: BoxShape.circle,
                        ),
                        child: const UserAvatar(size: _avatarSize),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: o.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: o.bg, width: 2),
                          ),
                          child: const Icon(
                            Iconsax.camera_copy,
                            size: 13,
                            color: OmniaPalette.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.md,
            Space.lg,
            Space.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 2),
              Text(
                Fmt.shortDid(did),
                style: theme.textTheme.bodyMedium?.copyWith(color: o.textLow),
              ),
              const SizedBox(height: Space.lg),
              // Wrap, not Row: "Set a display name" + "Change photo" do not
              // fit side by side on a narrow screen at large text sizes, and
              // stacking is better than truncating either label.
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  OmniaButton(
                    label: hasName ? 'Edit name' : 'Set a display name',
                    icon: Iconsax.edit_2_copy,
                    size: ButtonSize.small,
                    color: ButtonColor.secondary,
                    onPressed: onEditName,
                  ),
                  OmniaButton(
                    label: 'Change photo',
                    icon: Iconsax.gallery_copy,
                    size: ButtonSize.small,
                    color: ButtonColor.secondary,
                    onPressed: onEditPhoto,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
