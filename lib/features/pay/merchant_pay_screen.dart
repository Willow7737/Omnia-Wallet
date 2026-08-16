import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/design/tokens.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/button.dart';
import '../../core/ui/header.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Customer-side merchant payment screen.
///
/// The QR contains a GHS price, a time-limited OMNIA amount, and the
/// merchant's Ed25519 settlement address. The wallet signs the final transfer
/// locally; it never marks the payment confirmed by itself.
class MerchantPayScreen extends ConsumerStatefulWidget {
  const MerchantPayScreen({super.key});

  @override
  ConsumerState<MerchantPayScreen> createState() => _MerchantPayScreenState();
}

class _MerchantPayScreenState extends ConsumerState<MerchantPayScreen> {
  final _scannerController = MobileScannerController();
  MerchantPaymentRequest? _request;
  bool _scanning = true;
  bool _busy = false;
  String? _error;
  FinancialTransferResult? _result;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_scanning || _request != null) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic> ||
            decoded['protocol'] != 'omnia') {
          continue;
        }
        final request = MerchantPaymentRequest.fromJson(decoded);
        if (request.paymentId.isEmpty || request.merchantId.isEmpty) continue;
        _scannerController.stop();
        if (!mounted) return;
        setState(() {
          _request = request;
          _scanning = false;
          _error = null;
        });
        return;
      } catch (_) {
        // Ignore unrelated QR codes; the scanner remains active.
      }
    }
  }

  Future<void> _pay() async {
    final request = _request;
    final merchantKey = request?.merchantPublicKey;
    if (request == null) return;
    if (merchantKey == null ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(merchantKey)) {
      setState(() =>
          _error = 'This merchant request has no valid settlement address.');
      return;
    }
    if (request.quoteExpiryMs <= DateTime.now().millisecondsSinceEpoch) {
      setState(
          () => _error = 'This merchant quote has expired. Ask for a new QR.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(walletRepositoryProvider).sendFinancial(
            toPublicKeyHex: merchantKey,
            amount: request.omniaAmountPlancks,
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        _busy = false;
      });
      ref.invalidate(financialBalanceProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(error).message;
      });
    }
  }

  String _ghs(int pesewas) => 'GHS ${(pesewas / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final request = _request;
    final result = _result;
    return Scaffold(
      backgroundColor: o.bg,
      appBar: const OmniaHeader(title: 'Pay merchant'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Space.lg, Space.md, Space.lg, Space.x5l),
          children: [
            if (_scanning) ...[
              Text('Scan merchant QR',
                  style: TextStyle(
                      color: o.textHigh,
                      fontSize: FontSizes.xxl,
                      fontWeight: Weights.bold)),
              const SizedBox(height: Space.sm),
              Text(
                  'Scan a time-limited Omnia payment request. Never pay from a screenshot whose amount or expiry you cannot verify.',
                  style: TextStyle(
                      color: o.textMedium, height: LineHeights.relaxed)),
              const SizedBox(height: Space.lg),
              ClipRRect(
                borderRadius: Radii.rLg,
                child: SizedBox(
                  height: 320,
                  child: MobileScanner(
                      controller: _scannerController, onDetect: _onDetect),
                ),
              ),
              const SizedBox(height: Space.md),
              Center(
                  child: Text('Point the camera at the merchant QR code',
                      style: TextStyle(color: o.textMedium))),
            ] else if (request != null && result == null) ...[
              _RequestCard(request: request, ghs: _ghs),
              const SizedBox(height: Space.lg),
              OmniaButton.primary(
                label:
                    'Sign and pay ${Fmt.number(request.omniaAmountPlancks)} OMNIA',
                icon: Iconsax.empty_wallet_copy,
                onPressed: _busy ? null : _pay,
                loading: _busy,
              ),
              const SizedBox(height: Space.sm),
              Text(
                  'Your device signs the transferable OMNIA transfer. The merchant becomes confirmed only after the node observes the transfer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: o.textLow,
                      fontSize: FontSizes.xs,
                      height: LineHeights.relaxed)),
            ] else if (result != null) ...[
              Icon(Iconsax.tick_circle, size: 56, color: o.positive),
              const SizedBox(height: Space.md),
              Text('Payment submitted',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: o.textHigh,
                      fontSize: FontSizes.xxl,
                      fontWeight: Weights.bold)),
              const SizedBox(height: Space.sm),
              Text(
                  'The wallet signed and relayed ${Fmt.number(result.amount)} OMNIA plancks to the merchant.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: o.textMedium, height: LineHeights.relaxed)),
              const SizedBox(height: Space.lg),
              _DetailRow(label: 'Event', value: Fmt.shortId(result.eventId)),
              _DetailRow(
                  label: 'Recipient balance',
                  value: Fmt.number(result.recipientBalance)),
            ],
            if (_error != null) ...[
              const SizedBox(height: Space.md),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: o.negative)),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.ghs});

  final MerchantPaymentRequest request;
  final String Function(int) ghs;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
          color: o.bg50,
          borderRadius: Radii.rLg,
          border: Border.all(color: o.borderLow)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review payment',
              style: TextStyle(
                  color: o.textHigh,
                  fontSize: FontSizes.xl,
                  fontWeight: Weights.bold)),
          const SizedBox(height: Space.md),
          _DetailRow(label: 'Merchant', value: request.merchantId),
          _DetailRow(label: 'Price', value: ghs(request.ghsPricePesewas)),
          _DetailRow(
              label: 'OMNIA amount',
              value: '${Fmt.number(request.omniaAmountPlancks)} plancks'),
          _DetailRow(
              label: 'Protocol fee',
              value: '${Fmt.number(request.protocolFeePlancks)} plancks'),
          _DetailRow(
              label: 'Quote expiry',
              value: DateTime.fromMillisecondsSinceEpoch(request.quoteExpiryMs)
                  .toLocal()
                  .toString()),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: o.textMedium))),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: o.textHigh, fontWeight: Weights.medium))),
        ],
      ),
    );
  }
}
