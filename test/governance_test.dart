import 'package:flutter_test/flutter_test.dart';
import 'package:omnia_wallet/data/governance.dart';

void main() {
  test('VoteChoice wire values match the node contract', () {
    expect(VoteChoice.forProposal.wire, 'for');
    expect(VoteChoice.against.wire, 'against');
    expect(VoteChoice.abstain.wire, 'abstain');
  });

  test('Proposal parses the node schema and derives helpers', () {
    final p = Proposal.fromJson({
      'id': 'prop-1',
      'description': 'Raise the quota',
      'created_at_epoch': 2,
      'expires_at_epoch': 5,
      'votes_for': 7,
      'votes_against': 3,
      'votes_abstain': 1,
      'execution_time': null,
      'status': 'voting',
      'total_participation': 11,
    });
    expect(p.id, 'prop-1');
    expect(p.isVoting, isTrue);
    expect(p.totalVotes, 11);
    expect(p.executionTime, isNull);
  });

  test('CastVoteResult parses', () {
    final r = CastVoteResult.fromJson({
      'status': 'recorded',
      'proposal_id': 'prop-1',
      'did': 'did:omnia:x',
      'choice': 'for',
      'effective_weight': 3,
      'epoch': 5,
    });
    expect(r.choice, 'for');
    expect(r.effectiveWeight, 3);
  });

  test('CreateProposalResult parses', () {
    final r = CreateProposalResult.fromJson({
      'id': 'prop-1',
      'status': 'created',
      'created_at_epoch': 2,
      'expires_at_epoch': 5,
    });
    expect(r.id, 'prop-1');
    expect(r.expiresAtEpoch, 5);
  });
}
