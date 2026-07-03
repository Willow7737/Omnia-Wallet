import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../crypto/key_manager.dart';
import '../../state/providers.dart';

/// Shows the wallet's own DID as a QR code and copyable text so others can
/// record it. (UBC is soulbound, so this is for identity/provenance, not for
/// receiving spendable balance.)
class ReceiveScreen extends ConsumerWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(identityProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Your DID')),
      body: Center(
        child: identityAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (identity) {
            if (identity == null) {
              return const Text('No wallet found');
            }
            return _DidView(identity: identity, theme: theme);
          },
        ),
      ),
    );
  }
}

class _DidView extends StatelessWidget {
  const _DidView({required this.identity, required this.theme});
  final WalletIdentity identity;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              data: identity.did,
              version: QrVersions.auto,
              size: 220,
            ),
          ),
          const SizedBox(height: 24),
          SelectableText(
            identity.did,
            textAlign: TextAlign.center,
            style:
                theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: identity.did));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('DID copied')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy DID'),
          ),
        ],
      ),
    );
  }
}
