import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/auth_mode.dart';
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
import '../../data/contact.dart';
import '../../data/payment_request.dart';
import '../../state/contacts.dart';
import '../../state/notices.dart';
import '../../state/providers.dart';
import '../contacts/contacts_screen.dart';

/// Spend UBC.
///
/// Amount-first: the figure you are sending is the largest thing on the page
/// and sits above the fold, with the recipient directly beneath it and the
/// primary action docked above the keyboard. Confirmation is a sheet.
class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final _toDidController = TextEditingController();
  final _amountController = TextEditingController();
  bool _busy = false;
  String? _didError;
  String? _amountError;

  /// Latest known spendable balance, for validation and the remaining hint.
  int? _available;

  @override
  void initState() {
    super.initState();
    _toDidController.addListener(_onChanged);
    _amountController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _toDidController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Clear stale errors as soon as the user starts fixing them — an error that
  /// outlives the mistake reads as the field being permanently broken.
  void _onChanged() {
    if (!mounted) return;
    setState(() {
      _didError = null;
      _amountError = null;
    });
  }

  int get _amount => int.tryParse(_amountController.text.trim()) ?? 0;
  String get _toDid => _toDidController.text.trim();

  bool get _canSubmit =>
      _toDid.startsWith('did:omnia:') &&
      _amount > 0 &&
      (_available == null || _amount <= _available!);

  String? _validateDid() {
    if (_toDid.isEmpty) return 'Enter a recipient DID';
    if (!_toDid.startsWith('did:omnia:')) {
      return 'A DID must start with did:omnia:';
    }
    return null;
  }

  String? _validateAmount() {
    if (_amount <= 0) return 'Enter a positive whole number';
    if (_available != null && _amount > _available!) {
      return 'You only have ${Fmt.ubc(_available!)}';
    }
    return null;
  }

  /// Apply a scanned or pasted payment request: fill the recipient, and
  /// prefill the amount when the request carried one.
  void _applyRequest(PaymentRequest request) {
    Haptics.selection();
    _toDidController.text = request.did;
    if (request.amount != null) {
      _amountController.text = request.amount.toString();
    }
  }

  Future<void> _scan() async {
    Haptics.medium();
    final request = await context.push<PaymentRequest>('/scan');
    if (request != null) _applyRequest(request);
  }

  Future<void> _pickContact() async {
    final did = await showContactPicker(context, ref);
    if (did != null) {
      Haptics.selection();
      _toDidController.text = did;
    }
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData('text/plain'))?.text;
    if (text == null || !mounted) return;
    // A pasted payment request (omnia:did?amount=…) prefills the amount too;
    // anything else drops into the recipient field as-is.
    final request = PaymentRequest.parse(text);
    if (request != null) {
      _applyRequest(request);
    } else {
      Haptics.selection();
      _toDidController.text = text.trim();
    }
  }

  void _setMax() {
    final balance = _available;
    if (balance == null || balance <= 0) return;
    Haptics.selection();
    _amountController.text = balance.toString();
  }

  String _authorizationNote() {
    final mode =
        ref.read(authModeProvider).valueOrNull ?? AuthMode.selfCustody;
    return mode == AuthMode.supabase
        ? 'Authorized through your Omnia account'
        : 'Signed on-device with your private key';
  }

  Future<bool> _confirmWithBiometrics() async {
    final auth = LocalAuthentication();
    try {
      if (!await auth.isDeviceSupported()) return true; // no hardware — allow
      return auth.authenticate(
        localizedReason: 'Confirm to send UBC',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } on PlatformException {
      return true; // biometrics unavailable/misconfigured — don't block
    }
  }

  Future<void> _submit() async {
    final didError = _validateDid();
    final amountError = _validateAmount();
    if (didError != null || amountError != null) {
      Haptics.error();
      setState(() {
        _didError = didError;
        _amountError = amountError;
      });
      return;
    }

    final toDid = _toDid;
    final amount = _amount;

    final proceed = await showOmniaConfirm(
      context,
      icon: Iconsax.arrow_up_3_copy,
      title: 'Send ${Fmt.ubc(amount)}?',
      message: 'This spends the amount from your balance and cannot be undone.',
      confirmLabel: 'Send ${Fmt.ubc(amount)}',
      details: [
        (label: 'To', value: Fmt.shortDid(toDid)),
        (label: 'Amount', value: Fmt.ubc(amount)),
        if (_available != null)
          (label: 'Remaining', value: Fmt.ubc(_available! - amount)),
      ],
    );
    if (!proceed || !mounted) return;

    if (!await _confirmWithBiometrics()) return;
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      final result = await runWithOverlay(
        context,
        () => ref
            .read(walletRepositoryProvider)
            .send(toDid: toDid, amount: amount),
        message: 'Sending…',
      );
      ref.invalidate(balanceProvider);
      ref.invalidate(historyProvider);

      // When the wallet signed the transfer itself (self-custody), say so —
      // the spend was authorized by the on-device key, not just the session.
      final signedNote = result.isWalletSigned ? ' · signed on-device' : '';
      await ref.read(noticesProvider.notifier).add(
            type: NoticeType.sent,
            title: 'Sent ${Fmt.ubc(result.amount)}',
            body: 'To ${Fmt.shortDid(toDid)} · '
                'new balance ${Fmt.ubc(result.newBalance)}$signedNote',
          );
      if (!mounted) return;
      Haptics.success();
      showOmniaToast(
        context,
        message: 'Sent ${Fmt.ubc(result.amount)}',
        icon: Iconsax.tick_circle,
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      Haptics.error();
      showOmniaToast(context, message: friendlyError(e).message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    _available = ref.watch(balanceProvider).valueOrNull?.balance;

    final did = _toDid;
    final contact = did.isEmpty
        ? null
        : ref.watch(contactsProvider).where((c) => c.did == did).firstOrNull;
    final isNewDid = did.startsWith('did:omnia:') && contact == null;

    return Scaffold(
      backgroundColor: o.bg,
      appBar: const OmniaHeader(title: 'Send'),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: Space.xxl),
                children: [
                  _AmountField(
                    controller: _amountController,
                    available: _available,
                    error: _amountError,
                    onMax: _setMax,
                  ),
                  const Hairline(),
                  _RecipientField(
                    controller: _toDidController,
                    contact: contact,
                    error: _didError,
                    onScan: _scan,
                    onContacts: _pickContact,
                    onPaste: _paste,
                  ),
                  if (isNewDid)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.lg,
                        0,
                        Space.lg,
                        Space.md,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OmniaButton(
                          label: 'Save to contacts',
                          icon: Iconsax.user_add_copy,
                          size: ButtonSize.tiny,
                          color: ButtonColor.secondary,
                          onPressed: () =>
                              editContact(context, ref, presetDid: did),
                        ),
                      ),
                    ),
                  const Hairline(),
                  const _SoulboundNotice(),
                ],
              ),
            ),
            // The primary action is docked above the keyboard rather than
            // buried at the end of a scroll — the thing you came here to do
            // should never require scrolling to reach.
            _SubmitBar(
              enabled: _canSubmit,
              busy: _busy,
              note: _authorizationNote(),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Amount
// ---------------------------------------------------------------------------

/// The amount, typed directly at display size.
///
/// A wallet's amount field should never look like a form input, so this is a
/// borderless, centred, display-scale field with a "Max" pill beside it.
class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.available,
    required this.error,
    required this.onMax,
  });

  final TextEditingController controller;
  final int? available;
  final String? error;
  final VoidCallback onMax;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Space.lg, Space.xl, Space.lg, Space.xl),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // IntrinsicWidth keeps the field exactly as wide as the digits,
              // so the number + unit pair stays optically centred as it grows.
              IntrinsicWidth(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    // Past nine digits the figure stops fitting at display
                    // size, and no reachable balance needs more.
                    LengthLimitingTextInputFormatter(9),
                  ],
                  style: theme.textTheme.displayMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: '0',
                    hintStyle: theme.textTheme.displayMedium
                        ?.copyWith(color: o.borderHigh),
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              Text(
                'UBC',
                style:
                    theme.textTheme.headlineMedium?.copyWith(color: o.textLow),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          if (error != null)
            Text(
              error!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: FontSizes.sm,
                fontWeight: Weights.medium,
                color: o.negative,
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Flexible so a long formatted balance yields to the Max
                // button rather than pushing it off the edge.
                Flexible(
                  child: Text(
                    available == null
                        ? 'Checking balance…'
                        : 'Available ${Fmt.ubc(available!)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: FontSizes.sm,
                      color: o.textLow,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ),
                if (available != null && available! > 0) ...[
                  const SizedBox(width: Space.sm),
                  OmniaButton(
                    label: 'Max',
                    size: ButtonSize.tiny,
                    color: ButtonColor.secondary,
                    onPressed: onMax,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recipient
// ---------------------------------------------------------------------------

class _RecipientField extends StatelessWidget {
  const _RecipientField({
    required this.controller,
    required this.contact,
    required this.error,
    required this.onScan,
    required this.onContacts,
    required this.onPaste,
  });

  final TextEditingController controller;
  final Contact? contact;
  final String? error;
  final VoidCallback onScan;
  final VoidCallback onContacts;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final did = controller.text.trim();
    final resolved = did.startsWith('did:omnia:');
    final label = contact?.label ?? '';

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TO',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: FontSizes.xs,
              fontWeight: Weights.bold,
              letterSpacing: 0.6,
              color: o.textLow,
            ),
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              // Resolving a DID to a face is the difference between hoping you
              // pasted the right thing and knowing you did.
              if (resolved)
                Padding(
                  padding: const EdgeInsets.only(right: Space.md),
                  child: DidAvatar(did: did, size: 36),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: FontSizes.md,
                    fontWeight: Weights.medium,
                    color: o.text,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: Space.sm),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText: 'did:omnia:…',
                    errorText: error,
                  ),
                ),
              ),
            ],
          ),
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: OmniaPill(
                label: label,
                icon: Iconsax.user_tick_copy,
                color: o.accent,
              ),
            ),
          const SizedBox(height: Space.md),
          // Three labelled pills do not fit on one line on a narrow screen at
          // large text sizes; Wrap lets the third drop rather than clip.
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              _RecipientAction(
                icon: Iconsax.scan_barcode_copy,
                label: 'Scan',
                onTap: onScan,
              ),
              _RecipientAction(
                icon: Iconsax.profile_2user_copy,
                label: 'Contacts',
                onTap: onContacts,
              ),
              _RecipientAction(
                icon: Iconsax.copy_copy,
                label: 'Paste',
                onTap: onPaste,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecipientAction extends StatelessWidget {
  const _RecipientAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        decoration: BoxDecoration(color: o.bg50, borderRadius: Radii.rFull),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: o.textMedium),
            const SizedBox(width: Space.xs + 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: FontSizes.sm,
                fontWeight: Weights.medium,
                color: o.textHigh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------

class _SoulboundNotice extends StatelessWidget {
  const _SoulboundNotice();

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.info_circle_copy, size: 16, color: o.textLow),
          const SizedBox(width: Space.md - 2),
          Expanded(
            child: Text(
              'UBC is soulbound. Sending spends (burns) tokens from your '
              'balance — the recipient DID is recorded for provenance but is '
              'not credited the amount.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: FontSizes.sm,
                height: LineHeights.relaxed,
                color: o.textLow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.enabled,
    required this.busy,
    required this.note,
    required this.onSubmit,
  });

  final bool enabled;
  final bool busy;
  final String note;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Container(
      decoration: BoxDecoration(
        color: o.bg,
        border: Border(top: BorderSide(color: o.borderLow)),
      ),
      padding: EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.lg,
        Space.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OmniaButton(
            label: 'Review & send',
            expand: true,
            loading: busy,
            onPressed: enabled ? onSubmit : null,
          ),
          const SizedBox(height: Space.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.shield_tick_copy, size: 13, color: o.textLow),
              const SizedBox(width: Space.xs + 1),
              Flexible(
                child: Text(
                  note,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: FontSizes.xs,
                    height: LineHeights.snug,
                    color: o.textLow,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
