import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/auth_mode.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/widgets/hud.dart';
import '../../state/contacts.dart';
import '../../state/notices.dart';
import '../../state/providers.dart';
import '../contacts/contacts_screen.dart';
import 'scan_did_screen.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _toDidController = TextEditingController();
  final _amountController = TextEditingController();
  bool _busy = false;

  /// Latest known spendable balance (from balanceProvider), for validation
  /// and the "remaining after send" hint.
  int? _available;

  @override
  void dispose() {
    _toDidController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String? _validateDid(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Enter a recipient DID';
    if (!value.startsWith('did:omnia:')) {
      return 'DID must start with did:omnia:';
    }
    return null;
  }

  String? _validateAmount(String? v) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null || n <= 0) return 'Enter a positive whole number';
    final bal = _available;
    if (bal != null && n > bal) return 'You only have ${Fmt.ubc(bal)}';
    return null;
  }

  Future<void> _scanDid() async {
    Haptics.medium();
    final did = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanDidScreen()),
    );
    if (did != null) {
      Haptics.selection();
      _toDidController.text = did;
    }
  }

  Future<void> _pickContact() async {
    Haptics.light();
    final did = await showContactPicker(context, ref);
    if (did != null) {
      Haptics.selection();
      _toDidController.text = did;
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _toDidController.text = data!.text!.trim();
    }
  }

  void _setMax() {
    final bal = _available;
    if (bal != null && bal > 0) {
      Haptics.selection();
      _amountController.text = bal.toString();
    }
  }

  String _signedByLine(WidgetRef ref) {
    final mode =
        ref.watch(authModeProvider).valueOrNull ?? AuthMode.selfCustody;
    return mode == AuthMode.supabase
        ? 'Authorized through your Omnia account.'
        : 'Signed on-device with your private key.';
  }

  Future<bool> _confirmWithBiometrics() async {
    final auth = LocalAuthentication();
    try {
      final canCheck = await auth.isDeviceSupported();
      if (!canCheck) return true; // no biometric hardware — allow
      return auth.authenticate(
        localizedReason: 'Confirm to send UBC',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } on PlatformException {
      return true; // biometrics unavailable/misconfigured — don't block
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final toDid = _toDidController.text.trim();
    final amount = int.parse(_amountController.text.trim());

    Haptics.medium();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmSheet(toDid: toDid, amount: amount),
    );
    if (proceed != true) return;

    if (!await _confirmWithBiometrics()) return;
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      // Blocking HUD: dimmed screen + centered spinner square while the
      // transfer is in flight.
      final result = await runWithHud(
        context,
        () => ref
            .read(walletRepositoryProvider)
            .send(toDid: toDid, amount: amount),
      );
      ref.invalidate(balanceProvider);
      ref.invalidate(historyProvider);
      ref.read(noticesProvider.notifier).add(
            type: NoticeType.sent,
            title: 'Sent ${Fmt.ubc(result.amount)}',
            body: 'To ${Fmt.shortDid(toDid)} · '
                'new balance ${Fmt.ubc(result.newBalance)}',
          );
      if (!mounted) return;
      Haptics.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sent ${Fmt.ubc(result.amount)} · new balance ${Fmt.ubc(result.newBalance)}',
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        Haptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Keep the latest balance for validation / hints.
    _available = ref.watch(balanceProvider).valueOrNull?.balance;
    final contacts = ref.watch(contactsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Send UBC')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SoulboundNotice(),
              const SizedBox(height: 20),
              TextFormField(
                controller: _toDidController,
                validator: _validateDid,
                decoration: InputDecoration(
                  labelText: 'Recipient DID',
                  hintText: 'did:omnia:…',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Contacts',
                        icon: const Icon(Icons.contacts_outlined),
                        onPressed: _pickContact,
                      ),
                      IconButton(
                        tooltip: 'Scan QR',
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scanDid,
                      ),
                      IconButton(
                        tooltip: 'Paste',
                        icon: const Icon(Icons.paste),
                        onPressed: _paste,
                      ),
                    ],
                  ),
                ),
              ),
              // Offer to save a freshly-entered DID that isn't a contact yet.
              AnimatedBuilder(
                animation: _toDidController,
                builder: (context, _) {
                  final did = _toDidController.text.trim();
                  final known =
                      ref.read(contactsProvider.notifier).byDid(did) != null;
                  if (!did.startsWith('did:omnia:') || known) {
                    return const SizedBox.shrink();
                  }
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          editContact(context, ref, presetDid: did),
                      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                      label: const Text('Save to contacts'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                validator: _validateAmount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  suffixText: 'UBC',
                  helperText: _available == null
                      ? null
                      : 'Available: ${Fmt.ubc(_available!)}',
                  // NOTE: `suffix` + `suffixText` together is illegal in
                  // Flutter; use `suffixIcon` for the Max action instead.
                  suffixIcon: TextButton(
                    onPressed: _available == null ? null : _setMax,
                    child: const Text('Max'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _RemainingHint(
                amountController: _amountController,
                available: _available,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Review & send'),
              ),
              const SizedBox(height: 12),
              Text(
                contacts.isEmpty
                    ? _signedByLine(ref)
                    : '${_signedByLine(ref)} '
                        'Tap the contacts icon to reuse a saved DID.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows "Remaining after send" as the amount changes.
class _RemainingHint extends StatelessWidget {
  const _RemainingHint(
      {required this.amountController, required this.available});

  final TextEditingController amountController;
  final int? available;

  @override
  Widget build(BuildContext context) {
    if (available == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: amountController,
      builder: (context, _) {
        final amount = int.tryParse(amountController.text.trim()) ?? 0;
        if (amount <= 0) return const SizedBox.shrink();
        final remaining = available! - amount;
        final over = remaining < 0;
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            over
                ? 'Exceeds your balance by ${Fmt.ubc(-remaining)}'
                : 'Remaining after send: ${Fmt.ubc(remaining)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: over
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}

class _SoulboundNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'UBC is soulbound. Sending spends (burns) tokens from your '
              'balance — the recipient DID is recorded for provenance but is '
              'NOT credited the amount.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.toDid, required this.amount});
  final String toDid;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm send'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Amount: ${Fmt.ubc(amount)}'),
          const SizedBox(height: 8),
          Text('To: $toDid'),
          const SizedBox(height: 12),
          const Text(
            'This spends the amount from your balance and cannot be undone.',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Send'),
        ),
      ],
    );
  }
}
