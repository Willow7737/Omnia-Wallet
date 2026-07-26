import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../core/brand/brand.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/ui/button.dart';
import '../../core/ui/header.dart';
import '../../core/ui/list_row.dart';
import '../../core/ui/press.dart';
import '../../core/ui/sheet.dart';
import '../../core/ui/states.dart';
import '../../data/news.dart';
import '../../state/news.dart';
import '../shell/app_shell.dart';

/// Posts hearted locally (session-scoped, purely decorative).
final likedPostsProvider = StateProvider<Set<String>>((ref) => {});

/// The News tab.
///
/// Restructured as a Bluesky feed rather than a stack of cards: posts are
/// full-bleed, separated by hairlines, with the author row on top and a quiet
/// action row underneath. No card backgrounds, no rounded containers — the
/// hairline does all the separating.
class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final postsAsync = ref.watch(newsPostsProvider);

    return Scaffold(
      backgroundColor: o.bg,
      appBar: const OmniaHeader(title: 'News', showBack: false),
      body: OmniaRefresh(
        onRefresh: () async {
          ref.invalidate(newsPostsProvider);
          await ref.read(newsPostsProvider.future);
        },
        child: postsAsync.when(
          loading: () => ListView(
            padding: EdgeInsets.only(bottom: tabBarInset(context)),
            children: const [
              _PostSkeleton(),
              Hairline(),
              _PostSkeleton(),
              Hairline(),
              _PostSkeleton(),
            ],
          ),
          error: (e, _) => ListView(
            children: [
              OmniaErrorState(
                message: friendlyError(e).message,
                onRetry: () => ref.invalidate(newsPostsProvider),
              ),
            ],
          ),
          data: (posts) {
            if (posts.isEmpty) {
              return ListView(
                children: const [
                  OmniaEmptyState(
                    icon: Iconsax.global_copy,
                    title: 'No news yet',
                    message: 'Updates from the Omnia team will land here.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: EdgeInsets.only(bottom: tabBarInset(context) + Space.xl),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const Hairline(),
              itemBuilder: (_, i) => FadeIn(
                delay: FadeIn.stagger(i),
                child: NewsPostCard(post: posts[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A network image with graceful loading and error states, used for post
/// images and reply attachments.
class NewsImage extends StatelessWidget {
  const NewsImage({super.key, required this.url, this.maxHeight = 300});

  final String url;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return ClipRRect(
      borderRadius: Radii.rMd,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: Radii.rMd,
          border: Border.all(color: o.borderLow),
        ),
        constraints: BoxConstraints(maxHeight: maxHeight),
        width: double.infinity,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 180,
              color: o.bg50,
              alignment: Alignment.center,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: o.textLow,
                  value: progress.expectedTotalBytes == null
                      ? null
                      : progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!,
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            height: 120,
            color: o.bg50,
            alignment: Alignment.center,
            child: Icon(Iconsax.gallery_slash_copy, color: o.textLow),
          ),
        ),
      ),
    );
  }
}

/// One post in the feed. Set [full] on the detail screen to show the whole
/// body; the feed clamps it.
class NewsPostCard extends ConsumerWidget {
  const NewsPostCard({super.key, required this.post, this.full = false});

  final NewsPost post;
  final bool full;

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final action = await showOmniaMenu<String>(
      context,
      actions: const [
        SheetAction(
          label: 'Copy text',
          value: 'copy',
          icon: Iconsax.copy_copy,
        ),
        SheetAction(
          label: 'Refresh feed',
          value: 'refresh',
          icon: Iconsax.refresh_copy,
        ),
      ],
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case 'copy':
        await Clipboard.setData(
          ClipboardData(text: '${post.title}\n\n${post.body}'),
        );
        if (context.mounted) {
          showOmniaToast(context, message: 'Post copied');
        }
      case 'refresh':
        ref.invalidate(newsPostsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final liked = ref.watch(likedPostsProvider).contains(post.id);

    return Pressable(
      onTap: full ? null : () => context.push('/post', extra: post),
      haptic: !full,
      feel: full ? PressFeel.none : PressFeel.normal,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.lg,
          Space.lg,
          Space.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row: mark, handle, relative time, overflow.
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: o.bg50,
                    shape: BoxShape.circle,
                    border: Border.all(color: o.borderLow),
                  ),
                  child: const BrandMark(size: 17),
                ),
                const SizedBox(width: Space.sm + 2),
                Flexible(
                  child: Text(
                    post.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: Space.xs + 2),
                Text(
                  '· ${Fmt.relative(post.createdAt)}',
                  style: theme.textTheme.labelSmall?.copyWith(color: o.textLow),
                ),
                const Spacer(),
                OmniaIconButton(
                  icon: Iconsax.more_copy,
                  size: 18,
                  box: 34,
                  color: o.textLow,
                  tooltip: 'More',
                  onTap: () => _menu(context, ref),
                ),
              ],
            ),
            const SizedBox(height: Space.md),

            Text(
              post.title,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: Space.xs + 2),
            Text(
              post.body,
              maxLines: full ? null : 4,
              overflow: full ? null : TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: o.textHigh),
            ),

            if (post.imageUrl != null) ...[
              const SizedBox(height: Space.md),
              NewsImage(url: post.imageUrl!),
            ],

            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.xs,
                children: [
                  for (final tag in post.tags)
                    Text(
                      '#$tag',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: o.link,
                        fontWeight: Weights.medium,
                      ),
                    ),
                ],
              ),
            ],

            const SizedBox(height: Space.sm),
            // Bluesky's action row: icon + count, low contrast, widely spaced,
            // left-aligned rather than pushed to the right edge.
            Row(
              children: [
                _Action(
                  icon: Iconsax.message_copy,
                  count: post.replyCount,
                  label: 'Replies',
                  onTap: () {
                    if (!full) context.push('/post', extra: post);
                  },
                ),
                const SizedBox(width: Space.x4l),
                _LikeAction(
                  liked: liked,
                  onTap: () {
                    Haptics.selection();
                    final notifier = ref.read(likedPostsProvider.notifier);
                    final next = {...notifier.state};
                    liked ? next.remove(post.id) : next.add(post.id);
                    notifier.state = next;
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final tint = color ?? o.textLow;
    return Pressable(
      onTap: onTap,
      feel: PressFeel.subtle,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: tint),
            if ((count ?? 0) > 0) ...[
              const SizedBox(width: Space.xs + 2),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: FontSizes.sm,
                  color: tint,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The heart, with the little pop Bluesky gives it on the way in.
class _LikeAction extends StatefulWidget {
  const _LikeAction({required this.liked, required this.onTap});

  final bool liked;
  final VoidCallback onTap;

  @override
  State<_LikeAction> createState() => _LikeActionState();
}

class _LikeActionState extends State<_LikeAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.fast,
    lowerBound: 1.0,
    upperBound: 1.35,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap() {
    // Only the *liking* direction pops. Un-liking with a flourish would
    // celebrate the wrong thing.
    if (!widget.liked) {
      _c.forward(from: 1.0).then((_) {
        if (mounted) _c.reverse();
      });
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return ScaleTransition(
      scale: _c,
      child: _Action(
        icon: widget.liked ? Iconsax.heart : Iconsax.heart_copy,
        label: 'Like',
        color: widget.liked ? o.like : null,
        onTap: _tap,
      ),
    );
  }
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton.circle(size: 34),
              SizedBox(width: Space.sm + 2),
              Skeleton.line(width: 100, height: 12),
            ],
          ),
          SizedBox(height: Space.md),
          Skeleton.line(width: 240, height: 17),
          SizedBox(height: Space.md),
          Skeleton.line(width: double.infinity, height: 11),
          SizedBox(height: Space.sm),
          Skeleton.line(width: double.infinity, height: 11),
          SizedBox(height: Space.sm),
          Skeleton.line(width: 180, height: 11),
        ],
      ),
    );
  }
}
