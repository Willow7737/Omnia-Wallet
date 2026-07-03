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

/// Result of `POST /api/v1/economics/transfer`.
class TransferResult {
  TransferResult({
    required this.status,
    required this.amount,
    required this.newBalance,
    this.note,
  });

  final String status;
  final int amount;
  final int newBalance;
  final String? note;

  factory TransferResult.fromJson(Map<String, dynamic> json) => TransferResult(
        status: json['status'] as String? ?? 'unknown',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        newBalance: (json['new_balance'] as num?)?.toInt() ?? 0,
        note: json['note'] as String?,
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
  });

  final String id;
  final String fromDid;
  final String toDid;
  final int amount;

  /// Unix-millisecond timestamp.
  final int timestamp;
  final String status;
  final int newBalance;

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  factory TransferRecord.fromJson(Map<String, dynamic> json) => TransferRecord(
        id: json['id'] as String? ?? '',
        fromDid: json['from_did'] as String? ?? '',
        toDid: json['to_did'] as String? ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? '',
        newBalance: (json['new_balance'] as num?)?.toInt() ?? 0,
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
