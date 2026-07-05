import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../data/governance.dart';
import '../../state/governance.dart';
import '../../state/providers.dart';

class GovernanceScreen extends ConsumerWidget {
  const GovernanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposalsAsync = ref.watch(proposalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Governance')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createProposal(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New proposal'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          Haptics.light();
          ref.invalidate(proposalsProvider);
          await ref.read(proposalsProvider.future);
        },
        child: proposalsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(friendlyError(e).message)),
              ),
            ],
          ),
          data: (proposals) {
            if (proposals.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: Text('No proposals yet')),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: proposals.length,
              itemBuilder: (_, i) => FadeSlideIn(
                delay: Duration(milliseconds: 30 * (i.clamp(0, 8))),
                child: _ProposalCard(proposal: proposals[i]),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _createProposal(BuildContext context, WidgetRef ref) async {
    Haptics.light();
    // We need the current epoch to compute an absolute expiry.
    var epoch = ref.read(balanceProvider).valueOrNull?.currentEpoch;
    epoch ??= (await ref.read(balanceProvider.future)).currentEpoch;
    if (!context.mounted) return;

    final descCtrl = TextEditingController();
    var epochs = 3;
    final formKey = GlobalKey<FormState>();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('New proposal'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: descCtrl,
                  maxLines: 3,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What are you proposing?',
                  ),
                  validator: (v) => (v ?? '').trim().length < 8
                      ? 'Describe the proposal (min 8 chars)'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Voting window'),
                    const Spacer(),
                    IconButton(
                      onPressed:
                          epochs > 1 ? () => setLocal(() => epochs--) : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$epochs epoch${epochs == 1 ? '' : 's'}'),
                    IconButton(
                      onPressed: () => setLocal(() => epochs++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
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
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || !context.mounted) return;

    final id =
        'prop-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    try {
      await ref.read(governanceRepositoryProvider).create(
            id: id,
            description: descCtrl.text.trim(),
            expiresAtEpoch: epoch + epochs,
          );
      ref.invalidate(proposalsProvider);
      if (!context.mounted) return;
      Haptics.success();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proposal created')),
      );
    } catch (e) {
      if (!context.mounted) return;
      Haptics.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e).message)),
      );
    }
  }
}

class _ProposalCard extends ConsumerStatefulWidget {
  const _ProposalCard({required this.proposal});
  final Proposal proposal;

  @override
  ConsumerState<_ProposalCard> createState() => _ProposalCardState();
}

class _ProposalCardState extends ConsumerState<_ProposalCard> {
  bool _voting = false;

  Future<void> _vote(VoteChoice choice) async {
    setState(() => _voting = true);
    Haptics.medium();
    try {
      final result = await ref
          .read(governanceRepositoryProvider)
          .vote(widget.proposal.id, choice);
      ref.invalidate(proposalsProvider);
      if (!mounted) return;
      Haptics.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vote recorded: ${result.choice} (weight ${result.effectiveWeight})',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Haptics.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e).message)),
      );
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.proposal;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child:
                      Text(p.description, style: theme.textTheme.titleMedium),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: p.status),
              ],
            ),
            const SizedBox(height: 12),
            _TallyBar(proposal: p),
            const SizedBox(height: 8),
            Row(
              children: [
                _tally('For', p.votesFor, context.omnia.positive),
                _tally('Against', p.votesAgainst, theme.colorScheme.error),
                _tally('Abstain', p.votesAbstain,
                    theme.colorScheme.onSurfaceVariant),
                const Spacer(),
                Text(
                  'Epoch ${p.expiresAtEpoch}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            if (p.isVoting) ...[
              const SizedBox(height: 12),
              if (_voting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _vote(VoteChoice.forProposal),
                        child: const Text('For'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _vote(VoteChoice.against),
                        child: const Text('Against'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _vote(VoteChoice.abstain),
                        child: const Text('Abstain'),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tally(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('$label $value', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _TallyBar extends StatelessWidget {
  const _TallyBar({required this.proposal});
  final Proposal proposal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = proposal.totalVotes;
    final scheme = theme.colorScheme;
    if (total == 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: [
          Expanded(
            flex: proposal.votesFor,
            child: Container(height: 8, color: context.omnia.positive),
          ),
          Expanded(
            flex: proposal.votesAgainst,
            child: Container(height: 8, color: scheme.error),
          ),
          Expanded(
            flex: proposal.votesAbstain,
            child: Container(height: 8, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = status.toLowerCase();
    Color bg;
    Color fg;
    if (s == 'passed') {
      bg = context.omnia.successContainer;
      fg = context.omnia.success;
    } else if (s == 'voting') {
      bg = theme.colorScheme.primaryContainer;
      fg = theme.colorScheme.onPrimaryContainer;
    } else {
      bg = theme.colorScheme.surfaceContainerHighest;
      fg = theme.colorScheme.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
