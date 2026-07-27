import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/brand/brand.dart';
import '../../core/config.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../core/ui/header.dart';
import '../../core/ui/list_row.dart';
import '../../core/ui/press.dart';
import '../../core/ui/scroll_to_top.dart';
import '../../core/ui/sheet.dart';
import '../../core/ui/states.dart';
import '../../core/ui/thread.dart';
import '../../data/news.dart';
import '../../data/reactions.dart';
import '../../state/news.dart';
import '../../state/reactions.dart';
import '../shell/app_shell.dart';
import 'media_viewer.dart';
import 'reaction_loader.dart';
import 'share_card.dart';

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
            return ReactionLoader(
              contentType: ReactionKey.post,
              ids: [for (final post in posts) post.id],
              child: ScrollToTop(
                child: ListView.separated(
                  padding:
                      EdgeInsets.only(bottom: tabBarInset(context) + Space.xl),
                  itemCount: posts.length,
                  separatorBuilder: (_, __) => const Hairline(),
                  itemBuilder: (_, i) => FadeIn(
                    delay: FadeIn.stagger(i),
                    child: NewsPostCard(post: posts[i]),
                  ),
                ),
              ),
            );
          },
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

  /// Share the post as a picture with the app link in the text.
  ///
  /// The image carries the post so it is readable at a glance in whatever app
  /// it lands in; the link is plain text beside it, because every share target
  /// linkifies text and almost none read a URL out of a picture.
  Future<void> _share(BuildContext context) async {
    Haptics.selection();
    try {
      // Render under a progress overlay, then hand off — the OS share sheet
      // must come up over the post, not over a spinner of ours.
      final path = await runWithOverlay(
        context,
        message: 'Preparing…',
        () async {
          final bytes = await PostShareCard.render(
            post: post,
            link: AppConfig.appUrl,
            image: await _decodePostImage(),
          );
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/omnia-post-${post.id}.png');
          await file.writeAsBytes(bytes, flush: true);
          return file.path;
        },
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'image/png')],
          // `subject` is what an email target uses as its subject line;
          // `text` is the body every other target shows. The link lives in
          // the text, not the picture — share targets linkify text, and none
          // of them read a URL out of an image.
          subject: post.title,
          text: '${post.title}\n\n${AppConfig.appUrl}',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Haptics.error();
        showOmniaToast(context, message: friendlyError(e).message, error: true);
      }
    }
  }

  /// Fetch and decode the post's picture for the share card, or null.
  ///
  /// A share must not fail because an image did not download — the card is
  /// still worth sharing without it.
  Future<ui.Image?> _decodePostImage() async {
    final url = post.imageUrl;
    if (url == null || url.isEmpty) return null;
    try {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 12),
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

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

  Future<void> _react(BuildContext context, WidgetRef ref) async {
    Haptics.selection();
    try {
      await ref.read(reactionsProvider.notifier).toggle(
            contentType: ReactionKey.post,
            contentId: post.id,
            direction: 1,
          );
    } catch (_) {
      if (context.mounted) {
        showOmniaToast(context, message: 'Sign in to react', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final tally = ref.watch(
      reactionsProvider.select(
        (all) =>
            all[ReactionKey(ReactionKey.post, post.id)] ??
            const ReactionTally(),
      ),
    );

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
                Expanded(
                  child: ThreadHeader(
                    name: post.author,
                    timestamp: '· ${Fmt.relative(post.createdAt)}',
                    onMore: () => _menu(context, ref),
                  ),
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

            if (post.imageUrl case final url? when url.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              MediaThumb(
                url: url,
                heroTag: 'post-media-${post.id}',
                caption: post.title,
              ),
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

            const SizedBox(height: Space.xs),
            // Threads' action row: left-aligned, evenly spaced, each count set
            // immediately beside its own glyph.
            Row(
              children: [
                ThreadLikeAction(
                  liked: tally.liked,
                  count: tally.likes,
                  onTap: () => _react(context, ref),
                ),
                const SizedBox(width: ThreadAction.gap),
                ThreadAction(
                  icon: Iconsax.message_copy,
                  count: post.replyCount,
                  label: 'Replies',
                  onTap: () {
                    if (!full) context.push('/post', extra: post);
                  },
                ),
                const SizedBox(width: ThreadAction.gap),
                ThreadAction(
                  icon: Iconsax.send_2_copy,
                  label: 'Share',
                  onTap: () => _share(context),
                ),
              ],
            ),
          ],
        ),
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
