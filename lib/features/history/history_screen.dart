import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/haptics.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../state/providers.dart';
import '../home/home_screen.dart' show TransferTile;

enum _Scope { all, mine }

/// The transfer log. "All" shows network activity; "Mine" narrows to
/// transfers this wallet sent — visually distinct in the tiles as well.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _Scope _scope = _Scope.all;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyProvider);
    final myDid = ref.watch(identityProvider).valueOrNull?.did;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: SegmentedButton<_Scope>(
              segments: const [
                ButtonSegment(value: _Scope.all, label: Text('All activity')),
                ButtonSegment(value: _Scope.mine, label: Text('Mine')),
              ],
              selected: {_scope},
              showSelectedIcon: false,
              onSelectionChanged: (s) {
                Haptics.selection();
                setState(() => _scope = s.first);
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(historyProvider);
                await ref.read(historyProvider.future);
              },
              child: historyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(friendlyError(e).message)),
                    ),
                  ],
                ),
                data: (records) {
                  var visible = records;
                  if (_scope == _Scope.mine) {
                    visible = [
                      for (final r in records)
                        if (myDid != null && r.fromDid == myDid) r,
                    ];
                  }
                  if (visible.isEmpty) {
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(48),
                          child: Center(
                            child: Text(
                              _scope == _Scope.mine
                                  ? "You haven't sent anything yet"
                                  : 'No transactions yet',
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  final ordered = visible.reversed.toList();
                  return ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: ordered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => FadeSlideIn(
                      delay: Duration(milliseconds: 30 * (i.clamp(0, 8))),
                      child: TransferTile(record: ordered[i]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
