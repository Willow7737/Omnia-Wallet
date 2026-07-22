import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth_mode.dart';
import '../../core/brand/identicon.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../data/news.dart';
import '../../state/blocklist.dart';
import '../../state/news.dart';
import '../../state/providers.dart';
import 'news_screen.dart';

/// A single post with its conversation. Replies follow Threads' anatomy:
/// avatar column with a thin connector line stitching the thread together,
/// name + relative time on the top row, body underneath. Replies can be
/// answered (one nesting level), and authors can edit/delete their own.
class NewsPostScreen extends ConsumerStatefulWidget {
  const NewsPostScreen({super.key, required this.post});

  final NewsPost post;

  @override
  ConsumerState<NewsPostScreen> createState() => _NewsPostScreenState();
}

class _NewsPostScreenState extends ConsumerState<NewsPostScreen> {
  final _replyController = TextEditingController();
  bool _sending = false;

  /// Reply being answered (Threads-style "Replying to …" chip).
  NewsReply? _replyTo;

  /// Image attached to the pending reply.
  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageMime;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  /// The name shown on this user's replies: local display name first, then
  /// the Supabase account's username (GitHub user_name / Google name),
  /// then the email prefix.
  String _authorName() {
    final displayName = ref.read(displayNameProvider).valueOrNull;
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final gateway = ref.read(supabaseGatewayProvider);
    return gateway.userName ??
        gateway.userEmail?.split('@').first ??
        'omnia user';
  }

