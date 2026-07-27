import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/brand/identicon.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../core/ui/list_row.dart';
import '../../core/ui/sheet.dart';
import '../../core/ui/states.dart';
import '../../core/ui/thread.dart';
import '../../data/news.dart';
import '../../data/reactions.dart';
import '../../state/blocklist.dart';
import '../../state/reactions.dart';
import 'media_viewer.dart';
import 'reaction_loader.dart';
import 'thread_model.dart';

/// The conversation under a post, drawn the way Threads draws one.
///
/// Everything about *which* rows exist and *where the connectors run* is
/// decided by [buildThreadLayout] — a pure function with its own tests. This
/// widget only paints what that returns, which is what keeps the two hard
/// cases honest: a childless comment trails no rail, and a reply's elbow
/// curves out of the exact rail belonging to its parent.
class ThreadedReplies extends ConsumerStatefulWidget {
  const ThreadedReplies({
    super.key,
    required this.replies,
    required this.myUserId,
    required this.blocked,
    required this.canInteract,
    required this.onReply,
    required this.onMenu,
  });

  final List<NewsReply> replies;
  final String? myUserId;
  final Set<String> blocked;
  final bool canInteract;
  final void Function(NewsReply reply) onReply;
  final Future<void> Function(NewsReply reply, {required bool isMine}) onMenu;

  @override
  ConsumerState<ThreadedReplies> createState() => _ThreadedRepliesState();
}

class _ThreadedRepliesState extends ConsumerState<ThreadedReplies> {
  /// Parent ids whose held-back answers the reader has opened.
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final visible = widget.replies.where((r) {
      final key = blockKeyFor(userId: r.userId, name: r.authorName);
      return key == null || !widget.blocked.contains(key);
    }).toList();

    if (visible.isEmpty) {
      return const OmniaEmptyState(
        icon: Iconsax.message_copy,
        title: 'No replies yet',
        message: 'Be the first to say something.',
        compact: true,
      );
    }

    final layout = buildThreadLayout(visible, expanded: _expanded);

    return ReactionLoader(
      contentType: ReactionKey.reply,
      ids: [for (final r in visible) r.id],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < layout.rows.length; i++) ...[
            // A rule between comments, and only between comments. Each
            // top-level comment starts a separate conversation, so the line
            // marks where one ends and the next begins; drawing it between
            // replies too would cut a single thread into slices and undo what
            // the connectors are saying.
            if (i > 0 && layout.rows[i].depth == 0) const Hairline(),
            _ReplyRow(
              row: layout.rows[i],
              isMine: widget.myUserId != null &&
                  layout.rows[i].reply.userId == widget.myUserId,
              canInteract: widget.canInteract,
              onReply: widget.onReply,
              onMenu: widget.onMenu,
            ),
            if (layout.collapsed[i] case final run?)
              _CollapsedRun(
                run: run,
                onTap: () {
                  Haptics.selection();
                  setState(() => _expanded.add(run.parentId));
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _ReplyRow extends ConsumerWidget {
  const _ReplyRow({
    required this.row,
    required this.isMine,
    required this.canInteract,
    required this.onReply,
    required this.onMenu,
  });

  final ThreadRow row;
  final bool isMine;
  final bool canInteract;
  final void Function(NewsReply reply) onReply;
  final Future<void> Function(NewsReply reply, {required bool isMine}) onMenu;

  void _react(BuildContext context, WidgetRef ref, int direction) {
    final reactions = ref.read(reactionsProvider.notifier);
    if (!reactions.canReact) {
      showOmniaToast(context, message: 'Sign in to react', error: true);
      return;
    }
    Haptics.selection();
    // Deliberately not awaited: the tally on screen is already updated, and
    // the write is coalesced. Tapping twice quickly must feel like two taps,
    // not like two round trips.
    reactions.toggle(
      contentType: ReactionKey.reply,
      contentId: row.reply.id,
      direction: direction,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final reply = row.reply;
    final tally = ref.watch(
      reactionsProvider.select(
        (all) =>
            all[ReactionKey(ReactionKey.reply, reply.id)] ??
            const ReactionTally(),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
      child: ThreadItem(
        depth: row.depth,
        ancestorRails: row.ancestorRails,
        hasChildrenBelow: row.hasChildrenBelow,
        isLastChild: row.isLastChild,
        avatar: ClipOval(
          child: Identicon(seed: reply.authorDid ?? reply.authorName, size: 34),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ThreadHeader(
                name: reply.authorName,
                timestamp: '· ${Fmt.relative(reply.createdAt)}',
                onMore: () => onMenu(reply, isMine: isMine),
                moreTooltip: 'Reply options',
              ),
              if (reply.body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs),
                  child: Text(
                    reply.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: o.textHigh,
                    ),
                  ),
                ),
              if (reply.imageUrl case final url?) ...[
                const SizedBox(height: Space.sm),
                // Constrained rather than full-bleed: a reply's picture is an
                // aside, and letting it match the post's image would make
                // every answer shout as loud as the thing it answers.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: MediaThumb(
                    url: url,
                    heroTag: 'reply-media-${reply.id}',
                    maxHeight: 200,
                  ),
                ),
              ],
              const SizedBox(height: Space.xs),
              Row(
                children: [
                  ThreadLikeAction(
                    liked: tally.liked,
                    count: tally.likes,
                    onTap: () => _react(context, ref, 1),
                  ),
                  const SizedBox(width: ThreadAction.gap),
                  ThreadDislikeAction(
                    disliked: tally.disliked,
                    count: tally.dislikes,
                    onTap: () => _react(context, ref, -1),
                  ),
                  if (canInteract) ...[
                    const SizedBox(width: ThreadAction.gap),
                    ThreadAction(
                      icon: Iconsax.message_copy,
                      label: 'Reply',
                      onTap: () => onReply(reply),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Show replies" standing where the held-back answers will appear.
class _CollapsedRun extends StatelessWidget {
  const _CollapsedRun({required this.run, required this.onTap});

  final ThreadCollapsed run;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The marker sits at the depth of the replies it stands in for, so the
    // parent's rail runs straight down into it.
    final indent = ThreadGeometry.indentFor(run.depth) + 34 + Space.md;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      child: ThreadMoreReplies(
        indent: indent,
        // No count. The faces already say roughly how many, and a number
        // makes the row read as a statistic rather than an invitation.
        onTap: onTap,
        avatars: [
          for (final reply in run.hidden.take(3))
            Identicon(seed: reply.authorDid ?? reply.authorName, size: 18),
        ],
      ),
    );
  }
}
