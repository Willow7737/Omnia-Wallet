import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../data/contact.dart';
import '../../state/contacts.dart';

/// Full address-book management screen.
class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Address book')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          Haptics.light();
          await editContact(context, ref);
        },
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add'),
      ),
      body: contacts.isEmpty
          ? const _EmptyContacts()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: contacts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => FadeSlideIn(
                delay: Duration(milliseconds: 25 * (i.clamp(0, 8))),
                child: _ContactTile(contact: contacts[i]),
              ),
            ),
    );
  }
}

class _EmptyContacts extends StatelessWidget {
  const _EmptyContacts();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contacts_outlined,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No saved contacts', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Save recipient DIDs here so you can pick them when sending.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends ConsumerWidget {
  const _ContactTile({required this.contact});
  final Contact contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label =
        contact.label.isEmpty ? Fmt.shortDid(contact.did) : contact.label;
    return ListTile(
      leading: CircleAvatar(
        child: Text(
          label.isNotEmpty ? label.characters.first.toUpperCase() : '?',
        ),
      ),
      title: Text(label),
      subtitle: Text(Fmt.shortDid(contact.did)),
      onTap: () {
        Haptics.selection();
        Clipboard.setData(ClipboardData(text: contact.did));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('DID copied')),
        );
      },
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'edit') {
            await editContact(context, ref, existing: contact);
          } else if (v == 'delete') {
            Haptics.warning();
            await ref.read(contactsProvider.notifier).remove(contact.did);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

/// Add or edit a contact via a dialog. When [existing] is provided the DID is
/// locked (identity is fixed; only the label changes).
Future<void> editContact(
  BuildContext context,
  WidgetRef ref, {
  Contact? existing,
  String? presetDid,
}) async {
  final labelCtrl = TextEditingController(text: existing?.label ?? '');
  final didCtrl = TextEditingController(text: existing?.did ?? presetDid ?? '');
  final formKey = GlobalKey<FormState>();

  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(existing == null ? 'New contact' : 'Edit contact'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: labelCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: didCtrl,
              enabled: existing == null,
              decoration: const InputDecoration(
                labelText: 'DID',
                hintText: 'did:omnia:…',
              ),
              validator: (v) {
                final value = (v ?? '').trim();
                if (!value.startsWith('did:omnia:')) {
                  return 'DID must start with did:omnia:';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(context).pop(true);
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (saved == true) {
    Haptics.selection();
    await ref.read(contactsProvider.notifier).upsert(
          Contact(label: labelCtrl.text, did: didCtrl.text),
        );
  }
}

/// Bottom-sheet picker that returns the chosen contact's DID, or null.
Future<String?> showContactPicker(BuildContext context, WidgetRef ref) {
  final contacts = ref.read(contactsProvider);
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (_) {
      if (contacts.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No saved contacts yet')),
        );
      }
      return ListView(
        shrinkWrap: true,
        children: [
          for (final c in contacts)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(c.label.isEmpty ? Fmt.shortDid(c.did) : c.label),
              subtitle: Text(Fmt.shortDid(c.did)),
              onTap: () => Navigator.of(context).pop(c.did),
            ),
        ],
      );
    },
  );
}
