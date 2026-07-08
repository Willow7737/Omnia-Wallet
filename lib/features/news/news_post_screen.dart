import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_mode.dart';
import '../../core/brand/identicon.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../data/news.dart';
import '../../state/news.dart';
import '../../state/providers.dart';
import 'news_screen.dart';

/// A single post with its conversation. Replies follow Threads' anatomy:
/// avatar column with a thin connector line stitching the thread together,
/// name + relative time on the top row, body underneath.
class NewsPostScreen extends ConsumerStatefulWidget {
  const NewsPostScreen({super.key, required this.post});

  final NewsPost post;

  @override
  ConsumerState<NewsPostScreen> createState() => _NewsPostScreenState();
}

class _NewsPostScreenState extends ConsumerState<NewsPostScreen> {
  final _replyController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final body = _replyController.text.trim();
    if (body.isEmpty) return;
    Haptics.medium();
    setState(() => _sending = true);
    try {
      final gateway = ref.read(supabaseGatewayProvider);
      final token = await gateway.accessToken();
      final displayName = ref.read(displayNameProvider).valueOrNull;
      final identity = ref.read(identityProvider).valueOrNull;
      final name = (displayName != null && displayName.isNotEmpty)
          ? displayName
          : (gateway.userEmail?.split('@').first ?? 'omnia user');
      await ref.read(newsRepositoryProvider).addReply(
            postId: widget.post.id,
            body: body,
            authorName: name,
            authorDid: identity?.did,
            accessToken: token,
          );
      _replyController.clear();
      ref.invalidate(newsRepliesProvider(widget.post.id));
      ref.invalidate(newsPostsProvider);
      if (mounted) Haptics.success();
    } catch (e) {
      if (mounted) {
        Haptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repliesAsync = ref.watch(newsRepliesProvider(widget.post.id));
    final mode =
        ref.watch(authModeProvider).valueOrNull ?? AuthMode.selfCustody;
    final canReply = mode == AuthMode.supabase &&
        ref.watch(supabaseGatewayProvider).isSignedIn;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(newsRepliesProvider(widget.post.id));
                await ref.read(newsRepliesProvider(widget.post.id).future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  NewsPostCard(post: widget.post, full: true),
                  const SizedBox(height: 18),
                  Text(
                    'Replies',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  repliesAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(friendlyError(e).message),
                    ),
                    data: (replies) {
                      if (replies.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No replies yet — start the conversation.',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (var i = 0; i < replies.length; i++)
                            _ReplyRow(
                              reply: replies[i],
                              isLast: i == replies.length - 1,
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Composer — or a sign-in hint for self-custody users.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: canReply
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            enabled: !_sending,
                            textCapitalization: TextCapitalization.sentences,
                            maxLength: 2000,
                            buildCounter: (_,
                                    {required currentLength,
                                    required isFocused,
                                    maxLength}) =>
                                null,
                            decoration: const InputDecoration(
                              hintText: 'Reply to omnia…',
                              isDense: true,
                            ),
                            onSubmitted: (_) => _sendReply(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sending ? null : _sendReply,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.arrow_upward),
                        ),
                      ],
                    )
                  : Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline,
                              size: 18, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Sign in with your Omnia account to join the '
                              'conversation.',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One Threads-style reply row: avatar + connector line on the left,
/// name/time/body on the right.
class _ReplyRow extends StatelessWidget {
  const _ReplyRow({required this.reply, required this.isLast});

  final NewsReply reply;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Avatar column with the thread connector.
          Column(
            children: [
              ClipOval(
                child: Identicon(
                  seed: reply.authorDid ?? reply.authorName,
                  size: 34,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.only(top: 4),
                    color: scheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 4 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reply.authorName,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Fmt.relative(reply.createdAt),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reply.body,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
