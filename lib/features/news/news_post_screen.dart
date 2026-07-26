import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth_mode.dart';
import '../../core/brand/identicon.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../core/ui/button.dart';
import '../../core/ui/header.dart';
import '../../core/ui/list_row.dart';
import '../../core/ui/press.dart';
import '../../core/ui/sheet.dart';
import '../../core/ui/states.dart';
import '../../core/ui/thread.dart';
import '../../data/news.dart';
import '../../state/blocklist.dart';
import '../../state/news.dart';
import '../../state/providers.dart';
import 'news_screen.dart';

/// A single post with its conversation.
///
/// Replies use a threaded anatomy: an avatar column with a thin connector line
/// stitching the thread together, name + relative time on the top row, body
/// underneath. Replies can be answered (one nesting level), and authors can
/// edit or delete their own.
class NewsPostScreen extends ConsumerStatefulWidget {
  const NewsPostScreen({super.key, required this.post});

  final NewsPost post;

  @override
  ConsumerState<NewsPostScreen> createState() => _NewsPostScreenState();
}

class _NewsPostScreenState extends ConsumerState<NewsPostScreen> {
  final _replyController = TextEditingController();
  bool _sending = false;

  /// Reply being answered ("Replying to …" chip above the composer).
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

  /// The name shown on this user's replies: local display name first, then the
  /// Supabase account's username (GitHub user_name / Google name), then the
  /// email prefix.
  String _authorName() {
    final displayName = ref.read(displayNameProvider).valueOrNull;
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final gateway = ref.read(supabaseGatewayProvider);
    return gateway.userName ??
        gateway.userEmail?.split('@').first ??
        'omnia user';
  }

