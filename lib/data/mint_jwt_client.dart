import 'package:dio/dio.dart';

import '../core/config.dart';

/// Response from the `mint-node-jwt` edge function: a node JWT for the DID
/// linked to the signed-in Supabase account.
class MintedJwt {
  MintedJwt({required this.did, required this.token, required this.expiresIn});

  final String did;
  final String token;
  final int expiresIn;

  factory MintedJwt.fromJson(Map<String, dynamic> json) => MintedJwt(
        did: json['did'] as String,
        token: json['token'] as String,
        expiresIn: (json['expires_in'] as num?)?.toInt() ?? 86400,
      );
}

/// Calls the Supabase edge function that verifies a Supabase session and
/// mints a node JWT (Mode B). `OMNIA_JWT_SECRET` never leaves the server —
/// the wallet only ever holds the short-lived result.
class MintJwtClient {
  MintJwtClient({String? supabaseUrl, String? anonKey, Dio? dio})
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

  Future<MintedJwt> mint(String supabaseAccessToken) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl${AppConfig.mintJwtPath}',
      options: Options(headers: {
        'authorization': 'Bearer $supabaseAccessToken',
        'apikey': _anonKey,
        'content-type': 'application/json',
      }),
    );
    return MintedJwt.fromJson(res.data!);
  }
}
