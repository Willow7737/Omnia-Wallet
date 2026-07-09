// End-to-end smoke test of the self-custody auth flow against a real node:
//   challenge -> sign -> login -> balance
//
// Usage: dart run tool/e2e_wallet_auth.dart [nodeUrl]
//
// Generates a throwaway keypair, so each run registers a fresh DID on the
// target node. Exits non-zero on any failure.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

Future<Map<String, dynamic>> _json(HttpClientResponse res) async =>
    jsonDecode(await res.transform(utf8.decoder).join())
        as Map<String, dynamic>;

Future<void> main(List<String> args) async {
  final base = args.isNotEmpty ? args.first : 'https://78.47.43.136.sslip.io';
  final client = HttpClient();

  // Fresh throwaway keypair.
  final seed = Uint8List.fromList(
      List.generate(32, (_) => DateTime.now().microsecond % 251 + 1));
  final priv = ed.newKeyFromSeed(seed);
  final pub = Uint8List.fromList(ed.public(priv).bytes);
  final pubHex = hex.encode(pub);
  final did =
      'did:omnia:${hex.encode(crypto.sha256.convert(pub).bytes).substring(0, 32)}';
  stdout.writeln('DID: $did');

  Future<Map<String, dynamic>> post(String path, Map<String, Object> body,
      {String? bearer}) async {
    final req = await client.postUrl(Uri.parse('$base$path'));
    req.headers.contentType = ContentType.json;
    if (bearer != null) req.headers.set('authorization', 'Bearer $bearer');
    req.write(jsonEncode(body));
    final res = await req.close();
    final data = await _json(res);
    if (res.statusCode != 200) {
      throw StateError('$path -> ${res.statusCode}: $data');
    }
    return data;
  }

  final chal = await post('/api/v1/auth/challenge', {'public_key': pubHex});
  stdout.writeln('challenge ok (nonce ${chal['nonce']})');

  final sig = ed.sign(
      priv, Uint8List.fromList(('omnia-auth:${chal['nonce']}').codeUnits));
  final login = await post('/api/v1/auth/login', {
    'public_key': pubHex,
    'signature': hex.encode(sig),
    'nonce': chal['nonce'] as String,
  });
  if (login['did'] != did) {
    throw StateError('DID mismatch: node says ${login['did']}');
  }
  stdout.writeln('login ok — JWT issued for $did');

  final balReq =
      await client.getUrl(Uri.parse('$base/api/v1/economics/balance/$did'));
  balReq.headers.set('authorization', 'Bearer ${login['token']}');
  final balRes = await balReq.close();
  final bal = await _json(balRes);
  if (balRes.statusCode != 200 || bal['is_registered'] != true) {
    throw StateError('balance -> ${balRes.statusCode}: $bal');
  }
  stdout.writeln(
      'balance ok — registered=${bal['is_registered']}, balance=${bal['balance']}, quota=${bal['monthly_quota']}');
  stdout.writeln('E2E PASS');
  client.close();
}
