import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Read-only network status for power users — reachability, version, peers.
/// Uses the node's public `node/info` endpoint (no auth).
class NetworkScreen extends ConsumerWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(nodeInfoProvider);
    final nodeUrl = ref.watch(nodeUrlProvider);
    final epoch = ref.watch(balanceProvider).valueOrNull?.currentEpoch;

    return Scaffold(
      appBar: AppBar(title: const Text('Network')),
      body: RefreshIndicator(
        onRefresh: () async {
          Haptics.light();
          ref.invalidate(nodeInfoProvider);
          await ref.read(nodeInfoProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _StatusHeader(infoAsync: infoAsync, nodeUrl: nodeUrl),
            const SizedBox(height: 20),
            infoAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text(friendlyError(e).message),
              ),
              data: (info) => Card(
                child: Column(
                  children: [
                    _row('Node version', info.version),
                    _row('Protocol', info.protocolVersion),
                    _row('Peers', Fmt.number(info.peers)),
                    _row('Finalized height', Fmt.number(info.finalizedHeight)),
                    _row('Shards', Fmt.number(info.shardCount)),
                    _row('Uptime', _uptime(info.uptimeSeconds)),
                    if (epoch != null) _row('Current epoch', '#$epoch'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => _Kv(label: label, value: value);

  static String _uptime(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.infoAsync, required this.nodeUrl});
  final AsyncValue<NodeInfo> infoAsync;
  final String nodeUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reachable = infoAsync.hasValue;
    final loading = infoAsync.isLoading;
    final color = loading
        ? theme.colorScheme.onSurfaceVariant
        : reachable
            ? context.omnia.success
            : theme.colorScheme.error;
    final label = loading
        ? 'Checking…'
        : reachable
            ? 'Reachable'
            : 'Unreachable';
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(label, style: theme.textTheme.titleMedium),
        const Spacer(),
        Flexible(
          child: Text(
            nodeUrl,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const Spacer(),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