  Future<void> _pickImage() async {
    Haptics.light();
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
        _imageMime = picked.mimeType ?? 'image/jpeg';
      });
      Haptics.selection();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e).message)),
        );
      }
    }
  }

  Future<void> _sendReply() async {
    final body = _replyController.text.trim();
    if (body.isEmpty && _imageBytes == null) return;
    Haptics.medium();
    setState(() => _sending = true);
    try {
      final gateway = ref.read(supabaseGatewayProvider);
      final token = await gateway.accessToken();
      final repo = ref.read(newsRepositoryProvider);

      String? imageUrl;
      final bytes = _imageBytes;
      if (bytes != null) {
        imageUrl = await repo.uploadImage(
          bytes: bytes,
          fileName: _imageName ?? 'image.jpg',
          contentType: _imageMime ?? 'image/jpeg',
          accessToken: token,
        );
      }

      final identity = ref.read(identityProvider).valueOrNull;
      await repo.addReply(
        postId: widget.post.id,
        body: body.isEmpty ? '📷' : body,
        authorName: _authorName(),
        authorDid: identity?.did,
        parentId: _replyTo?.id,
        imageUrl: imageUrl,
        accessToken: token,
      );
      _replyController.clear();
      setState(() {
        _replyTo = null;
        _imageBytes = null;
        _imageName = null;
        _imageMime = null;
      });
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

  Future<void> _editReply(NewsReply reply) async {
    final controller = TextEditingController(text: reply.body);
    final newBody = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit reply'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 2000,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newBody == null || newBody.isEmpty || newBody == reply.body) return;
    try {
      final token = await ref.read(supabaseGatewayProvider).accessToken();
      await ref.read(newsRepositoryProvider).updateReply(
            replyId: reply.id,
            body: newBody,
            accessToken: token,
          );
      ref.invalidate(newsRepliesProvider(widget.post.id));
      Haptics.success();
    } catch (e) {
      if (mounted) {
        Haptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e).message)),
        );
      }
    }
  }

  Future<void> _deleteReply(NewsReply reply) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete reply?'),
        content: const Text('This removes your reply for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = await ref.read(supabaseGatewayProvider).accessToken();
      await ref.read(newsRepositoryProvider).deleteReply(
            replyId: reply.id,
            accessToken: token,
          );
      ref.invalidate(newsRepliesProvider(widget.post.id));
      ref.invalidate(newsPostsProvider);
      Haptics.success();
    } catch (e) {
      if (mounted) {
        Haptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e).message)),
        );
      }
    }
  }

  Future<void> _reportReply(NewsReply reply) async {
    final gateway = ref.read(supabaseGatewayProvider);
    if (!gateway.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to report content.')),
      );
      return;
    }
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _ReportSheet(),
    );
    if (reason == null) return;
    try {
      final token = await gateway.accessToken();
      await ref.read(newsRepositoryProvider).reportContent(
            contentType: 'reply',
            contentId: reply.id,
            reason: reason,
            reportedAuthor: reply.authorDid ?? reply.authorName,
            accessToken: token,
          );
      if (mounted) {
        Haptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Reported. Thanks — our team reviews reports within 24 hours.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Haptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e).message)),
        );
      }
    }
  }

  Future<void> _blockUser(NewsReply reply) async {
    final key = blockKeyFor(userId: reply.userId, name: reply.authorName);
    if (key == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Block ${reply.authorName}?'),
        content: const Text(
            "You won't see their posts or replies. You can unblock them "
            'later in Settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(blocklistProvider.notifier).block(key);
    if (mounted) {
      Haptics.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Blocked ${reply.authorName}.')),
      );
    }
  }

  void _startReplyTo(NewsReply reply) {
    Haptics.selection();
    setState(() {
      // One nesting level: answering a child threads under its parent.
      _replyTo = reply;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repliesAsync = ref.watch(newsRepliesProvider(widget.post.id));
    final mode =
        ref.watch(authModeProvider).valueOrNull ?? AuthMode.selfCustody;
    final gateway = ref.watch(supabaseGatewayProvider);
    final canReply = mode == AuthMode.supabase && gateway.isSignedIn;
    final myUserId = gateway.isAvailable ? gateway.userId : null;
    final blocked = ref.watch(blocklistProvider);
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
                      return _ThreadedReplies(
                        replies: replies,
                        myUserId: myUserId,
                        blocked: blocked,
                        canInteract: canReply,
                        onReply: _startReplyTo,
                        onEdit: _editReply,
                        onDelete: _deleteReply,
                        onReport: _reportReply,
                        onBlock: _blockUser,
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: canReply
                  ? _Composer(
                      controller: _replyController,
                      sending: _sending,
                      replyTo: _replyTo,
                      imageBytes: _imageBytes,
                      onPickImage: _pickImage,
                      onClearImage: () => setState(() {
                        _imageBytes = null;
                        _imageName = null;
                        _imageMime = null;
                      }),
                      onCancelReplyTo: () => setState(() => _replyTo = null),
                      onSend: _sendReply,
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

/// The reply composer: optional "Replying to" chip, optional image preview,
/// text field with attach + send.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.replyTo,
    required this.imageBytes,
    required this.onPickImage,
    required this.onClearImage,
    required this.onCancelReplyTo,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final NewsReply? replyTo;
  final Uint8List? imageBytes;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final VoidCallback onCancelReplyTo;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (replyTo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.subdirectory_arrow_right,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Replying to ${replyTo!.authorName}',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                InkWell(
                  onTap: onCancelReplyTo,
                  child: Icon(Icons.close,
                      size: 16, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        if (imageBytes != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    imageBytes!,
                    height: 84,
                    width: 84,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 2,
                  left: 62,
                  child: InkWell(
                    onTap: onClearImage,
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(Icons.close, size: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            IconButton(
              tooltip: 'Attach image',
              onPressed: sending ? null : onPickImage,
              icon: const Icon(Icons.image_outlined),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !sending,
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
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ],
    );
  }
}

/// Renders the reply list with one level of nesting: top-level replies in
/// order, children indented beneath their parent.
class _ThreadedReplies extends StatelessWidget {
  const _ThreadedReplies({
    required this.replies,
    required this.myUserId,
    required this.blocked,
    required this.canInteract,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
    required this.onBlock,
  });

  final List<NewsReply> replies;
  final String? myUserId;
  final Set<String> blocked;
  final bool canInteract;
  final void Function(NewsReply) onReply;
  final void Function(NewsReply) onEdit;
  final void Function(NewsReply) onDelete;
  final void Function(NewsReply) onReport;
  final void Function(NewsReply) onBlock;

  bool _isBlocked(NewsReply r) {
    final key = blockKeyFor(userId: r.userId, name: r.authorName);
    return key != null && blocked.contains(key);
  }

  @override
  Widget build(BuildContext context) {
    // Hide replies from blocked authors (content moderation, client-side).
    final visible = replies.where((r) => !_isBlocked(r)).toList();
    if (visible.isEmpty) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No replies to show.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final byParent = <String, List<NewsReply>>{};
    final topLevel = <NewsReply>[];
    final ids = {for (final r in visible) r.id};
    for (final r in visible) {
      // Treat orphans (parent deleted or blocked) as top-level.
      if (r.parentId != null && ids.contains(r.parentId)) {
        byParent.putIfAbsent(r.parentId!, () => []).add(r);
      } else {
        topLevel.add(r);
      }
    }

    final rows = <Widget>[];
    for (var i = 0; i < topLevel.length; i++) {
      final parent = topLevel[i];
      final children = byParent[parent.id] ?? const <NewsReply>[];
      final parentIsLast = i == topLevel.length - 1 && children.isEmpty;
      rows.add(_ReplyRow(
        reply: parent,
        isLast: parentIsLast,
        isMine: myUserId != null && parent.userId == myUserId,
        canInteract: canInteract,
        onReply: onReply,
        onEdit: onEdit,
        onDelete: onDelete,
        onReport: onReport,
        onBlock: onBlock,
      ));
      for (var j = 0; j < children.length; j++) {
        rows.add(Padding(
          padding: const EdgeInsets.only(left: 40),
          child: _ReplyRow(
            reply: children[j],
            isLast: i == topLevel.length - 1 && j == children.length - 1,
            isMine: myUserId != null && children[j].userId == myUserId,
            canInteract: canInteract,
            onReply: onReply,
            onEdit: onEdit,
            onDelete: onDelete,
            onReport: onReport,
            onBlock: onBlock,
            nested: true,
          ),
        ));
      }
    }
    return Column(children: rows);
  }
}

/// One Threads-style reply row: avatar + connector line on the left,
/// name/time/body on the right, small action row underneath.
class _ReplyRow extends StatelessWidget {
  const _ReplyRow({
    required this.reply,
    required this.isLast,
    required this.isMine,
    required this.canInteract,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
    required this.onBlock,
    this.nested = false,
  });

  final NewsReply reply;
  final bool isLast;
  final bool isMine;
  final bool canInteract;
  final bool nested;
  final void Function(NewsReply) onReply;
  final void Function(NewsReply) onEdit;
  final void Function(NewsReply) onDelete;
  final void Function(NewsReply) onReport;
  final void Function(NewsReply) onBlock;

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
                  size: nested ? 28 : 34,
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
              padding: EdgeInsets.only(bottom: isLast ? 4 : 16),
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
                      PopupMenuButton<String>(
                        tooltip: 'More',
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: Icon(Icons.more_horiz,
                            color: scheme.onSurfaceVariant),
                        onSelected: (action) {
                          switch (action) {
                            case 'edit':
                              onEdit(reply);
                            case 'delete':
                              onDelete(reply);
                            case 'report':
                              onReport(reply);
                            case 'block':
                              onBlock(reply);
                          }
                        },
                        itemBuilder: (_) => isMine
                            ? const [
                                PopupMenuItem(
                                    value: 'edit', child: Text('Edit')),
                                PopupMenuItem(
                                    value: 'delete', child: Text('Delete')),
                              ]
                            : [
                                const PopupMenuItem(
                                  value: 'report',
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.flag_outlined),
                                    title: Text('Report'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'block',
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.block),
                                    title: Text('Block ${reply.authorName}'),
                                  ),
                                ),
                              ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reply.body,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                  if (reply.imageUrl != null) ...[
                    const SizedBox(height: 8),
                    NewsImage(url: reply.imageUrl!, maxHeight: 220),
                  ],
                  if (canInteract && !nested) ...[
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 30),
                          foregroundColor: scheme.onSurfaceVariant,
                        ),
                        onPressed: () => onReply(reply),
                        icon: const Icon(Icons.chat_bubble_outline, size: 15),
                        label: const Text('Reply'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet that asks why a piece of content is being reported and pops
/// the chosen reason (content moderation). Returns null if dismissed.
class _ReportSheet extends StatelessWidget {
  const _ReportSheet();

  static const _reasons = <(String, IconData)>[
    ('Spam or scam', Icons.report_gmailerrorred_outlined),
    ('Harassment or bullying', Icons.mood_bad_outlined),
    ('Hate speech', Icons.volume_off_outlined),
    ('Sexual or explicit content', Icons.no_adult_content_outlined),
    ('Violence or threats', Icons.dangerous_outlined),
    ('Other', Icons.more_horiz),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text(
              'Report content',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Tell us what’s wrong. Our team reviews every report within '
              '24 hours and removes anything that breaks our guidelines.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          for (final (label, icon) in _reasons)
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              onTap: () => Navigator.of(context).pop(label),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
