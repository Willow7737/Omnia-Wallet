import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omnia_wallet/core/auth_mode.dart';
import 'package:omnia_wallet/crypto/secure_store.dart';
import 'package:omnia_wallet/data/api_client.dart';
import 'package:omnia_wallet/data/auth_repository.dart';
import 'package:omnia_wallet/data/mint_jwt_client.dart';
import 'package:omnia_wallet/data/supabase_gateway.dart';

class MockStorage extends Mock implements FlutterSecureStorage {}

class MockDio extends Mock implements Dio {}

/// Deterministic in-test stand-in for supabase_flutter.
class FakeGateway implements SupabaseGateway {
  FakeGateway({this.token = 'supabase-access-token'});

  String token;
  bool signedOut = false;
  int tokenCalls = 0;

  @override
  bool get isAvailable => true;

  @override
  bool get isSignedIn => !signedOut;

  @override
  String? get userEmail => 'user@example.com';

  @override
  String? get userId => 'uid-1';

  @override
  String? get userName => 'Willow';

  @override
  Future<String> accessToken() async {
    tokenCalls++;
    return token;
  }

  @override
  Future<void> signInWithSocial(SocialProvider provider) async {}

  @override
  Future<void> signInWithEmail(
      {required String email, required String password}) async {}

  @override
  Future<void> signOut() async => signedOut = true;

  @override
  Stream<void> get signedIn => const Stream.empty();
}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late MockStorage storage;
  late Map<String, String?> disk;
  late MockDio mintDio;
  late MockDio apiDio;
  late FakeGateway gateway;
  late AuthRepository repo;
  int mintCalls = 0;

  void stubMint({int status = 200}) {
    when(() => mintDio.post<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async {
      mintCalls++;
      final req = RequestOptions(path: '/mint');
      if (status != 200) {
        throw DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: req, statusCode: status),
        );
      }
      return Response(
        requestOptions: req,
        statusCode: 200,
        data: {
          'did': 'did:omnia:11223344',
          'token': 'node-jwt',
          'expires_in': 86400,
        },
      );
    });
  }

  setUp(() {
    mintCalls = 0;
    disk = {};
    storage = MockStorage();
    when(() => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((inv) async {
      disk[inv.namedArguments[#key] as String] =
          inv.namedArguments[#value] as String?;
    });
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((inv) async => disk[inv.namedArguments[#key] as String]);
    when(() => storage.containsKey(key: any(named: 'key'))).thenAnswer(
        (inv) async => disk.containsKey(inv.namedArguments[#key] as String));
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer(
        (inv) async => disk.remove(inv.namedArguments[#key] as String));

    mintDio = MockDio();
    gateway = FakeGateway();
    // ApiClient's constructor assigns dio.options.baseUrl.
    apiDio = MockDio();
    when(() => apiDio.options).thenReturn(BaseOptions());
    // The post-mint DID registration call to the node.
    when(() => apiDio.post<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/api/v1/auth/register'),
          statusCode: 200,
          data: {'is_registered': true},
        ));
    repo = AuthRepository(
      store: SecureStore(storage),
      api: ApiClient(baseUrl: 'http://node.invalid', dio: apiDio),
      mintClient: MintJwtClient(
        supabaseUrl: 'https://project.supabase.co',
        anonKey: 'anon',
        dio: mintDio,
      ),
      supabase: gateway,
    );
  });

  group('AuthRepository (Mode B — Supabase)', () {
    test('completeSupabaseSignIn persists mode + DID and returns a session',
        () async {
      stubMint();
      final session = await repo.completeSupabaseSignIn();

      expect(session.did, 'did:omnia:11223344');
      expect(session.token, 'node-jwt');
      expect(await repo.authMode(), AuthMode.supabase);
      expect(await repo.hasWallet(), isTrue);

      final identity = await repo.loadIdentity();
      expect(identity?.did, 'did:omnia:11223344');
      expect(identity?.publicKeyHex, isNull);
      expect(identity?.mode, AuthMode.supabase);
    });

    test('sign-in registers the DID on the node with the minted JWT', () async {
      stubMint();
      await repo.completeSupabaseSignIn();

      final captured = verify(() => apiDio.post<Map<String, dynamic>>(
            captureAny(),
            options: captureAny(named: 'options'),
          )).captured;
      expect(captured[0], '/api/v1/auth/register');
      expect((captured[1] as Options).headers?['authorization'],
          'Bearer node-jwt');
    });

    test('a failing node registration does not block sign-in', () async {
      stubMint();
      when(() => apiDio.post<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/api/v1/auth/register'),
        type: DioExceptionType.connectionError,
      ));

      final session = await repo.completeSupabaseSignIn();
      expect(session.did, 'did:omnia:11223344');
      expect(await repo.hasWallet(), isTrue);
    });

    test('ensureSession reuses the cached node JWT until it expires', () async {
      stubMint();
      await repo.completeSupabaseSignIn();
      await repo.ensureSession();
      await repo.ensureSession();
      expect(mintCalls, 1);
    });

    test('a failed mint rolls the auth mode back', () async {
      stubMint(status: 401);
      await expectLater(
          repo.completeSupabaseSignIn(), throwsA(isA<DioException>()));
      expect(await repo.authMode(), AuthMode.selfCustody);
      expect(await repo.hasWallet(), isFalse);
    });

    test('logout signs out of Supabase and wipes local state', () async {
      stubMint();
      await repo.completeSupabaseSignIn();
      await repo.logout();

      expect(gateway.signedOut, isTrue);
      expect(await repo.hasWallet(), isFalse);
      expect(await repo.loadIdentity(), isNull);
      expect(await repo.authMode(), AuthMode.selfCustody);
    });
  });
}
