/// Data models mirroring the Omnia node's economics API responses.
/// See `node/src/api/economics.rs` and the interface's `lib/api-client.ts`.
library;

/// Response from `GET /api/v1/economics/balance/:did`.
class Balance {
  Balance({
    required this.did,
    required this.balance,
    required this.monthlyQuota,
    required this.currentEpoch,
    required this.isRegistered,
  });

  final String did;
  final int balance;
  final int monthlyQuota;
  final int currentEpoch;
  final bool isRegistered;

  factory Balance.fromJson(Map<String, dynamic> json) => Balance(
        did: json['did'] as String? ?? '',
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        monthlyQuota: (json['monthly_quota'] as num?)?.toInt() ?? 0,
        currentEpoch: (json['current_epoch'] as num?)?.toInt() ?? 0,
        isRegistered: json['is_registered'] as bool? ?? false,
      );
}

/// A wallet-signed spend authorization attached to a transfer request
/// (self-sovereign transfers, Step 2). Mirrors the node's
/// `TransferAuthorization`: the wallet's public key, the single-use nonce
/// it consumed from `/auth/challenge`, and the Ed25519 signature over the
/// canonical transfer message.
class TransferAuthorization {
  TransferAuthorization({
    required this.publicKeyHex,
    required this.nonce,
    required this.signatureHex,
  });

  final String publicKeyHex;
  final String nonce;
  final String signatureHex;

  Map<String, dynamic> toJson() => {
        'public_key': publicKeyHex,
        'nonce': nonce,
        'signature': signatureHex,
      };
}

/// Result of `POST /api/v1/economics/transfer`.
class TransferResult {
  TransferResult({
    required this.status,
    required this.amount,
    required this.newBalance,
    this.note,
    this.provenance = 'node_attested',
  });

  final String status;
  final int amount;
  final int newBalance;
  final String? note;

  /// Who authorized the spend: `wallet_signed` (the key owner's own
  /// signature was verified — self-sovereign) or `node_attested` (JWT-only).
  final String provenance;

  bool get isWalletSigned => provenance == 'wallet_signed';

  factory TransferResult.fromJson(Map<String, dynamic> json) => TransferResult(
        status: json['status'] as String? ?? 'unknown',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        newBalance: (json['new_balance'] as num?)?.toInt() ?? 0,
        note: json['note'] as String?,
        provenance: json['provenance'] as String? ?? 'node_attested',
      );
}

/// An item in `GET /api/v1/economics/transfers`.
class TransferRecord {
  TransferRecord({
    required this.id,
    required this.fromDid,
    required this.toDid,
    required this.amount,
    required this.timestamp,
    required this.status,
    required this.newBalance,
    this.eventId,
    this.provenance = 'node_attested',
    this.lane0Final,
  });

  final String id;
  final String fromDid;
  final String toDid;
  final int amount;

  /// Unix-millisecond timestamp.
  final int timestamp;
  final String status;
  final int newBalance;

  /// Hex ID of the on-chain causal-graph event recording this transfer,
  /// or null if the provenance event wasn't submitted.
  final String? eventId;

  /// Who authorized the spend: `wallet_signed` (the key owner's own
  /// signature was verified) or `node_attested` (JWT-only).
  final String provenance;

  /// Whether the transfer's event has reached Lane 0 fast-path finality.
  /// Null when the node has Lane 0 disabled (the field is absent), so the
  /// UI can distinguish "not final yet" from "finality not tracked here".
  final bool? lane0Final;

  bool get isWalletSigned => provenance == 'wallet_signed';

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  factory TransferRecord.fromJson(Map<String, dynamic> json) => TransferRecord(
        id: json['id'] as String? ?? '',
        fromDid: json['from_did'] as String? ?? '',
        toDid: json['to_did'] as String? ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? '',
        newBalance: (json['new_balance'] as num?)?.toInt() ?? 0,
        eventId: json['event_id'] as String?,
        provenance: json['provenance'] as String? ?? 'node_attested',
        lane0Final: json['lane0_final'] as bool?,
      );
}

/// Public node status from `GET /api/v1/node/info`.
class NodeInfo {
  NodeInfo({
    required this.version,
    required this.protocolVersion,
    required this.uptimeSeconds,
    required this.peers,
    required this.finalizedHeight,
    required this.shardCount,
  });

  final String version;
  final String protocolVersion;
  final int uptimeSeconds;
  final int peers;
  final int finalizedHeight;
  final int shardCount;

  factory NodeInfo.fromJson(Map<String, dynamic> json) => NodeInfo(
        version: json['version'] as String? ?? '—',
        protocolVersion: json['protocol_version']?.toString() ?? '—',
        uptimeSeconds: (json['uptime_seconds'] as num?)?.toInt() ?? 0,
        peers: (json['peers'] as num?)?.toInt() ?? 0,
        finalizedHeight: (json['finalized_height'] as num?)?.toInt() ?? 0,
        shardCount: (json['shard_count'] as num?)?.toInt() ?? 0,
      );
}

/// Session credentials returned by `POST /api/v1/auth/login`.
class Session {
  Session({required this.did, required this.token, required this.expiresAt});

  final String did;
  final String token;

  /// Absolute expiry (device clock).
  final DateTime expiresAt;

  bool isExpiredWithin(Duration skew) =>
      DateTime.now().add(skew).isAfter(expiresAt);
}
