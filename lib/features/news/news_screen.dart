import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand/brand.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../data/news.dart';
import '../../state/news.dart';

/// Posts we've hearted locally (session-scoped, purely decorative).
final likedPostsProvider = StateProvider<Set<String>>((ref) => {});

/// The news feed. Post layout follows Tumblr's single-post anatomy:
/// avatar + blog name header, body, lowercase #tags, then a footer with the
/// note count on the left and actions on the right.
class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(newsPostsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('News')),
      body: RefreshIndicator(
        onRefresh: () async {
          Haptics.light();
          ref.invalidate(newsPostsProvider);
          await ref.read(newsPostsProvider.future);
        },
        child: postsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(friendlyError(e).message)),
              ),
            ],
          ),
          data: (posts) {
            if (posts.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: Text('No news yet — stay tuned.')),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) => FadeSlideIn(
                delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                child: NewsPostCard(post: posts[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A rounded network image with graceful loading/error states, used for
/// post images and reply attachments.
class NewsImage extends StatelessWidget {
  const NewsImage({super.key, required this.url, this.maxHeight = 280});

  final String url;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Image.network(
          url,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 160,
              color: scheme.surfaceContainerHighest,
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            height: 120,
            color: scheme.surfaceContainerHighest,
            child: Center(
              child: Icon(Icons.broken_image_outlined,
                  color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tumblr-style post card. Set [full] on the detail screen to show the whole
/// body; the feed clamps it.
class NewsPostCard extends ConsumerWidget {
  const NewsPostCard({super.key, required this.post, this.full = false});

  final NewsPost post;
  final bool full;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final liked = ref.watch(likedPostsProvider).contains(post.id);

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: full
            ? null
            : () {
                Haptics.light();
                context.push('/news/${post.id}', extra: post);
              },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: avatar + blog name + time (Tumblr top bar).
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surface,
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: const BrandMark(size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    post.author,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Fmt.relative(post.createdAt),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: Icon(Icons.more_horiz,
                        size: 20, color: scheme.onSurfaceVariant),
                    onSelected: (action) {
                      Haptics.selection();
                      switch (action) {
                        case 'copy':
                          Clipboard.setData(ClipboardData(
                              text: '${post.title}\n\n${post.body}'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Post copied')),
                          );
                        case 'refresh':
                          ref.invalidate(newsPostsProvider);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'copy',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.copy, size: 20),
                          title: Text('Copy text'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'refresh',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.refresh, size: 20),
                          title: Text('Refresh feed'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Body: heading + prose.
              Text(
                post.title,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800, height: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                post.body,
                maxLines: full ? null : 5,
                overflow: full ? null : TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
              if (post.imageUrl != null) ...[
                const SizedBox(height: 12),
                NewsImage(url: post.imageUrl!),
              ],
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                // Tumblr tags: lowercase, muted, hash-prefixed.
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    for (final tag in post.tags)
                      Text(
                        '#$tag',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
              // Footer: note count left, actions right.
              Row(
                children: [
                  Text(
                    post.replyCount == 1
                        ? '1 reply'
                        : '${post.replyCount} replies',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Replies',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chat_bubble_outline, size: 20),
                    onPressed: () {
                      Haptics.light();
                      if (!full) {
                        context.push('/news/${post.id}', extra: post);
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Like',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: liked ? const Color(0xFFE0245E) : null,
                    ),
                    onPressed: () {
                      Haptics.selection();
                      final notifier = ref.read(likedPostsProvider.notifier);
                      final current = {...notifier.state};
                      liked ? current.remove(post.id) : current.add(post.id);
                      notifier.state = current;
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
