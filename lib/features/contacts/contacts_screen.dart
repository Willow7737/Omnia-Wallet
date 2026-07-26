import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

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
import '../../data/contact.dart';
import '../../state/contacts.dart';

/// Full address-book management.
class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final contacts = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: o.bg,
      appBar: OmniaHeader(
        title: 'Address book',
        actions: [
          OmniaIconButton(
            icon: Iconsax.user_add_copy,
            tooltip: 'Add contact',
            onTap: () => editContact(context, ref),
          ),
        ],
      ),
      body: contacts.isEmpty
          ? OmniaEmptyState(
              icon: Iconsax.profile_2user_copy,
              title: 'No saved contacts',
              message: 'Save recipient DIDs here so you can pick them when '
                  'sending, instead of pasting a hex string every time.',
              actionLabel: 'Add a contact',
              onAction: () => editContact(context, ref),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: Space.x4l),
              itemCount: contacts.length,
              separatorBuilder: (_, __) => const Hairline(indent: 68),
              itemBuilder: (_, i) => FadeIn(
                delay: FadeIn.stagger(i),
                child: _ContactTile(contact: contacts[i]),
              ),
            ),
    );
  }
}

class _ContactTile extends ConsumerWidget {
  const _ContactTile({required this.contact});

  final Contact contact;

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final action = await showOmniaMenu<String>(
      context,
      title: contact.label.isEmpty ? Fmt.shortDid(contact.did) : contact.label,
      actions: const [
        SheetAction(
          label: 'Copy DID',
          value: 'copy',
          icon: Iconsax.copy_copy,
        ),
        SheetAction(
          label: 'Edit label',
          value: 'edit',
          icon: Iconsax.edit_2_copy,
        ),
        SheetAction(
          label: 'Delete contact',
          value: 'delete',
          icon: Iconsax.trash_copy,
          destructive: true,
        ),
      ],
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case 'copy':
        Haptics.selection();
        await Clipboard.setData(ClipboardData(text: contact.did));
        if (context.mounted) {
          showOmniaToast(
            context,
            message: 'DID copied',
            icon: Iconsax.copy_success_copy,
          );
        }
      case 'edit':
        await editContact(context, ref, existing: contact);
      case 'delete':
        final confirmed = await showOmniaConfirm(
          context,
          icon: Iconsax.trash_copy,
          title: 'Delete contact?',
          message: 'The DID stays valid — this only removes it from your '
              'address book.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (confirmed) {
          await ref.read(contactsProvider.notifier).remove(contact.did);
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final label =
        contact.label.isEmpty ? Fmt.shortDid(contact.did) : contact.label;

    return Pressable(
      onTap: () {
        Haptics.selection();
        Clipboard.setData(ClipboardData(text: contact.did));
        showOmniaToast(
          context,
          message: 'DID copied',
          icon: Iconsax.copy_success_copy,
        );
      },
      onLongPress: () => _menu(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md,
        ),
        child: Row(
          children: [
            DidAvatar(did: contact.did, size: 40),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: FontSizes.md,
                      fontWeight: Weights.semiBold,
                      height: LineHeights.snug,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Fmt.shortDid(contact.did),
                    style: monoStyle(fontSize: FontSizes.xs, color: o.textLow),
                  ),
                ],
              ),
            ),
            OmniaIconButton(
              icon: Iconsax.more_copy,
              size: 18,
              box: 36,
              color: o.textLow,
              tooltip: 'More',
              onTap: () => _menu(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add or edit a contact.
///
/// When [existing] is provided the DID is fixed — identity doesn't change, only
/// the label does — so the sheet collects a single field either way.
Future<void> editContact(
  BuildContext context,
  WidgetRef ref, {
  Contact? existing,
  String? presetDid,
}) async {
  final knownDid = existing?.did ?? presetDid;

  // With a DID already in hand there is exactly one thing left to ask.
  if (knownDid != null) {
    final label = await showOmniaInput(
      context,
      title: existing == null ? 'Save contact' : 'Edit contact',
      subtitle: Fmt.shortDid(knownDid),
      initialValue: existing?.label,
      hintText: 'Name this contact',
      textCapitalization: TextCapitalization.words,
    );
    if (label == null) return;
    Haptics.selection();
    await ref
        .read(contactsProvider.notifier)
        .upsert(Contact(label: label, did: knownDid));
    return;
  }

  // Otherwise collect the DID first, then the label.
  final did = await showOmniaInput(
    context,
    title: 'New contact',
    subtitle: 'Paste the DID you want to save.',
    hintText: 'did:omnia:…',
    confirmLabel: 'Next',
    validator: (v) =>
        v.startsWith('did:omnia:') ? null : 'A DID must start with did:omnia:',
  );
  if (did == null || did.isEmpty || !context.mounted) return;

  final label = await showOmniaInput(
    context,
    title: 'Name this contact',
    subtitle: Fmt.shortDid(did),
    hintText: 'e.g. Ama',
    textCapitalization: TextCapitalization.words,
  );
  if (label == null) return;

  Haptics.selection();
  await ref
      .read(contactsProvider.notifier)
      .upsert(Contact(label: label, did: did));
}

/// Bottom-sheet picker that returns the chosen contact's DID, or null.
Future<String?> showContactPicker(BuildContext context, WidgetRef ref) {
  final contacts = ref.read(contactsProvider);

  return showOmniaSheet<String>(
    context,
    title: 'Choose a contact',
    scrollable: contacts.length > 6,
    initialSize: 0.5,
    builder: (sheetContext) {
      if (contacts.isEmpty) {
        return const OmniaEmptyState(
          icon: Iconsax.profile_2user_copy,
          title: 'No saved contacts yet',
          message: 'Contacts you save will be pickable here.',
          compact: true,
        );
      }
      return ListView.separated(
        primary: contacts.length > 6,
        shrinkWrap: contacts.length <= 6,
        physics:
            contacts.length <= 6 ? const NeverScrollableScrollPhysics() : null,
        padding: EdgeInsets.only(
          top: Space.sm,
          bottom: Space.xl + MediaQuery.viewPaddingOf(sheetContext).bottom,
        ),
        itemCount: contacts.length,
        separatorBuilder: (_, __) => const Hairline(indent: 68),
        itemBuilder: (_, i) {
          final c = contacts[i];
          return Pressable(
            onTap: () => Navigator.of(sheetContext).pop(c.did),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.lg,
                vertical: Space.md,
              ),
              child: Row(
                children: [
                  DidAvatar(did: c.did, size: 40),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.label.isEmpty ? Fmt.shortDid(c.did) : c.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: FontSizes.md,
                            fontWeight: Weights.semiBold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Fmt.shortDid(c.did),
                          style: monoStyle(
                              fontSize: FontSizes.xs,
                              color: context.omnia.textLow),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
