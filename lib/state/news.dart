import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/news.dart';
import 'notices.dart';
import 'providers.dart';

final newsRepositoryProvider =
    Provider<NewsRepository>((ref) => NewsRepository());

/// The news feed, newest first. As a side effect, files a `news` notification
/// when a post newer than the last-seen one shows up (skipping the very first
/// fetch so a fresh install isn't greeted by a backlog of alerts).
final newsPostsProvider = FutureProvider<List<NewsPost>>((ref) async {
  final posts = await ref.watch(newsRepositoryProvider).listPosts();
  if (posts.isNotEmpty) {
    final store = ref.read(secureStoreProvider);
    final lastSeen = await store.readLastSeenNews();
    final newest = posts.first;
    if (lastSeen != null && lastSeen != newest.id) {
      ref.read(noticesProvider.notifier).add(
            type: NoticeType.news,
            title: 'News from the Omnia team',
            body: newest.title,
          );
    }
    await store.saveLastSeenNews(newest.id);
  }
  return posts;
});

/// Replies for one post, oldest first (threaded reading order).
final newsRepliesProvider =
    FutureProvider.family<List<NewsReply>, String>((ref, postId) async {
  return ref.watch(newsRepositoryProvider).listReplies(postId);
});
