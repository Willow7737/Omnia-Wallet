import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/config.dart';

/// A post from the Omnia team (the `news_posts` table).
class NewsPost {
  const NewsPost({
    required this.id,
    required this.title,
    required this.body,
    required this.tags,
    required this.author,
    required this.createdAt,
    required this.replyCount,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String body;
  final List<String> tags;
  final String author;
  final DateTime createdAt;
  final int replyCount;
  final String? imageUrl;

  factory NewsPost.fromJson(Map<String, dynamic> json) {
    // PostgREST embeds the reply count as `news_replies: [{count: n}]`.
    var count = 0;
    final embedded = json['news_replies'];
    if (embedded is List && embedded.isNotEmpty) {
      final first = embedded.first;
      if (first is Map && first['count'] is num) {
        count = (first['count'] as num).toInt();
      }
    }
    return NewsPost(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
      author: json['author'] as String? ?? 'omnia',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      replyCount: count,
      imageUrl: json['image_url'] as String?,
    );
  }
}

/// A reply under a post (the `news_replies` table).
class NewsReply {
  const NewsReply({
    required this.id,
    required this.postId,
    required this.authorName,
    required this.authorDid,
    required this.body,
    required this.createdAt,
    this.userId,
    this.parentId,
    this.imageUrl,
  });

  final String id;
  final String postId;
  final String authorName;
  final String? authorDid;
  final String body;
  final DateTime createdAt;

  /// The Supabase user that wrote it — lets the client offer edit/delete
  /// on the author's own replies (RLS enforces it server-side regardless).
  final String? userId;

  /// Set when this reply answers another reply (one-level threading).
  final String? parentId;

  final String? imageUrl;

  factory NewsReply.fromJson(Map<String, dynamic> json) => NewsReply(
        id: json['id'] as String? ?? '',
        postId: json['post_id'] as String? ?? '',
        authorName: json['author_name'] as String? ?? 'someone',
        authorDid: json['author_did'] as String?,
        body: json['body'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        userId: json['user_id'] as String?,
        parentId: json['parent_id'] as String?,
        imageUrl: json['image_url'] as String?,
      );
}

/// Reads news through Supabase's PostgREST API with the public anon key —
/// works in both auth modes, no session needed. Writing (replies, media
/// uploads, edits, deletes) requires a signed-in Supabase user's access
/// token; RLS enforces ownership server-side.
class NewsRepository {
  NewsRepository({String? supabaseUrl, String? anonKey, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            )),
        _baseUrl = _normalize(supabaseUrl ?? AppConfig.supabaseUrl),
        _anonKey = anonKey ?? AppConfig.supabaseAnonKey;

  final Dio _dio;
  final String _baseUrl;
  final String _anonKey;

  static String _normalize(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  Map<String, String> _headers({String? accessToken}) => {
        'apikey': _anonKey,
        'authorization': 'Bearer ${accessToken ?? _anonKey}',
        'content-type': 'application/json',
      };

  /// Newest first, with reply counts.
  Future<List<NewsPost>> listPosts() async {
    final res = await _dio.get<List<dynamic>>(
      '$_baseUrl/rest/v1/news_posts',
      queryParameters: {
        'select': '*,news_replies(count)',
        'order': 'created_at.desc',
      },
      options: Options(headers: _headers()),
    );
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(NewsPost.fromJson)
        .toList();
  }

  /// Oldest first — replies read top-to-bottom like a thread.
  Future<List<NewsReply>> listReplies(String postId) async {
    final res = await _dio.get<List<dynamic>>(
      '$_baseUrl/rest/v1/news_replies',
      queryParameters: {
        'post_id': 'eq.$postId',
        'order': 'created_at.asc',
      },
      options: Options(headers: _headers()),
    );
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(NewsReply.fromJson)
        .toList();
  }

  /// Post a reply as the signed-in Supabase user. `user_id` defaults to
  /// `auth.uid()` server-side; RLS rejects anonymous writes.
  Future<NewsReply> addReply({
    required String postId,
    required String body,
    required String authorName,
    String? authorDid,
    String? parentId,
    String? imageUrl,
    required String accessToken,
  }) async {
    final res = await _dio.post<List<dynamic>>(
      '$_baseUrl/rest/v1/news_replies',
      data: {
        'post_id': postId,
        'body': body,
        'author_name': authorName,
        if (authorDid != null) 'author_did': authorDid,
        if (parentId != null) 'parent_id': parentId,
        if (imageUrl != null) 'image_url': imageUrl,
      },
      options: Options(headers: {
        ..._headers(accessToken: accessToken),
        'prefer': 'return=representation',
      }),
    );
    final rows = (res.data ?? []).cast<Map<String, dynamic>>();
    if (rows.isEmpty) {
      throw StateError('Reply was not saved');
    }
    return NewsReply.fromJson(rows.first);
  }

  /// Edit one's own reply (RLS restricts to the author).
  Future<void> updateReply({
    required String replyId,
    required String body,
    required String accessToken,
  }) async {
    await _dio.patch<void>(
      '$_baseUrl/rest/v1/news_replies',
      queryParameters: {'id': 'eq.$replyId'},
      data: {'body': body},
      options: Options(headers: _headers(accessToken: accessToken)),
    );
  }

  /// Delete one's own reply (children cascade server-side).
  Future<void> deleteReply({
    required String replyId,
    required String accessToken,
  }) async {
    await _dio.delete<void>(
      '$_baseUrl/rest/v1/news_replies',
      queryParameters: {'id': 'eq.$replyId'},
      options: Options(headers: _headers(accessToken: accessToken)),
    );
  }

  /// Upload an image to the public `news-media` bucket and return its
  /// public URL. Requires a signed-in user (bucket policy).
  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String accessToken,
  }) async {
    final path = 'replies/${DateTime.now().millisecondsSinceEpoch}-$fileName';
    await _dio.post<void>(
      '$_baseUrl/storage/v1/object/news-media/$path',
      // A single-chunk stream keeps Dio from JSON-encoding the bytes.
      data: Stream.fromIterable([bytes]),
      options: Options(headers: {
        'apikey': _anonKey,
        'authorization': 'Bearer $accessToken',
        'content-type': contentType,
        'content-length': bytes.length.toString(),
      }),
    );
    return '$_baseUrl/storage/v1/object/public/news-media/$path';
  }
}
