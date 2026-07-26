import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/header.dart';
import '../../core/ui/list_row.dart';
import '../../core/ui/states.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Read-only network status for power users — reachability, version, peers.
/// Uses the node's public `node/info` endpoint (no auth).
class NetworkScreen extends ConsumerWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final infoAsync = ref.watch(nodeInfoProvider);
    final nodeUrl = ref.watch(nodeUrlProvider);
    final epoch = ref.watch(balanceProvider).valueOrNull?.currentEpoch;

    return Scaffold(
      backgroundColor: o.bg,
      appBar: const OmniaHeader(title: 'Network'),
      body: OmniaRefresh(
        onRefresh: () async {
          ref.invalidate(nodeInfoProvider);
          await ref.read(nodeInfoProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.x4l),
          children: [
            _StatusHeader(infoAsync: infoAsync, nodeUrl: nodeUrl),
            const Hairline(),
            infoAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(Space.x4l),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => OmniaErrorState(
                message: friendlyError(e).message,
                onRetry: () => ref.invalidate(nodeInfoProvider),
              ),
              data: (info) => Column(
                children: [
                  const OmniaSectionLabel('Node'),
                  _Kv(label: 'Version', value: info.version),
                  const Hairline(indent: Space.lg),
                  _Kv(label: 'Protocol', value: info.protocolVersion),
                  const Hairline(indent: Space.lg),
                  _Kv(label: 'Uptime', value: _uptime(info.uptimeSeconds)),
                  const Hairline(),
                  const OmniaSectionLabel('Chain'),
                  _Kv(label: 'Peers', value: Fmt.number(info.peers)),
                  const Hairline(indent: Space.lg),
                  _Kv(
                    label: 'Finalized height',
                    value: Fmt.number(info.finalizedHeight),
                  ),
                  const Hairline(indent: Space.lg),
                  _Kv(label: 'Shards', value: Fmt.number(info.shardCount)),
                  if (epoch != null) ...[
                    const Hairline(indent: Space.lg),
                    _Kv(label: 'Current epoch', value: '#$epoch'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _uptime(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}

/// Reachability at a glance: a status dot, a word, and the endpoint it refers
/// to. This is the first thing anyone opening this screen wants to know.
class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.infoAsync, required this.nodeUrl});

  final AsyncValue<NodeInfo> infoAsync;
  final String nodeUrl;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);

    final loading = infoAsync.isLoading;
    final reachable = infoAsync.hasValue;
    final color =
        loading ? o.textLow : (reachable ? o.positive : o.negative);
    final label =
        loading ? 'Checking…' : (reachable ? 'Reachable' : 'Unreachable');

    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleMedium),
                const SizedBox(height: 1),
                Text(
                  nodeUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: monoStyle(fontSize: FontSizes.xs, color: o.textLow),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md + 2,
      ),
      // Both sides flex: "Finalized height" and a six-digit value together
      // exceed a narrow screen at large text sizes. The label gives way first,
      // since the value is the information.
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: o.textMedium),
            ),
          ),
          const SizedBox(width: Space.lg),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: FontSizes.md,
                fontWeight: Weights.semiBold,
                color: o.text,
                fontFeatures: kTabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
