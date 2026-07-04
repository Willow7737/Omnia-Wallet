import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/fade_slide_in.dart';
import '../../state/providers.dart';
import '../home/home_screen.dart' show TransferTile;

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: RefreshIndicator(
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
                child: Center(child: Text('Could not load history:\n$e')),
              ),
            ],
          ),
          data: (records) {
            if (records.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: Text('No transactions yet')),
                  ),
                ],
              );
            }
            final ordered = records.reversed.toList();
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
    );
  }
}
