import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/errors.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../core/ui/button.dart';
import '../../core/ui/header.dart';
import '../../core/ui/list_row.dart';
import '../../core/ui/sheet.dart';
import '../../core/ui/states.dart';
import '../../data/governance.dart';
import '../../state/governance.dart';
import '../../state/notices.dart';
import '../../state/providers.dart';

/// Governance: open proposals, their running tallies, and voting.
class GovernanceScreen extends ConsumerWidget {
  const GovernanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final proposalsAsync = ref.watch(proposalsProvider);

    return Scaffold(
      backgroundColor: o.bg,
      appBar: OmniaHeader(
        title: 'Governance',
        actions: [
          OmniaIconButton(
            icon: Iconsax.add_copy,
            size: 24,
            tooltip: 'New proposal',
            onTap: () => _createProposal(context, ref),
          ),
        ],
      ),
      body: OmniaRefresh(
        onRefresh: () async {
          ref.invalidate(proposalsProvider);
          await ref.read(proposalsProvider.future);
        },
        child: proposalsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              OmniaErrorState(
                message: friendlyError(e).message,
                onRetry: () => ref.invalidate(proposalsProvider),
              ),
            ],
          ),
          data: (proposals) {
            if (proposals.isEmpty) {
              return ListView(
                children: [
                  OmniaEmptyState(
                    icon: Iconsax.chart_2_copy,
                    title: 'No proposals yet',
                    message: 'Anyone can propose a change to the protocol.',
                    actionLabel: 'Create a proposal',
                    onAction: () => _createProposal(context, ref),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: Space.x4l),
              itemCount: proposals.length,
              separatorBuilder: (_, __) => const Hairline(),
              itemBuilder: (_, i) => FadeIn(
                delay: FadeIn.stagger(i),
                child: _Proposal(proposal: proposals[i]),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _createProposal(BuildContext context, WidgetRef ref) async {
    // The voting window is expressed in epochs from now, so we need the
    // current one to compute an absolute expiry.
    var epoch = ref.read(balanceProvider).valueOrNull?.currentEpoch;
    epoch ??= (await ref.read(balanceProvider.future)).currentEpoch;
    if (!context.mounted) return;

    final result = await showOmniaSheet<({String description, int epochs})>(
      context,
      title: 'New proposal',
      subtitle: 'Describe the change and how long voting stays open.',
      builder: (_) => const _NewProposalBody(),
    );
    if (result == null || !context.mounted) return;

    final id =
        'prop-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    try {
      await ref.read(governanceRepositoryProvider).create(
            id: id,
            description: result.description,
            expiresAtEpoch: epoch + result.epochs,
          );
      ref.invalidate(proposalsProvider);
      if (!context.mounted) return;
      Haptics.success();
      showOmniaToast(context, message: 'Proposal created');
    } catch (e) {
      if (!context.mounted) return;
      Haptics.error();
      showOmniaToast(context, message: friendlyError(e).message, error: true);
    }
  }
}

// ---------------------------------------------------------------------------
// Proposal
// ---------------------------------------------------------------------------

class _Proposal extends ConsumerStatefulWidget {
  const _Proposal({required this.proposal});

  final Proposal proposal;

  @override
  ConsumerState<_Proposal> createState() => _ProposalState();
}

class _ProposalState extends ConsumerState<_Proposal> {
  bool _voting = false;

  Future<void> _vote(VoteChoice choice) async {
    setState(() => _voting = true);
    Haptics.medium();
    try {
      final result = await ref
          .read(governanceRepositoryProvider)
          .vote(widget.proposal.id, choice);
      ref.invalidate(proposalsProvider);
      await ref.read(noticesProvider.notifier).add(
            type: NoticeType.vote,
            title: 'Vote recorded: ${result.choice}',
            body: 'On "${widget.proposal.id}" · weight '
                '${result.effectiveWeight}',
          );
      if (!mounted) return;
      Haptics.success();
      showOmniaToast(
        context,
        message: 'Voted ${result.choice} · weight ${result.effectiveWeight}',
      );
    } catch (e) {
      if (!mounted) return;
      Haptics.error();
      showOmniaToast(context, message: friendlyError(e).message, error: true);
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final p = widget.proposal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.lg,
        Space.lg,
        Space.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  p.description,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: FontSizes.md,
                    fontWeight: Weights.medium,
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
              _StatusPill(status: p.status),
            ],
          ),
          const SizedBox(height: Space.md),
          _TallyBar(proposal: p),
          const SizedBox(height: Space.md),
          // Four independent labels never fit on one line at large text
          // sizes; Wrap reflows them instead of clipping the epoch.
          Wrap(
            spacing: Space.lg,
            runSpacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Tally(label: 'For', value: p.votesFor, color: o.positive),
              _Tally(
                  label: 'Against', value: p.votesAgainst, color: o.negative),
              _Tally(
                label: 'Abstain',
                value: p.votesAbstain,
                color: o.textLow,
              ),
              Text(
                'Ends epoch ${p.expiresAtEpoch}',
                style: theme.textTheme.labelSmall?.copyWith(color: o.textLow),
              ),
            ],
          ),
          if (p.isVoting) ...[
            const SizedBox(height: Space.lg),
            if (_voting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(Space.sm),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OmniaButton(
                      label: 'For',
                      expand: true,
                      size: ButtonSize.small,
                      color: ButtonColor.positiveTonal,
                      onPressed: () => _vote(VoteChoice.forProposal),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: OmniaButton(
                      label: 'Against',
                      expand: true,
                      size: ButtonSize.small,
                      color: ButtonColor.negativeTonal,
                      onPressed: () => _vote(VoteChoice.against),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: OmniaButton(
                      label: 'Abstain',
                      expand: true,
                      size: ButtonSize.small,
                      color: ButtonColor.secondary,
                      onPressed: () => _vote(VoteChoice.abstain),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/// A single stacked bar, proportioned by the running tally.
class _TallyBar extends StatelessWidget {
  const _TallyBar({required this.proposal});

  final Proposal proposal;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final total = proposal.totalVotes;

    if (total == 0) {
      return Container(
        height: 6,
        decoration: BoxDecoration(color: o.bg50, borderRadius: Radii.rFull),
      );
    }

    return ClipRRect(
      borderRadius: Radii.rFull,
      child: SizedBox(
        height: 6,
        child: Row(
          // Stretch, not the default centre alignment. A childless ColoredBox
          // takes `constraints.smallest`, and a centred Row hands its children
          // a *loose* height — so every segment collapsed to zero and the bar
          // rendered as empty space.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A zero-vote segment must contribute no flex at all, or Flutter
            // hands it a 1px sliver and the bar shows a colour nobody voted.
            if (proposal.votesFor > 0)
              Expanded(
                flex: proposal.votesFor,
                child: ColoredBox(color: o.positive),
              ),
            if (proposal.votesAgainst > 0)
              Expanded(
                flex: proposal.votesAgainst,
                child: ColoredBox(color: o.negative),
              ),
            if (proposal.votesAbstain > 0)
              Expanded(
                flex: proposal.votesAbstain,
                child: ColoredBox(color: o.borderHigh),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Space.xs + 1),
        Text(
          '$label $value',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: FontSizes.xs,
            fontWeight: Weights.medium,
            color: o.textMedium,
            fontFeatures: kTabularFigures,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final color = switch (status.toLowerCase()) {
      'passed' => o.positive,
      'voting' => o.accent,
      'rejected' => o.negative,
      _ => o.textLow,
    };
    return OmniaPill(label: status, color: color);
  }
}

// ---------------------------------------------------------------------------
// New proposal
// ---------------------------------------------------------------------------

class _NewProposalBody extends StatefulWidget {
  const _NewProposalBody();

  @override
  State<_NewProposalBody> createState() => _NewProposalBodyState();
}

class _NewProposalBodyState extends State<_NewProposalBody> {
  final _controller = TextEditingController();
  int _epochs = 3;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final description = _controller.text.trim();
    if (description.length < 8) {
      Haptics.error();
      setState(() => _error = 'Describe the proposal (at least 8 characters)');
      return;
    }
    Haptics.medium();
    Navigator.of(context).pop((description: description, epochs: _epochs));
  }

  void _adjust(int delta) {
    final next = (_epochs + delta).clamp(1, 24);
    if (next == _epochs) return;
    Haptics.tick();
    setState(() => _epochs = next);
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;

    return Padding(
      padding: EdgeInsets.only(
        left: Space.xl,
        right: Space.xl,
        top: Space.xl,
        bottom: Space.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            style: TextStyle(fontSize: FontSizes.md, color: o.text),
            decoration: InputDecoration(
              hintText: 'What are you proposing?',
              errorText: _error,
            ),
          ),
          const SizedBox(height: Space.xl),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voting window',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: FontSizes.md,
                        fontWeight: Weights.medium,
                        color: o.text,
                      ),
                    ),
                    Text(
                      'How long the proposal stays open',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: FontSizes.sm,
                        color: o.textLow,
                      ),
                    ),
                  ],
                ),
              ),
              OmniaIconButton(
                icon: Iconsax.minus_cirlce_copy,
                size: 22,
                color: _epochs > 1 ? o.text : o.borderHigh,
                tooltip: 'Fewer epochs',
                onTap: _epochs > 1 ? () => _adjust(-1) : null,
              ),
              SizedBox(
                width: 76,
                child: Text(
                  '$_epochs epoch${_epochs == 1 ? '' : 's'}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: FontSizes.sm,
                    fontWeight: Weights.semiBold,
                    color: o.text,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ),
              OmniaIconButton(
                icon: Iconsax.add_circle_copy,
                size: 22,
                color: _epochs < 24 ? o.text : o.borderHigh,
                tooltip: 'More epochs',
                onTap: _epochs < 24 ? () => _adjust(1) : null,
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          OmniaButton(
            label: 'Create proposal',
            expand: true,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
