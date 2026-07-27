import 'package:dio/dio.dart';

import '../core/config.dart';

/// The like/dislike tally for one post or reply, plus this user's own standing
/// on it.
///
/// [mine] is `1`, `-1` or `0` — the same alphabet the server stores, so an
/// optimistic update and the row it will become are directly comparable.
class ReactionTally {
  const ReactionTally({this.likes = 0, this.dislikes = 0, this.mine = 0});

  final int likes;
  final int dislikes;

  /// +1 liked, -1 disliked, 0 no reaction from this user.
  final int mine;

  bool get liked => mine == 1;
  bool get disliked => mine == -1;

  /// What this tally becomes when the user presses [direction] (+1 or -1).
  ///
  /// Pressing the direction you already hold clears it — a second tap on the
  /// heart un-likes. Pressing the opposite direction moves the vote across in
  /// one step rather than needing two taps, which is why this is arithmetic on
  /// both counters rather than a simple increment.
  ///
  /// This is the optimistic update the UI paints before the write lands, so it
  /// has to agree exactly with the row the server ends up holding.
  ReactionTally toggled(int direction) {
    assert(direction == 1 || direction == -1);
    final next = mine == direction ? 0 : direction;

    var l = likes;
    var d = dislikes;
    if (mine == 1) l -= 1;
    if (mine == -1) d -= 1;
    if (next == 1) l += 1;
    if (next == -1) d += 1;

    // A count can only go negative if the tally we started from was stale.
    // Clamp rather than render "-1 likes".
    return ReactionTally(
      likes: l < 0 ? 0 : l,
      dislikes: d < 0 ? 0 : d,
      mine: next,
    );
  }

  /// Fresh server counts, keeping whatever this user's own standing is.
  ReactionTally withCounts({required int likes, required int dislikes}) =>
      ReactionTally(likes: likes, dislikes: dislikes, mine: mine);

  ReactionTally withMine(int mine) =>
      ReactionTally(likes: likes, dislikes: dislikes, mine: mine);

  @override
  bool operator ==(Object other) =>
      other is ReactionTally &&
      other.likes == likes &&
      other.dislikes == dislikes &&
      other.mine == mine;

  @override
  int get hashCode => Object.hash(likes, dislikes, mine);

  @override
  String toString() =>
      'ReactionTally(likes: $likes, dislikes: $dislikes, mine: $mine)';
}

/// Content addressed by kind and id. Posts and replies live in separate tables
/// but share one reaction table, so the pair is the key everywhere.
class ReactionKey {
  const ReactionKey(this.contentType, this.contentId);

  /// `'post'` or `'reply'` — matches the CHECK constraint on the table.
  final String contentType;
  final String contentId;

  static const String post = 'post';
  static const String reply = 'reply';

  @override
  bool operator ==(Object other) =>
      other is ReactionKey &&
      other.contentType == contentType &&
      other.contentId == contentId;

  @override
  int get hashCode => Object.hash(contentType, contentId);

  @override
  String toString() => '$contentType:$contentId';
}

/// Reads and writes `news_reactions` through PostgREST.
///
/// Public counts come from the `news_reaction_counts` view — one row per piece
/// of content rather than one per reaction — so a post with a thousand likes
/// costs the same to render as one with none.
class ReactionRepository {
  ReactionRepository({String? supabaseUrl, String? anonKey, Dio? dio})
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

  /// PostgREST's `in.(…)` list. Ids are UUIDs in practice, but a stray comma
  /// or paren would change the meaning of the filter, so quote each one.
  static String inList(Iterable<String> ids) {
    final quoted = ids.map((id) => '"${id.replaceAll('"', r'\"')}"').join(',');
    return '($quoted)';
  }

  /// Public tallies for [ids]. Content nobody has reacted to has no row in the
  /// view and is simply absent from the result.
  Future<Map<ReactionKey, ReactionTally>> counts({
    required String contentType,
    required List<String> ids,
  }) async {
    if (ids.isEmpty) return const {};
    final res = await _dio.get<List<dynamic>>(
      '$_baseUrl/rest/v1/news_reaction_counts',
      queryParameters: {
        'content_type': 'eq.$contentType',
        'content_id': 'in.${inList(ids)}',
        'select': 'content_id,likes,dislikes',
      },
      options: Options(headers: _headers()),
    );

    final out = <ReactionKey, ReactionTally>{};
    for (final row in (res.data ?? []).cast<Map<String, dynamic>>()) {
      final id = row['content_id'] as String?;
      if (id == null) continue;
      out[ReactionKey(contentType, id)] = ReactionTally(
        likes: (row['likes'] as num?)?.toInt() ?? 0,
        dislikes: (row['dislikes'] as num?)?.toInt() ?? 0,
      );
    }
    return out;
  }

  /// This user's own reactions among [ids], as `key -> +1 | -1`.
  ///
  /// The user filter is explicit because RLS lets anyone read every row — the
  /// policy protects writes, not reads.
  Future<Map<ReactionKey, int>> mine({
    required String contentType,
    required List<String> ids,
    required String userId,
    required String accessToken,
  }) async {
    if (ids.isEmpty) return const {};
    final res = await _dio.get<List<dynamic>>(
      '$_baseUrl/rest/v1/news_reactions',
      queryParameters: {
        'content_type': 'eq.$contentType',
        'content_id': 'in.${inList(ids)}',
        'user_id': 'eq.$userId',
        'select': 'content_id,value',
      },
      options: Options(headers: _headers(accessToken: accessToken)),
    );

    final out = <ReactionKey, int>{};
    for (final row in (res.data ?? []).cast<Map<String, dynamic>>()) {
      final id = row['content_id'] as String?;
      final value = (row['value'] as num?)?.toInt();
      if (id == null || value == null) continue;
      out[ReactionKey(contentType, id)] = value;
    }
    return out;
  }

  /// Record [value] (+1 like, -1 dislike), or clear it when [value] is 0.
  ///
  /// The composite primary key makes this an upsert: reacting twice is still
  /// one row, and switching from like to dislike updates in place.
  Future<void> setReaction({
    required String contentType,
    required String contentId,
    required int value,
    required String userId,
    required String accessToken,
  }) async {
    if (value == 0) {
      await _dio.delete<void>(
        '$_baseUrl/rest/v1/news_reactions',
        queryParameters: {
          'content_type': 'eq.$contentType',
          'content_id': 'eq.$contentId',
          'user_id': 'eq.$userId',
        },
        options: Options(headers: _headers(accessToken: accessToken)),
      );
      return;
    }

    await _dio.post<void>(
      '$_baseUrl/rest/v1/news_reactions',
      data: {
        'content_type': contentType,
        'content_id': contentId,
        'user_id': userId,
        'value': value,
      },
      options: Options(headers: {
        ..._headers(accessToken: accessToken),
        'prefer': 'resolution=merge-duplicates,return=minimal',
      }),
    );
  }
}
