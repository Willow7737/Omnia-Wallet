import 'auth_repository.dart';
import 'api_client.dart';
import 'models.dart';

/// Wallet actions (balance, send, history) that require an authenticated
/// session. Delegates token lifecycle to [AuthRepository].
class WalletRepository {
  WalletRepository({required AuthRepository auth, required ApiClient api})
      : _auth = auth,
        _api = api;

  final AuthRepository _auth;
  final ApiClient _api;

  Future<Balance> balance() async {
    final session = await _auth.ensureSession();
    return _api.getBalance(session.did, session.token);
  }

  Future<List<TransferRecord>> history({int limit = 50}) async {
    final session = await _auth.ensureSession();
    return _api.listTransfers(session.token, limit: limit);
  }

  /// Spend (burn) [amount] UBC. UBC is soulbound — the recipient is recorded
  /// for provenance but is NOT credited.
  Future<TransferResult> send({
    required String toDid,
    required int amount,
  }) async {
    final session = await _auth.ensureSession();
    return _api.transfer(
      fromDid: session.did,
      toDid: toDid,
      amount: amount,
      token: session.token,
    );
  }
}
