/// Governance models mirroring the node's `/api/v1/governance/*` responses.
/// See `node/src/api/governance.rs` and the interface's `lib/api-client.ts`.
library;

enum VoteChoice {
  forProposal('for'),
  against('against'),
  abstain('abstain');

  const VoteChoice(this.wire);

  /// The exact string the node expects ("for" / "against" / "abstain").
  final String wire;
}

/// A governance proposal (item in `GET /governance/proposals`).
class Proposal {
  Proposal({
    required this.id,
    required this.description,
    required this.createdAtEpoch,
    required this.expiresAtEpoch,
    required this.votesFor,
    required this.votesAgainst,
    required this.votesAbstain,
    required this.executionTime,
    required this.status,
    required this.totalParticipation,
  });

  final String id;
  final String description;
  final int createdAtEpoch;
  final int expiresAtEpoch;
  final int votesFor;
  final int votesAgainst;
  final int votesAbstain;
  final int? executionTime;

  /// Server-derived: "voting" / "expired" / "passed".
  final String status;
  final int totalParticipation;

  bool get isVoting => status.toLowerCase() == 'voting';

  int get totalVotes => votesFor + votesAgainst + votesAbstain;

  factory Proposal.fromJson(Map<String, dynamic> json) => Proposal(
        id: json['id'] as String? ?? '',
        description: json['description'] as String? ?? '',
        createdAtEpoch: (json['created_at_epoch'] as num?)?.toInt() ?? 0,
        expiresAtEpoch: (json['expires_at_epoch'] as num?)?.toInt() ?? 0,
        votesFor: (json['votes_for'] as num?)?.toInt() ?? 0,
        votesAgainst: (json['votes_against'] as num?)?.toInt() ?? 0,
        votesAbstain: (json['votes_abstain'] as num?)?.toInt() ?? 0,
        executionTime: (json['execution_time'] as num?)?.toInt(),
        status: json['status'] as String? ?? 'unknown',
        totalParticipation: (json['total_participation'] as num?)?.toInt() ?? 0,
      );
}

/// Result of `POST /governance/vote`.
class CastVoteResult {
  CastVoteResult({
    required this.status,
    required this.proposalId,
    required this.choice,
    required this.effectiveWeight,
    required this.epoch,
  });

  final String status;
  final String proposalId;
  final String choice;
  final int effectiveWeight;
  final int epoch;

  factory CastVoteResult.fromJson(Map<String, dynamic> json) => CastVoteResult(
        status: json['status'] as String? ?? '',
        proposalId: json['proposal_id'] as String? ?? '',
        choice: json['choice'] as String? ?? '',
        effectiveWeight: (json['effective_weight'] as num?)?.toInt() ?? 0,
        epoch: (json['epoch'] as num?)?.toInt() ?? 0,
      );
}

/// Result of `POST /governance/proposals`.
class CreateProposalResult {
  CreateProposalResult({
    required this.id,
    required this.status,
    required this.createdAtEpoch,
    required this.expiresAtEpoch,
  });

  final String id;
  final String status;
  final int createdAtEpoch;
  final int expiresAtEpoch;

  factory CreateProposalResult.fromJson(Map<String, dynamic> json) =>
      CreateProposalResult(
        id: json['id'] as String? ?? '',
        status: json['status'] as String? ?? '',
        createdAtEpoch: (json['created_at_epoch'] as num?)?.toInt() ?? 0,
        expiresAtEpoch: (json['expires_at_epoch'] as num?)?.toInt() ?? 0,
      );
}
