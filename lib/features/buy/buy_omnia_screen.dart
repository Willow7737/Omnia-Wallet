import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/design/tokens.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/button.dart';
import '../../core/ui/header.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Ghana-first OMNIA acquisition flow.
///
/// The wallet can request and display a quote, but it cannot set rate, fees,
/// quantity, expiry, or payment success. Those values come from the node.
class BuyOmniaScreen extends ConsumerStatefulWidget {
  const BuyOmniaScreen({super.key});

  @override
  ConsumerState<BuyOmniaScreen> createState() => _BuyOmniaScreenState();
}

class _BuyOmniaScreenState extends ConsumerState<BuyOmniaScreen> {
  final _amountController = TextEditingController(text: '10.00');
  final _phoneController = TextEditingController();

  String _provider = 'Mtn';
  OmniaQuote? _quote;
  PaymentOrderStatus? _order;
  Timer? _poller;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _poller?.cancel();
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  int get _ghsPesewas {
    final normalized = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(normalized) ?? 0;
    return (amount * 100).round();
  }

  String _ghs(int pesewas) => 'GHS ${(pesewas / 100).toStringAsFixed(2)}';

  Future<void> _requestQuote() async {
    final amount = _ghsPesewas;
    final phone = _phoneController.text.trim();
    if (amount < 100) {
      setState(() => _error = 'Enter at least GHS 1.00.');
      return;
    }
    if (!RegExp(r'^\+233\d{9}$').hasMatch(phone)) {
      setState(() => _error = 'Use a Ghana number in +233XXXXXXXXX format.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _order = null;
    });
    try {
      final quote = await ref.read(walletRepositoryProvider).requestOmniaQuote(
            ghsAmountPesewas: amount,
            provider: _provider,
            customerNumber: phone,
          );
      if (!mounted) return;
      setState(() => _quote = quote);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startPayment() async {
    final quote = _quote;
    if (quote == null || quote.isExpired()) {
      setState(() => _error = 'This quote has expired. Request a new quote.');
      return;
    }
    final phone = _phoneController.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(walletRepositoryProvider).buyOmnia(
            quoteId: quote.quoteId,
            customerNumber: phone,
          );
      if (!mounted) return;
      setState(() {
        _order = result.order;
        _busy = false;
      });
      _beginPolling(result.order.orderId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(error).message;
      });
    }
  }

