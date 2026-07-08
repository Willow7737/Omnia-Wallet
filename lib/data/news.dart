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
  });

  final String id;
  final String title;
  final String body;
  final List<String> tags;
  final String author;
  final DateTime createdAt;
  final int replyCount;

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
  });

  final String id;
  final String postId;
  final String authorName;
  final String? authorDid;
  final String body;
  final DateTime createdAt;

  factory NewsReply.fromJson(Map<String, dynamic> json) => NewsReply(
        id: json['id'] as String? ?? '',
        postId: json['post_id'] as String? ?? '',
        authorName: json['author_name'] as String? ?? 'someone',
        authorDid: json['author_did'] as String?,
        body: json['body'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Reads news through Supabase's PostgREST API with the public anon key —
/// works in both auth modes, no session needed. Posting a reply requires a
/// signed-in Supabase user's access token (RLS enforces it).
class NewsRepository {
  NewsRepository({String? supabaseUrl, String? anonKey, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
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
    required String accessToken,
  }) async {
    final res = await _dio.post<List<dynamic>>(
      '$_baseUrl/rest/v1/news_replies',
      data: {
        'post_id': postId,
        'body': body,
        'author_name': authorName,
        if (authorDid != null) 'author_did': authorDid,
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
}
