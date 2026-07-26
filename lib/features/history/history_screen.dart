import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/ui/header.dart';
import '../../core/ui/press.dart';
import '../../core/ui/states.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../home/home_screen.dart' show TransferTile, TransferSkeleton;
import '../shell/app_shell.dart';

enum _Scope { all, mine }

/// The Activity tab — the transfer log.
///
/// "All" shows network activity; "Mine" narrows to transfers this wallet sent.
/// Rows are grouped under sticky day headers, which is what turns a flat log
/// into something you can actually navigate.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _Scope _scope = _Scope.all;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final historyAsync = ref.watch(historyProvider);
    final myDid = ref.watch(identityProvider).valueOrNull?.did;

    return Scaffold(
      backgroundColor: o.bg,
      appBar: OmniaHeader(
        title: 'Activity',
        showBack: false,
        bottom: _ScopeTabs(
          scope: _scope,
          onChanged: (s) => setState(() => _scope = s),
        ),
      ),
      body: OmniaRefresh(
        onRefresh: () async {
          ref.invalidate(historyProvider);
          await ref.read(historyProvider.future);
        },
        child: historyAsync.when(
          loading: () => ListView(
            padding: EdgeInsets.only(bottom: tabBarInset(context)),
            children: const [
              TransferSkeleton(),
              TransferSkeleton(),
              TransferSkeleton(),
              TransferSkeleton(),
              TransferSkeleton(),
            ],
          ),
          error: (e, _) => ListView(
            children: [
              OmniaErrorState(
                message: friendlyError(e).message,
                onRetry: () => ref.invalidate(historyProvider),
              ),
            ],
          ),
          data: (records) {
            final visible = _scope == _Scope.mine
                ? [
                    for (final r in records)
                      if (myDid != null && r.fromDid == myDid) r,
                  ]
                : records;

            if (visible.isEmpty) {
              return ListView(
                children: [
                  OmniaEmptyState(
                    icon: _scope == _Scope.mine
                        ? Iconsax.money_send_copy
                        : Iconsax.receipt_2_copy,
                    title: _scope == _Scope.mine
                        ? 'Nothing sent yet'
                        : 'No activity yet',
                    message: _scope == _Scope.mine
                        ? 'Transfers you send will be listed here.'
                        : 'Transfers on the network will appear here.',
                  ),
                ],
              );
            }

            // Already newest-first from historyProvider.
            final sections = _groupByDay(visible);
            return CustomScrollView(
              slivers: [
                for (final section in sections) ...[
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _DayHeaderDelegate(label: section.label),
                  ),
                  SliverList.builder(
                    itemCount: section.records.length,
                    itemBuilder: (_, i) => TransferTile(
                      record: section.records[i],
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: SizedBox(height: tabBarInset(context) + Space.xl),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day grouping
// ---------------------------------------------------------------------------

typedef _DaySection = ({String label, List<TransferRecord> records});

/// Bucket an already-ordered list into consecutive day runs. Assumes the input
/// is newest-first, so runs are contiguous and a single pass suffices.
List<_DaySection> _groupByDay(List<TransferRecord> records) {
  final sections = <_DaySection>[];
  String? current;
  var bucket = <TransferRecord>[];

  for (final record in records) {
    final label = Fmt.dayLabel(record.dateTime);
    if (label != current) {
      if (current != null) {
        sections.add((label: current, records: bucket));
      }
      current = label;
      bucket = <TransferRecord>[];
    }
    bucket.add(record);
  }
  if (current != null) sections.add((label: current, records: bucket));
  return sections;
}

class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DayHeaderDelegate({required this.label});

  final String label;

  static const double _height = 34;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final o = context.omnia;
    return Container(
      height: _height,
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      decoration: BoxDecoration(
        color: o.bg25,
        border: Border(bottom: BorderSide(color: o.borderLow)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: FontSizes.xs,
          fontWeight: Weights.bold,
          letterSpacing: 0.6,
          color: o.textLow,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_DayHeaderDelegate old) => old.label != label;
}

// ---------------------------------------------------------------------------
// Scope tabs
// ---------------------------------------------------------------------------

/// Bluesky's feed switcher: text tabs with a short underline bar that slides
/// between them. Not a Material `SegmentedButton` — that reads as a form
/// control, and this is navigation.
class _ScopeTabs extends StatelessWidget implements PreferredSizeWidget {
  const _ScopeTabs({required this.scope, required this.onChanged});

  final _Scope scope;
  final ValueChanged<_Scope> onChanged;

  @override
  Size get preferredSize => const Size.fromHeight(42);

  @override
  Widget build(BuildContext context) {
    // Horizontally scrollable, the way a real feed switcher is: at large text
    // sizes the labels can exceed the width, and a clipped tab is worse than
    // one you can swipe to.
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        children: [
          for (final value in _Scope.values)
            _Tab(
              label: value == _Scope.all ? 'All activity' : 'Mine',
              selected: value == scope,
              onTap: () {
                if (value == scope) return;
                Haptics.tick();
                onChanged(value);
              },
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Pressable(
      onTap: onTap,
      haptic: false,
      feel: PressFeel.subtle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        // IntrinsicWidth makes the column exactly as wide as the label, so the
        // indicator underlines the *word* rather than filling a segment.
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: FontSizes.md,
                  fontWeight: selected ? Weights.bold : Weights.medium,
                  color: selected ? o.text : o.textLow,
                ),
              ),
              const SizedBox(height: Space.sm),
              // Scaled rather than resized: animating width would relayout the
              // whole row on every frame.
              AnimatedScale(
                scale: selected ? 1 : 0,
                alignment: Alignment.center,
                duration: Motion.fast,
                curve: Motion.standard,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: o.accent,
                    borderRadius: Radii.rFull,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