  void _beginPolling(String orderId) {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 5), (_) => _poll(orderId));
  }

  Future<void> _poll(String orderId) async {
    if (!mounted) return;
    try {
      final status = await ref
          .read(walletRepositoryProvider)
          .getPaymentOrderStatus(orderId: orderId);
      if (!mounted) return;
      setState(() => _order = status);
      if (status.isTerminal) {
        _poller?.cancel();
        if (status.isSuccessful) ref.invalidate(financialBalanceProvider);
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error).message);
    }
  }

  String _stateDescription(String state) => switch (state) {
        'CREATED' => 'Preparing your quote-backed order.',
        'QUOTED' => 'Quote accepted by the payment service.',
        'PAYMENT_PENDING' => 'Complete the mobile-money authorization on your phone.',
        'PAYMENT_VERIFIED' => 'Mobile-money payment verified.',
        'RISK_REVIEW' || 'RISK_APPROVED' => 'Risk checks are being completed.',
        'INVENTORY_RESERVED' => 'Treasury pilot inventory reserved for delivery.',
        'DELIVERED' => 'OMNIA delivered to your wallet.',
        'PAYMENT_FAILED' || 'PAYMENT_TIMEOUT' => 'The mobile-money payment did not complete.',
        'INVENTORY_UNAVAILABLE' => 'Pilot inventory is temporarily unavailable; follow the refund path.',
        'REFUNDED' => 'The order was refunded.',
        _ => 'The node is processing this order.',
      };

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final quote = _quote;
    final order = _order;
    return Scaffold(
      backgroundColor: o.bg,
      appBar: const OmniaHeader(title: 'Buy OMNIA'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.x5l),
          children: [
            Text(
              'Buy with Ghana mobile money',
              style: TextStyle(
                color: o.textHigh,
                fontSize: FontSizes.xxl,
                fontWeight: Weights.bold,
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(
              'OMNIA is a floating transferable asset. Your quote is time-limited and uses treasury-funded pilot inventory; it is not a fixed GHS redemption promise.',
              style: TextStyle(color: o.textMedium, height: LineHeights.relaxed),
            ),
            const SizedBox(height: Space.xl),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount to spend (GHS)',
                prefixText: 'GHS ',
              ),
              onChanged: (_) => setState(() {
                _quote = null;
                _error = null;
              }),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile-money number',
                hintText: '+233XXXXXXXXX',
              ),
              onChanged: (_) => setState(() {
                _quote = null;
                _error = null;
              }),
            ),
            const SizedBox(height: Space.md),
            DropdownButtonFormField<String>(
              value: _provider,
              decoration: const InputDecoration(labelText: 'Provider'),
              items: const [
                DropdownMenuItem(value: 'Mtn', child: Text('MTN Mobile Money')),
                DropdownMenuItem(value: 'Telecel', child: Text('Telecel Cash')),
                DropdownMenuItem(value: 'At', child: Text('AT Money')),
              ],
              onChanged: _busy ? null : (value) => setState(() {
                _provider = value ?? 'Mtn';
                _quote = null;
              }),
            ),
            const SizedBox(height: Space.lg),
            OmniaButton.primary(
              label: quote == null ? 'Get a quote' : 'Refresh quote',
              icon: Iconsax.receipt_2,
              onPressed: _busy ? null : _requestQuote,
              loading: _busy && quote == null,
            ),
            if (quote != null) ...[
              const SizedBox(height: Space.xl),
              _QuoteCard(quote: quote, ghs: _ghs),
              const SizedBox(height: Space.lg),
              OmniaButton.primary(
                label: 'Authorize mobile-money payment',
                icon: Iconsax.mobile,
                onPressed: _busy || quote.isExpired() ? null : _startPayment,
                loading: _busy && _order == null,
              ),
            ],
            if (order != null) ...[
              const SizedBox(height: Space.xl),
              _OrderCard(order: order, description: _stateDescription(order.state)),
            ],
            if (_error != null) ...[
              const SizedBox(height: Space.md),
              Text(_error!, style: TextStyle(color: o.negative)),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote, required this.ghs});

  final OmniaQuote quote;
  final String Function(int) ghs;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: o.bg50,
        borderRadius: Radii.rLg,
        border: Border.all(color: o.borderLow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quote disclosure', style: TextStyle(color: o.textHigh, fontWeight: Weights.bold)),
          const SizedBox(height: Space.sm),
          Text(
            '${ghs(quote.totalGhsCostPesewas)} → ${Fmt.number(quote.netOmniaPlancks)} OMNIA net',
            style: TextStyle(color: o.accent, fontSize: FontSizes.xxl, fontWeight: Weights.bold),
          ),
          const SizedBox(height: Space.md),
          ...quote.disclosureFields.map((field) => Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                child: Row(
                  children: [
                    Expanded(child: Text(field.label, style: TextStyle(color: o.textMedium))),
                    Flexible(child: Text(field.value, textAlign: TextAlign.right, style: TextStyle(color: o.textHigh, fontWeight: Weights.medium))),
                  ],
                ),
              )),
          const SizedBox(height: Space.sm),
          Text('Quote ID: ${quote.quoteId}', style: TextStyle(color: o.textLow, fontSize: FontSizes.xs)),
          Text('Provider: ${quote.provider}', style: TextStyle(color: o.textLow, fontSize: FontSizes.xs)),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.description});

  final PaymentOrderStatus order;
  final String description;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final positive = order.isSuccessful;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: positive ? o.positive.withValues(alpha: 0.12) : o.bg50,
        borderRadius: Radii.rLg,
        border: Border.all(color: positive ? o.positive.withValues(alpha: 0.35) : o.borderLow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(positive ? Iconsax.tick_circle : Iconsax.refresh, color: positive ? o.positive : o.accent),
              const SizedBox(width: Space.sm),
              Text(order.state, style: TextStyle(color: o.textHigh, fontWeight: Weights.bold)),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(description, style: TextStyle(color: o.textMedium, height: LineHeights.relaxed)),
          const SizedBox(height: Space.md),
          Text('Order ${order.orderId}', style: TextStyle(color: o.textLow, fontSize: FontSizes.xs)),
          if (order.isSuccessful) ...[
            const SizedBox(height: Space.sm),
            Text('Receipt: ${Fmt.number(order.omniaQuantityPlancks)} OMNIA plancks allocated', style: TextStyle(color: o.positive, fontWeight: Weights.medium)),
          ],
        ],
      ),
    );
  }
}
