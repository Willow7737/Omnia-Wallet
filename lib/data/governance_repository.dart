import 'api_client.dart';
import 'auth_repository.dart';
import 'governance.dart';

/// Governance actions (list / vote / create) that require an authenticated
/// session. Delegates token lifecycle to [AuthRepository]. Uses only the
/// node's existing endpoints — no protocol changes.
class GovernanceRepository {
  GovernanceRepository({required AuthRepository auth, required ApiClient api})
      : _auth = auth,
        _api = api;

  final AuthRepository _auth;
  final ApiClient _api;

  Future<List<Proposal>> proposals() async {
    final session = await _auth.ensureSession();
    return _api.listProposals(session.token);
  }

  Future<CastVoteResult> vote(String proposalId, VoteChoice choice) async {
    final session = await _auth.ensureSession();
    return _api.castVote(
      did: session.did,
      proposalId: proposalId,
      choice: choice,
      token: session.token,
    );
  }

  Future<CreateProposalResult> create({
    required String id,
    required String description,
    required int expiresAtEpoch,
  }) async {
    final session = await _auth.ensureSession();
    return _api.createProposal(
      id: id,
      description: description,
      expiresAtEpoch: expiresAtEpoch,
      token: session.token,
    );
  }
}
