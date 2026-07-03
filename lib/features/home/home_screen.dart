import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(balanceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('omnia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(balanceProvider);
          ref.invalidate(historyProvider);
          await ref.read(balanceProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _BalanceCard(balanceAsync: balanceAsync),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.arrow_upward,
                    label: 'Send',
                    onTap: () => context.push('/send'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.qr_code,
                    label: 'Receive',
                    onTap: () => context.push('/receive'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent activity', style: theme.textTheme.titleMedium),
                TextButton(
                  onPressed: () => context.push('/history'),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _RecentActivity(),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balanceAsync});
  final AsyncValue<Balance> balanceAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: balanceAsync.when(
          loading: () => const SizedBox(
            height: 96,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SizedBox(
            height: 96,
            child: Center(
              child: Text('Could not load balance:\n$e',
                  textAlign: TextAlign.center),
            ),
          ),
          data: (b) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Balance',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Text(Fmt.ubc(b.balance),
                  style: theme.textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                children: [
                  _Meta(
                      label: 'Monthly quota',
                      value: Fmt.number(b.monthlyQuota)),
                  _Meta(label: 'Epoch', value: '#${b.currentEpoch}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);
    return historyAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Could not load activity: $e'),
      ),
      data: (records) {
        if (records.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No transactions yet')),
          );
        }
        final recent = records.reversed.take(5).toList();
        return Column(
          children: [for (final r in recent) TransferTile(record: r)],
        );
      },
    );
  }
}

class TransferTile extends StatelessWidget {
  const TransferTile({super.key, required this.record});
  final TransferRecord record;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.arrow_upward)),
      title: Text('Sent ${Fmt.ubc(record.amount)}'),
      subtitle: Text(
          'To ${Fmt.shortDid(record.toDid)}\n${Fmt.dateTime(record.dateTime)}'),
      isThreeLine: true,
      trailing: Text('−${record.amount}',
          style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
