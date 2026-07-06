import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omnia_wallet/data/mint_jwt_client.dart';

class MockDio extends Mock implements Dio {}

RequestOptions _req() => RequestOptions(path: '/functions/v1/mint-node-jwt');

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  group('MintJwtClient', () {
    late MockDio dio;
    late MintJwtClient client;

    setUp(() {
      dio = MockDio();
      client = MintJwtClient(
        supabaseUrl: 'https://project.supabase.co',
        anonKey: 'anon-key',
        dio: dio,
      );
    });

    test('POSTs the access token and parses {did, token, expires_in}',
        () async {
      Options? sent;
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          )).thenAnswer((inv) async {
        sent = inv.namedArguments[#options] as Options?;
        return Response(
          requestOptions: _req(),
          statusCode: 200,
          data: {
            'did': 'did:omnia:abcd1234',
            'token': 'node-jwt',
            'expires_in': 86400,
          },
        );
      });

      final minted = await client.mint('supabase-access-token');

      expect(minted.did, 'did:omnia:abcd1234');
      expect(minted.token, 'node-jwt');
      expect(minted.expiresIn, 86400);

      // The edge function URL and both auth headers must be present.
      final url = verify(() => dio.post<Map<String, dynamic>>(
            captureAny(),
            options: any(named: 'options'),
          )).captured.single as String;
      expect(url, 'https://project.supabase.co/functions/v1/mint-node-jwt');
      expect(sent?.headers?['authorization'], 'Bearer supabase-access-token');
      expect(sent?.headers?['apikey'], 'anon-key');
    });

    test('defaults expires_in to 86400 when missing', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: _req(),
            statusCode: 200,
            data: {'did': 'did:omnia:x', 'token': 't'},
          ));
      final minted = await client.mint('token');
      expect(minted.expiresIn, 86400);
    });

    test('propagates HTTP errors', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          )).thenThrow(DioException(
        requestOptions: _req(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: _req(), statusCode: 401),
      ));
      expect(() => client.mint('expired'), throwsA(isA<DioException>()));
    });
  });
}
