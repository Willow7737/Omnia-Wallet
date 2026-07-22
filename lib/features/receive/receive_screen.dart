import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../crypto/key_manager.dart';
import '../../data/payment_request.dart';
import '../../state/providers.dart';

/// Shows the wallet's own DID as a QR code and copyable text so others can
/// record it, and optionally requests a specific amount (encoded into the QR
/// as an `omnia:` payment-request URI). UBC is soulbound, so a request only
/// prefills the sender's Send form — nothing is credited here.
class ReceiveScreen extends ConsumerWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(identityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Receive')),
      body: Center(
        child: identityAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (identity) {
            if (identity == null) {
              return const Text('No wallet found');
            }
            return FadeSlideIn(child: _RequestView(identity: identity));
          },
        ),
      ),
    );
  }
}

class _RequestView extends StatefulWidget {
  const _RequestView({required this.identity});
  final WalletIdentity identity;

  @override
  State<_RequestView> createState() => _RequestViewState();
}

class _RequestViewState extends State<_RequestView> {
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int? get _amount {
    final n = int.tryParse(_amountController.text.trim());
    return (n != null && n > 0) ? n : null;
  }

  /// The QR/share payload. With an amount it's an `omnia:` payment-request
  /// URI; without one it's the bare DID, so nothing regresses for scanners
  /// that only understand a plain DID.
  String get _payload {
    final amount = _amount;
    return amount == null
        ? widget.identity.did
        : PaymentRequest(did: widget.identity.did, amount: amount).toUri();
  }

  void _copy() {
    Haptics.selection();
    Clipboard.setData(ClipboardData(text: _payload));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(_amount == null ? 'DID copied' : 'Payment request copied'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: _payload,
              version: QrVersions.auto,
              size: 220,
            ),
          ),
          const SizedBox(height: 16),
          if (_amount != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Requesting ${Fmt.ubc(_amount!)}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          SelectableText(
            widget.identity.did,
            textAlign: TextAlign.center,
            style:
                theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 20),
          // Optional amount to request. Changing it re-renders the QR.
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Request an amount (optional)',
              suffixText: 'UBC',
              helperText: 'The sender sees this pre-filled in their Send form.',
              suffixIcon: _amountController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        Haptics.selection();
                        _amountController.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _copy,
            icon: const Icon(Icons.copy),
            label: Text(_amount == null ? 'Copy DID' : 'Copy request'),
          ),
          const SizedBox(height: 8),
          Text(
            'UBC is soulbound — a request just pre-fills the sender\'s form; '
            'no balance is transferred to you.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