  void _clearImage() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
      _imageMime = null;
    });
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
        _imageMime = picked.mimeType ?? 'image/jpeg';
      });
      Haptics.selection();
    } catch (e) {
      if (mounted) {
        showOmniaToast(context, message: friendlyError(e).message, error: true);
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
      if (mounted) {
        setState(() {
          _replyTo = null;
          _imageBytes = null;
          _imageName = null;
          _imageMime = null;
        });
      }
      ref.invalidate(newsRepliesProvider(widget.post.id));
      ref.invalidate(newsPostsProvider);
      if (mounted) Haptics.success();
    } catch (e) {
      if (mounted) {
        Haptics.error();
        showOmniaToast(context, message: friendlyError(e).message, error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _editReply(NewsReply reply) async {
    final newBody = await showOmniaInput(
      context,
      title: 'Edit reply',
      initialValue: reply.body,
      maxLines: 5,
      textCapitalization: TextCapitalization.sentences,
      validator: (v) => v.isEmpty ? 'A reply can\'t be empty' : null,
    );
    if (newBody == null || newBody == reply.body) return;

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
        showOmniaToast(context, message: friendlyError(e).message, error: true);
      }
    }
  }

  Future<void> _deleteReply(NewsReply reply) async {
    final confirmed = await showOmniaConfirm(
      context,
      icon: Iconsax.trash_copy,
      title: 'Delete reply?',
      message: 'This removes your reply for everyone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;

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
        showOmniaToast(context, message: friendlyError(e).message, error: true);
      }
    }
  }

  Future<void> _reportReply(NewsReply reply) async {
    final gateway = ref.read(supabaseGatewayProvider);
    if (!gateway.isSignedIn) {
      showOmniaToast(
        context,
        message: 'Sign in to report content',
        error: true,
      );
      return;
    }

    final reason = await showOmniaMenu<String>(
      context,
      title: 'Report content',
      actions: const [
        SheetAction(
          label: 'Spam or scam',
          value: 'Spam or scam',
          icon: Iconsax.danger_copy,
        ),
        SheetAction(
          label: 'Harassment or bullying',
          value: 'Harassment or bullying',
          icon: Iconsax.emoji_sad_copy,
        ),
        SheetAction(
          label: 'Hate speech',
          value: 'Hate speech',
          icon: Iconsax.volume_slash_copy,
        ),
        SheetAction(
          label: 'Sexual or explicit content',
          value: 'Sexual or explicit content',
          icon: Iconsax.eye_slash_copy,
        ),
        SheetAction(
          label: 'Violence or threats',
          value: 'Violence or threats',
          icon: Iconsax.warning_2_copy,
        ),
        SheetAction(label: 'Other', value: 'Other', icon: Iconsax.more_copy),
      ],
    );
    if (reason == null || !mounted) return;

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
        showOmniaToast(
          context,
          message: 'Reported — our team reviews within 24 hours',
        );
      }
    } catch (e) {
      if (mounted) {
        Haptics.error();
        showOmniaToast(context, message: friendlyError(e).message, error: true);
      }
    }
  }

  Future<void> _blockUser(NewsReply reply) async {
    final key = blockKeyFor(userId: reply.userId, name: reply.authorName);
    if (key == null) return;

    final confirmed = await showOmniaConfirm(
      context,
      icon: Iconsax.slash_copy,
      title: 'Block ${reply.authorName}?',
      message: "You won't see their posts or replies. You can unblock them "
          'later under Safety.',
      confirmLabel: 'Block',
      destructive: true,
    );
    if (!confirmed) return;

    await ref.read(blocklistProvider.notifier).block(key);
    if (mounted) {
      Haptics.success();
      showOmniaToast(context, message: 'Blocked ${reply.authorName}');
    }
  }

  Future<void> _replyMenu(NewsReply reply, {required bool isMine}) async {
    final action = await showOmniaMenu<String>(
      context,
      actions: isMine
          ? const [
              SheetAction(
                label: 'Edit reply',
                value: 'edit',
                icon: Iconsax.edit_2_copy,
              ),
              SheetAction(
                label: 'Delete reply',
                value: 'delete',
                icon: Iconsax.trash_copy,
                destructive: true,
              ),
            ]
          : [
              const SheetAction(
                label: 'Report',
                value: 'report',
                icon: Iconsax.flag_copy,
              ),
              SheetAction(
                label: 'Block ${reply.authorName}',
                value: 'block',
                icon: Iconsax.slash_copy,
                destructive: true,
              ),
            ],
    );
    if (action == null) return;

    switch (action) {
      case 'edit':
        await _editReply(reply);
      case 'delete':
        await _deleteReply(reply);
      case 'report':
        await _reportReply(reply);
      case 'block':
        await _blockUser(reply);
    }
  }

  void _startReplyTo(NewsReply reply) {
    Haptics.selection();
    // One nesting level: answering a child threads under its parent.
    setState(() => _replyTo = reply);
  }

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final repliesAsync = ref.watch(newsRepliesProvider(widget.post.id));
    final mode =
        ref.watch(authModeProvider).valueOrNull ?? AuthMode.selfCustody;
    final gateway = ref.watch(supabaseGatewayProvider);
    final canReply = mode == AuthMode.supabase && gateway.isSignedIn;
    final myUserId = gateway.isAvailable ? gateway.userId : null;
    final blocked = ref.watch(blocklistProvider);

    return Scaffold(
      backgroundColor: o.bg,
      appBar: const OmniaHeader(title: 'Post'),
      body: Column(
        children: [
          Expanded(
            child: OmniaRefresh(
              onRefresh: () async {
                ref.invalidate(newsRepliesProvider(widget.post.id));
                await ref.read(newsRepliesProvider(widget.post.id).future);
              },
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: Space.xl),
                children: [
                  NewsPostCard(post: widget.post, full: true),
                  const Hairline(),
                  const OmniaSectionLabel('Replies'),
                  repliesAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(Space.xxl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => OmniaErrorState(
                      message: friendlyError(e).message,
                      compact: true,
                      onRetry: () =>
                          ref.invalidate(newsRepliesProvider(widget.post.id)),
                    ),
                    data: (replies) => _ThreadedReplies(
                      replies: replies,
                      myUserId: myUserId,
                      blocked: blocked,
                      canInteract: canReply,
                      onReply: _startReplyTo,
                      onMenu: _replyMenu,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (canReply)
            _Composer(
              controller: _replyController,
              sending: _sending,
              replyTo: _replyTo,
              imageBytes: _imageBytes,
              onPickImage: _pickImage,
              onClearImage: _clearImage,
              onCancelReplyTo: () => setState(() => _replyTo = null),
              onSend: _sendReply,
            )
          else
            const _SignInHint(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Composer
// ---------------------------------------------------------------------------

/// The reply composer: an optional "Replying to" chip, an optional image
/// preview, and a pill-shaped field with attach + send.
///
/// Docked to the bottom with a hairline above it, and lifts with the keyboard
/// rather than being covered by it.
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
    final o = context.omnia;
    final target = replyTo;
    final bytes = imageBytes;

    return Container(
      decoration: BoxDecoration(
        color: o.bg,
        border: Border(top: BorderSide(color: o.borderLow)),
      ),
      padding: EdgeInsets.only(
        left: Space.md,
        right: Space.md,
        top: Space.sm,
        bottom: Space.sm +
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (target != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xs, 0, 0, Space.sm),
              child: Row(
                children: [
                  Icon(Iconsax.message_copy, size: 14, color: o.textLow),
                  const SizedBox(width: Space.xs + 2),
                  Expanded(
                    child: Text(
                      'Replying to ${target.authorName}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: FontSizes.sm,
                        color: o.textLow,
                      ),
                    ),
                  ),
                  OmniaIconButton(
                    icon: Iconsax.close_circle_copy,
                    size: 16,
                    box: 28,
                    color: o.textLow,
                    tooltip: 'Cancel reply',
                    onTap: onCancelReplyTo,
                  ),
                ],
              ),
            ),
          if (bytes != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xs, 0, 0, Space.sm),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: Radii.rSm,
                    child: Image.memory(
                      bytes,
                      height: 76,
                      width: 76,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Pressable(
                      onTap: onClearImage,
                      feel: PressFeel.subtle,
                      semanticLabel: 'Remove image',
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: o.text,
                          shape: BoxShape.circle,
                          border: Border.all(color: o.bg, width: 2),
                        ),
                        // Iconsax has no bare cross, and a circled one inside
                        // this circle reads as a ring in a ring. A quarter-
                        // turned plus is the glyph that belongs here.
                        child: Transform.rotate(
                          angle: math.pi / 4,
                          child: Icon(
                            Iconsax.add_copy,
                            size: 13,
                            color: o.bg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              OmniaIconButton(
                icon: Iconsax.gallery_copy,
                tooltip: 'Attach image',
                color: o.textMedium,
                onTap: sending ? null : onPickImage,
              ),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.lg,
                    vertical: Space.sm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: o.bg25,
                    borderRadius: Radii.rXl,
                    border: Border.all(color: o.borderMedium),
                  ),
                  child: TextField(
                    controller: controller,
                    enabled: !sending,
                    maxLines: null,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    // The counter would push the composer taller on every
                    // keystroke; the limit still applies.
                    buildCounter: (_,
                            {required currentLength,
                            required isFocused,
                            maxLength}) =>
                        null,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: FontSizes.md,
                      color: o.text,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Add a reply…',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              _SendButton(sending: sending, onSend: onSend),
            ],
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onSend});

  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Pressable(
      onTap: sending ? null : onSend,
      feel: PressFeel.firm,
      semanticLabel: 'Send reply',
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sending ? o.accentDisabled : o.accent,
          shape: BoxShape.circle,
        ),
        child: sending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: OmniaPalette.white,
                ),
              )
            : const Icon(
                Iconsax.arrow_up_3_copy,
                size: 18,
                color: OmniaPalette.white,
              ),
      ),
    );
  }
}

class _SignInHint extends StatelessWidget {
  const _SignInHint();

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: o.bg25,
        border: Border(top: BorderSide(color: o.borderLow)),
      ),
      padding: EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.lg,
        Space.md + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Row(
        children: [
          Icon(Iconsax.lock_copy, size: 17, color: o.textLow),
          const SizedBox(width: Space.md - 2),
          Expanded(
            child: Text(
              'Sign in with your Omnia account to join the conversation.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: FontSizes.sm,
                height: LineHeights.snug,
                color: o.textLow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thread
// ---------------------------------------------------------------------------

/// The reply list, laid out the way Threads lays out a conversation.
///
/// Top-level replies run down the page, each carrying a hairline rail from its
/// avatar to the next item so the whole thing reads as one thread. Answers to
/// a reply indent under it with a smaller avatar, and a run of more than
/// [_collapseAfter] answers collapses behind a "Show replies" row rather than
/// pushing the rest of the conversation off screen.
class _ThreadedReplies extends StatefulWidget {
  const _ThreadedReplies({
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
  final void Function(NewsReply) onReply;
  final Future<void> Function(NewsReply, {required bool isMine}) onMenu;

  @override
  State<_ThreadedReplies> createState() => _ThreadedRepliesState();
}

class _ThreadedRepliesState extends State<_ThreadedReplies> {
  /// How many answers to show before collapsing the rest.
  static const int _collapseAfter = 2;

  /// Parent ids whose collapsed run the user has expanded.
  final Set<String> _expanded = {};

  bool _isBlocked(NewsReply r) {
    final key = blockKeyFor(userId: r.userId, name: r.authorName);
    return key != null && widget.blocked.contains(key);
  }

  @override
  Widget build(BuildContext context) {
    // Hide replies from blocked authors (client-side moderation).
    final visible = widget.replies.where((r) => !_isBlocked(r)).toList();
    if (visible.isEmpty) {
      return OmniaEmptyState(
        icon: Iconsax.message_copy,
        title: widget.replies.isEmpty ? 'No replies yet' : 'No replies to show',
        message: widget.replies.isEmpty
            ? 'Start the conversation.'
            : 'The replies here are from people you blocked.',
        compact: true,
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
      final isLastTop = i == topLevel.length - 1;

      final expanded = _expanded.contains(parent.id);
      final shown = (children.length > _collapseAfter && !expanded)
          ? children.take(_collapseAfter).toList()
          : children;
      final hidden = children.length - shown.length;

      rows.add(_ReplyRow(
        reply: parent,
        // The rail continues while anything in this thread is still to come.
        railBelow: !(isLastTop && children.isEmpty),
        isMine: widget.myUserId != null && parent.userId == widget.myUserId,
        canInteract: widget.canInteract,
        onReply: widget.onReply,
        onMenu: widget.onMenu,
      ));

      for (var j = 0; j < shown.length; j++) {
        final isLastChild = j == shown.length - 1;
        rows.add(Padding(
          padding: const EdgeInsets.only(left: _ReplyRow.nestIndent),
          child: _ReplyRow(
            reply: shown[j],
            railBelow: !(isLastTop && isLastChild && hidden == 0),
            isMine:
                widget.myUserId != null && shown[j].userId == widget.myUserId,
            canInteract: widget.canInteract,
            onReply: widget.onReply,
            onMenu: widget.onMenu,
            nested: true,
          ),
        ));
      }

      if (hidden > 0) {
        rows.add(ThreadMoreReplies(
          indent: _ReplyRow.nestIndent,
          label:
              hidden == 1 ? 'Show 1 more reply' : 'Show $hidden more replies',
          avatars: [
            for (final r in children.skip(shown.length))
              Identicon(seed: r.authorDid ?? r.authorName, size: 18),
          ],
          onTap: () {
            Haptics.selection();
            setState(() => _expanded.add(parent.id));
          },
        ));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      child: Column(children: rows),
    );
  }
}

/// One item in the thread: avatar and rail on the left, identity/body/actions
/// on the right, overflow pinned to the far right.
class _ReplyRow extends StatelessWidget {
  const _ReplyRow({
    required this.reply,
    required this.railBelow,
    required this.isMine,
    required this.canInteract,
    required this.onReply,
    required this.onMenu,
    this.nested = false,
  });

  final NewsReply reply;
  final bool railBelow;
  final bool isMine;
  final bool canInteract;
  final bool nested;
  final void Function(NewsReply) onReply;
  final Future<void> Function(NewsReply, {required bool isMine}) onMenu;

  /// How far an answer indents under the reply it answers. Matches the width
  /// of the parent's avatar column plus its gutter, so a child's rail lines up
  /// inside its parent's.
  static const double nestIndent = 34 + Space.md;

  @override
  Widget build(BuildContext context) {
    final o = context.omnia;
    final theme = Theme.of(context);
    final avatarSize = nested ? 28.0 : 34.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ThreadRail(
            size: avatarSize,
            railBelow: railBelow,
            avatar: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: o.borderLow),
              ),
              clipBehavior: Clip.antiAlias,
              child: Identicon(
                seed: reply.authorDid ?? reply.authorName,
                size: avatarSize,
              ),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: railBelow ? Space.sm : Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ThreadHeader(
                    name: reply.authorName,
                    timestamp: Fmt.relative(reply.createdAt),
                    nameStyle: theme.textTheme.titleSmall,
                    onMore: () => onMenu(reply, isMine: isMine),
                  ),
                  Text(
                    reply.body,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: o.textHigh, height: 1.4),
                  ),
                  if (reply.imageUrl != null) ...[
                    const SizedBox(height: Space.sm),
                    NewsImage(url: reply.imageUrl!, maxHeight: 220),
                  ],
                  // Only top-level replies can be answered — one nesting
                  // level, so a child has nowhere deeper to go.
                  if (canInteract && !nested)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ThreadAction(
                        icon: Iconsax.message_copy,
                        label: 'Reply',
                        onTap: () => onReply(reply),
                      ),
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
