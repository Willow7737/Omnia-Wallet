import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/format.dart';
import '../../state/providers.dart';
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

  Future<void> _scanDid() async {
    final did = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanDidScreen()),
    );
    if (did != null) {
      _toDidController.text = did;
    }
  }

  String? _validateAmount(String? v) {
    final value = (v ?? '').trim();
    final n = int.tryParse(value);
    if (n == null || n <= 0) return 'Enter a positive whole number';
    return null;
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

    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmSheet(toDid: toDid, amount: amount),
    );
    if (proceed != true) return;

    if (!await _confirmWithBiometrics()) return;

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(walletRepositoryProvider)
          .send(toDid: toDid, amount: amount);
      ref.invalidate(balanceProvider);
      ref.invalidate(historyProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Sent ${Fmt.ubc(result.amount)} · new balance ${Fmt.ubc(result.newBalance)}')),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Send failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                        tooltip: 'Scan QR',
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scanDid,
                      ),
                      IconButton(
                        tooltip: 'Paste',
                        icon: const Icon(Icons.paste),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            _toDidController.text = data!.text!.trim();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                validator: _validateAmount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  suffixText: 'UBC',
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Review & send'),
              ),
              const SizedBox(height: 12),
              Text(
                'Signed on-device with your private key.',
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
