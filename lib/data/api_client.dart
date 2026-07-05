import 'package:dio/dio.dart';

import 'governance.dart';
import 'models.dart';

/// Low-level HTTP client for the Omnia node REST API (`/api/v1/...`).
///
/// Stateless with respect to auth: the caller passes a bearer [token] to the
/// authenticated methods. `AuthRepository` owns token lifecycle.
class ApiClient {
  ApiClient({required String baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'content-type': 'application/json'},
            )) {
    _dio.options.baseUrl = _normalize(baseUrl);
  }

  final Dio _dio;

  static String _normalize(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  set baseUrl(String url) => _dio.options.baseUrl = _normalize(url);

  Options _auth(String token) =>
      Options(headers: {'authorization': 'Bearer $token'});

  // ---- Auth (public) ----

  /// `POST /api/v1/auth/challenge` — returns the nonce to sign.
  Future<ChallengeResponse> requestChallenge(String publicKeyHex) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/challenge',
      data: {'public_key': publicKeyHex},
    );
    return ChallengeResponse.fromJson(res.data!);
  }

  /// `POST /api/v1/auth/login` — returns `{ did, token, expires_in }`.
  Future<LoginResponse> login({
    required String publicKeyHex,
    required String signatureHex,
    required String nonce,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/login',
      data: {
        'public_key': publicKeyHex,
        'signature': signatureHex,
        'nonce': nonce,
      },
    );
    return LoginResponse.fromJson(res.data!);
  }

  // ---- Economics (JWT) ----

  /// `GET /api/v1/economics/balance/:did`.
  ///
  /// A brand-new DID that has never transacted isn't registered in the node's
  /// quota system yet, so the node answers 404. That's an expected "empty
  /// wallet" state, not an error — surface it as a zero, unregistered balance
  /// so the UI shows "0 UBC · not registered yet" instead of an exception.
  Future<Balance> getBalance(String did, String token) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/economics/balance/$did',
        options: _auth(token),
      );
      return Balance.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Balance(
          did: did,
          balance: 0,
          monthlyQuota: 0,
          currentEpoch: 0,
          isRegistered: false,
        );
      }
      rethrow;
    }
  }

  /// `POST /api/v1/economics/transfer` — spends (burns) UBC. Soulbound.
  Future<TransferResult> transfer({
    required String fromDid,
    required String toDid,
    required int amount,
    required String token,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/economics/transfer',
      data: {'from_did': fromDid, 'to_did': toDid, 'amount': amount},
      options: _auth(token),
    );
    return TransferResult.fromJson(res.data!);
  }

  /// `GET /api/v1/economics/transfers?limit=N`.
  Future<List<TransferRecord>> listTransfers(String token,
      {int limit = 50}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/v1/economics/transfers',
      queryParameters: {'limit': limit},
      options: _auth(token),
    );
    final list = (res.data?['transfers'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(TransferRecord.fromJson)
        .toList();
    return list;
  }

  // ---- Governance (JWT) ----

  /// `GET /api/v1/governance/proposals`.
  Future<List<Proposal>> listProposals(String token) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/v1/governance/proposals',
      options: _auth(token),
    );
    return (res.data?['proposals'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Proposal.fromJson)
        .toList();
  }

  /// `POST /api/v1/governance/vote`.
  Future<CastVoteResult> castVote({
    required String did,
    required String proposalId,
    required VoteChoice choice,
    required String token,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/governance/vote',
      data: {'did': did, 'proposal_id': proposalId, 'choice': choice.wire},
      options: _auth(token),
    );
    return CastVoteResult.fromJson(res.data!);
  }

  /// `POST /api/v1/governance/proposals`.
  Future<CreateProposalResult> createProposal({
    required String id,
    required String description,
    required int expiresAtEpoch,
    required String token,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/governance/proposals',
      data: {
        'id': id,
        'description': description,
        'expires_at_epoch': expiresAtEpoch,
      },
      options: _auth(token),
    );
    return CreateProposalResult.fromJson(res.data!);
  }
}

/// `POST /api/v1/auth/challenge` response.
class ChallengeResponse {
  ChallengeResponse({
    required this.did,
    required this.nonce,
    required this.expiresAt,
    required this.message,
  });

  final String did;
  final String nonce;
  final int expiresAt;
  final String message;

  factory ChallengeResponse.fromJson(Map<String, dynamic> json) =>
      ChallengeResponse(
        did: json['did'] as String,
        nonce: json['nonce'] as String,
        expiresAt: (json['expires_at'] as num).toInt(),
        message: json['message'] as String,
      );
}

/// `POST /api/v1/auth/login` response.
class LoginResponse {
  LoginResponse({
    required this.did,
    required this.token,
    required this.expiresIn,
  });

  final String did;
  final String token;
  final int expiresIn;

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        did: json['did'] as String,
        token: json['token'] as String,
        expiresIn: (json['expires_in'] as num).toInt(),
      );
}
