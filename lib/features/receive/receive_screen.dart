import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../core/ui/button.dart';
import '../../core/ui/header.dart';
import '../../core/ui/press.dart';
import '../../core/ui/sheet.dart';
import '../../core/ui/states.dart';
import '../../crypto/key_manager.dart';
import '../../data/payment_request.dart';
import '../../state/providers.dart';

/// Shows the wallet's own DID as a QR code and copyable text so others can
/// record it, and optionally requests a specific amount (encoded into the QR
/// as an `omnia:` payment-request URI).
///
/// UBC is soulbound, so a request only prefills the sender's Send form —
/// nothing is credited here.
class ReceiveScreen extends ConsumerWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final identityAsync = ref.watch(identityProvider);

    return Scaffold(
      backgroundColor: o.bg,
      appBar: const OmniaHeader(title: 'Receive'),
      body: identityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => OmniaErrorState(message: '$e'),
        data: (identity) => identity == null
            ? const OmniaEmptyState(
                icon: Iconsax.empty_wallet_copy,
                title: 'No wallet found',
              )
            : FadeIn(child: _RequestView(identity: identity)),
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
  int? _amount;

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
    showOmniaToast(
      context,
      message: _amount == null ? 'DID copied' : 'Payment request copied',
      icon: Iconsax.copy_success_copy,
    );
  }

  Future<void> _editAmount() async {
    final value = await showOmniaInput(
      context,
      title: 'Request an amount',
      subtitle: 'The sender sees this pre-filled in their Send form.',
      initialValue: _amount?.toString(),
      hintText: '0',
      confirmLabel: 'Set amount',
      keyboardType: TextInputType.number,
      formatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (v) {
        if (v.isEmpty) return null; // empty clears the request
        final n = int.tryParse(v);
        return (n == null || n <= 0) ? 'Enter a positive whole number' : null;
      },
    );
    if (value == null || !mounted) return;
    setState(() => _amount = int.tryParse(value));
  }

  void _clearAmount() {
    Haptics.selection();
    setState(() => _amount = null);
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final amount = _amount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.x4l),
      children: [
        // A QR code needs a light quiet zone to scan reliably, so this panel
        // stays white in every theme — it is a scanning target, not a surface.
        Center(
          child: Container(
            padding: const EdgeInsets.all(Space.xl),
            decoration: BoxDecoration(
              color: OmniaPalette.white,
              borderRadius: Radii.rXl,
              border: Border.all(color: o.borderLow),
            ),
            child: QrImageView(
              data: _payload,
              version: QrVersions.auto,
              size: 216,
              backgroundColor: OmniaPalette.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: OmniaPalette.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: OmniaPalette.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.xl),

        if (amount != null) ...[
          Center(
            child: Pressable(
              onTap: _clearAmount,
              feel: PressFeel.subtle,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.lg,
                  vertical: Space.sm,
                ),
                decoration: BoxDecoration(
                  color: o.accent.withValues(alpha: 0.12),
                  borderRadius: Radii.rFull,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Requesting ${Fmt.ubc(amount)}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: FontSizes.sm,
                        fontWeight: Weights.semiBold,
                        color: o.accent,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Icon(Iconsax.close_circle_copy, size: 15, color: o.accent),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
        ],

        // The DID itself, monospaced so hex is scannable by eye.
        Pressable(
          onTap: _copy,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.md,
            ),
            decoration: BoxDecoration(
              color: o.bg25,
              borderRadius: Radii.rMd,
              border: Border.all(color: o.borderLow),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.identity.did,
                    textAlign: TextAlign.center,
                    style: monoStyle(fontSize: FontSizes.sm, height: LineHeights.snug, color: o.textHigh),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Icon(Iconsax.copy_copy, size: 17, color: o.textLow),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.xl),

        Row(
          children: [
            Expanded(
              child: OmniaButton(
                label: amount == null ? 'Copy DID' : 'Copy request',
                icon: Iconsax.copy_copy,
                expand: true,
                onPressed: _copy,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: OmniaButton(
                label: amount == null ? 'Request' : 'Change',
                icon: Iconsax.coin_copy,
                expand: true,
                color: ButtonColor.secondary,
                onPressed: _editAmount,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xxl),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Iconsax.info_circle_copy, size: 16, color: o.textLow),
            const SizedBox(width: Space.md - 2),
            Expanded(
              child: Text(
                'UBC is soulbound — a request only pre-fills the sender\'s '
                'form. No balance is transferred to you.',
                style: theme.textTheme.bodySmall?.copyWith(color: o.textLow),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
