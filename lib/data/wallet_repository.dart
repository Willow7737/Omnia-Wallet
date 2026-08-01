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
  ///
  /// Self-custody wallets sign the transfer with their on-device key so the
  /// node verifies the key owner — not just the JWT — authorized the spend
  /// (Step 2, self-sovereign). Supabase-mode wallets have no on-device key,
  /// so `authorizeTransfer` returns null and the spend is node-attested.
  Future<TransferResult> send({
    required String toDid,
    required int amount,
  }) async {
    final session = await _auth.ensureSession();
    final authorization =
        await _auth.authorizeTransfer(toDid: toDid, amount: amount);
    return _api.transfer(
      fromDid: session.did,
      toDid: toDid,
      amount: amount,
      token: session.token,
      authorization: authorization,
    );
  }

  // ---- Financial ledger — the transferable asset ----

  /// This account's transferable balance.
  ///
  /// Separate from [balance], which reports the soulbound UBC quota.
  /// A wallet holds both: UBC meters what it may *do*, this is what it
  /// may *pay*.
  Future<FinancialBalance> financialBalance() async {
    final session = await _auth.ensureSession();
    final identity = _auth.identity ?? await _auth.loadIdentity();
    final publicKeyHex = identity?.publicKeyHex;
    if (publicKeyHex == null) {
      // Supabase-mode identities have no key, so they have no account on
      // the financial ledger — an empty balance, not an error.
      return FinancialBalance.empty('', session.did);
    }
    return _api.getFinancialBalance(publicKeyHex, session.did, session.token);
  }

  /// Send [amount] to [toPublicKeyHex] — a real transfer: the recipient is
  /// credited by exactly what this account is debited.
  ///
  /// Recipients are identified by Ed25519 public key rather than DID,
  /// because a `did:omnia:` is a one-way hash of the key and the ledger
  /// needs the key itself to verify signatures.
  ///
  /// The nonce is read immediately before signing rather than passed in:
  /// the ledger requires strictly increasing per-sender nonces, so a value
  /// fetched earlier in a session may already be stale.
  Future<FinancialTransferResult> sendFinancial({
    required String toPublicKeyHex,
    required int amount,
  }) async {
    final session = await _auth.ensureSession();
    final current = await financialBalance();

    if (current.publicKeyHex == toPublicKeyHex) {
      throw ArgumentError('Cannot send to your own account');
    }
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero');
    }
    if (amount > current.balance) {
      throw ArgumentError(
        'Insufficient balance: have ${current.balance}, need $amount',
      );
    }

    final auth = await _auth.authorizeFinancialTransfer(
      toPublicKeyHex: toPublicKeyHex,
      amount: amount,
      nonce: current.nextNonce,
    );

    return _api.financialTransfer(
      fromPublicKeyHex: auth.publicKeyHex,
      toPublicKeyHex: toPublicKeyHex,
      amount: amount,
      nonce: current.nextNonce,
      signatureHex: auth.signatureHex,
      token: session.token,
    );
  }
}
