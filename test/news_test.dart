import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omnia_wallet/data/news.dart';

class MockDio extends Mock implements Dio {}

RequestOptions _req() => RequestOptions(path: '/rest/v1/news_posts');

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  group('NewsPost.fromJson', () {
    test('parses fields and the embedded reply count', () {
      final post = NewsPost.fromJson({
        'id': 'abc',
        'title': 'Hello',
        'body': 'World',
        'tags': ['welcome', 'omnia'],
        'author': 'omnia',
        'created_at': '2026-07-08T10:00:00Z',
        'news_replies': [
          {'count': 4},
        ],
      });
      expect(post.id, 'abc');
      expect(post.tags, ['welcome', 'omnia']);
      expect(post.replyCount, 4);
      expect(post.createdAt.year, 2026);
    });

    test('defaults reply count to 0 when the embed is missing', () {
      final post = NewsPost.fromJson({
        'id': 'x',
        'title': 't',
        'body': 'b',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(post.replyCount, 0);
      expect(post.author, 'omnia');
      expect(post.tags, isEmpty);
    });
  });

  group('NewsRepository', () {
    late MockDio dio;
    late NewsRepository repo;

    setUp(() {
      dio = MockDio();
      repo = NewsRepository(
        supabaseUrl: 'https://project.supabase.co',
        anonKey: 'anon-key',
        dio: dio,
      );
    });

    test('listPosts queries PostgREST with the reply-count embed', () async {
      Map<String, dynamic>? params;
      Options? sent;
      when(() => dio.get<List<dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((inv) async {
        params = inv.namedArguments[#queryParameters] as Map<String, dynamic>?;
        sent = inv.namedArguments[#options] as Options?;
        return Response(requestOptions: _req(), statusCode: 200, data: [
          {
            'id': 'p1',
            'title': 'T',
            'body': 'B',
            'created_at': '2026-07-08T10:00:00Z',
            'news_replies': [
              {'count': 2},
            ],
          },
        ]);
      });

      final posts = await repo.listPosts();
      expect(posts.single.replyCount, 2);
      expect(params?['select'], '*,news_replies(count)');
      expect(params?['order'], 'created_at.desc');
      expect(sent?.headers?['apikey'], 'anon-key');
      // Reads authenticate as anon.
      expect(sent?.headers?['authorization'], 'Bearer anon-key');
    });

    test('addReply posts with the user access token and returns the row',
        () async {
      Options? sent;
      Object? body;
      when(() => dio.post<List<dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((inv) async {
        sent = inv.namedArguments[#options] as Options?;
        body = inv.namedArguments[#data];
        return Response(requestOptions: _req(), statusCode: 201, data: [
          {
            'id': 'r1',
            'post_id': 'p1',
            'author_name': 'Willow',
            'body': 'Nice',
            'created_at': '2026-07-08T11:00:00Z',
          },
        ]);
      });

      final reply = await repo.addReply(
        postId: 'p1',
        body: 'Nice',
        authorName: 'Willow',
        accessToken: 'user-token',
      );
      expect(reply.id, 'r1');
      expect(reply.authorName, 'Willow');
      expect(sent?.headers?['authorization'], 'Bearer user-token');
      expect(sent?.headers?['prefer'], 'return=representation');
      expect((body as Map)['post_id'], 'p1');
    });
  });
}
