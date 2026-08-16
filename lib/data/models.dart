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
    this.id,
    this.note,
    this.provenance = 'node_attested',
  });

  final String status;
  final int amount;
  final int newBalance;

  /// The transfer's id in the log — the same value [TransferRecord.id]
  /// carries. Lets the "sent" notification open this exact transfer instead
  /// of the whole log. Null if an older node omits it.
  final String? id;

  final String? note;

  /// Who authorized the spend: `wallet_signed` (the key owner's own
  /// signature was verified — self-sovereign) or `node_attested` (JWT-only).
  final String provenance;

  bool get isWalletSigned => provenance == 'wallet_signed';

  factory TransferResult.fromJson(Map<String, dynamic> json) => TransferResult(
        status: json['status'] as String? ?? 'unknown',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        newBalance: (json['new_balance'] as num?)?.toInt() ?? 0,
        id: json['id'] as String?,
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

// ---------------------------------------------------------------------------
// Financial ledger — the transferable asset
// ---------------------------------------------------------------------------
//
// Distinct from UBC in every way that matters to a user. UBC is a soulbound
// monthly compute right: sending it burns your quota and credits nobody.
// These balances genuinely move — the recipient's balance goes up by exactly
// what the sender's goes down. See `node/src/api/financial.rs`.
//
// Accounts here are addressed by Ed25519 public key, not DID: a
// `did:omnia:` is a truncated SHA-256 of the key, so it cannot be turned
// back into the verifying key the node needs to check a signature.

/// Response from `GET /api/v1/financial/balance/:pubkey`.
class FinancialBalance {
  FinancialBalance({
    required this.publicKeyHex,
    required this.did,
    required this.balance,
    required this.nextNonce,
    required this.totalSupply,
  });

  /// Hex-encoded Ed25519 public key identifying the account.
  final String publicKeyHex;

  /// DID derived from [publicKeyHex], for display alongside the identity.
  final String did;

  /// Spendable, transferable balance.
  final int balance;

  /// The nonce this account's next transfer must use. The node requires
  /// strictly increasing nonces, so a signature built with a stale value
  /// is rejected — always refresh this immediately before signing.
  final int nextNonce;

  /// Total supply across all accounts. A transfer conserves it.
  final int totalSupply;

  factory FinancialBalance.fromJson(Map<String, dynamic> json) =>
      FinancialBalance(
        publicKeyHex: json['public_key'] as String? ?? '',
        did: json['did'] as String? ?? '',
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        nextNonce: (json['next_nonce'] as num?)?.toInt() ?? 1,
        totalSupply: (json['total_supply'] as num?)?.toInt() ?? 0,
      );

  /// An account with nothing in it — used when the node has never seen it.
  factory FinancialBalance.empty(String publicKeyHex, String did) =>
      FinancialBalance(
        publicKeyHex: publicKeyHex,
        did: did,
        balance: 0,
        nextNonce: 1,
        totalSupply: 0,
      );
}

/// Response from `POST /api/v1/financial/transfer`.
class FinancialTransferResult {
  FinancialTransferResult({
    required this.status,
    required this.amount,
    required this.senderBalance,
    required this.recipientBalance,
    required this.eventId,
  });

  final String status;
  final int amount;

  /// The sender's balance after the transfer.
  final int senderBalance;

  /// The recipient's balance after the transfer — the number that makes
  /// this a transfer rather than a burn.
  final int recipientBalance;

  /// ID of the causal-graph event carrying the transfer, so the UI can
  /// link to an independently verifiable receipt.
  final String eventId;

  factory FinancialTransferResult.fromJson(Map<String, dynamic> json) =>
      FinancialTransferResult(
        status: json['status'] as String? ?? 'unknown',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        senderBalance: (json['sender_balance'] as num?)?.toInt() ?? 0,
        recipientBalance: (json['recipient_balance'] as num?)?.toInt() ?? 0,
        eventId: json['event_id'] as String? ?? '',
      );
}

// ---------------------------------------------------------------------------
// Ghana mobile-money acquisition and merchant settlement
// ---------------------------------------------------------------------------

/// A server-signed OMNIA quote. Economic terms are display-only on the client;
/// the node remains authoritative when the quote is initiated.
class OmniaQuote {
  OmniaQuote({
    required this.quoteId,
    required this.ghsAmountPesewas,
    required this.omniaQuantityPlancks,
    required this.exchangeRate,
    required this.providerFeePesewas,
    required this.omniaFeePlancks,
    required this.spreadBps,
    required this.estimatedDeliverySeconds,
    required this.createdAtMs,
    required this.expiresAtMs,
    required this.provider,
    required this.signature,
    required this.signerPublicKey,
    required this.disclosureFields,
    required this.totalGhsCostPesewas,
    required this.netOmniaPlancks,
  });

  final String quoteId;
  final int ghsAmountPesewas;
  final int omniaQuantityPlancks;
  final int exchangeRate;
  final int providerFeePesewas;
  final int omniaFeePlancks;
  final int spreadBps;
  final int estimatedDeliverySeconds;
  final int createdAtMs;
  final int expiresAtMs;
  final String provider;
  final List<QuoteDisclosure> disclosureFields;
  final List<int> signature;
  final List<int> signerPublicKey;
  final int totalGhsCostPesewas;
  final int netOmniaPlancks;

  bool isExpired([DateTime? now]) =>
      (now ?? DateTime.now()).millisecondsSinceEpoch >= expiresAtMs;

  factory OmniaQuote.fromJson(Map<String, dynamic> json) {
    final quote = (json['quote'] as Map<String, dynamic>?) ?? json;
    return OmniaQuote(
      quoteId: quote['quote_id']?.toString() ?? '',
      ghsAmountPesewas: (quote['ghs_amount'] as num?)?.toInt() ?? 0,
      omniaQuantityPlancks: (quote['omnia_quantity'] as num?)?.toInt() ?? 0,
      exchangeRate: (quote['exchange_rate'] as num?)?.toInt() ?? 0,
      providerFeePesewas: (quote['provider_fee_ghs'] as num?)?.toInt() ?? 0,
      omniaFeePlancks: (quote['omnia_fee'] as num?)?.toInt() ?? 0,
      spreadBps: (quote['spread_bps'] as num?)?.toInt() ?? 0,
      estimatedDeliverySeconds:
          (quote['estimated_delivery_secs'] as num?)?.toInt() ?? 0,
      createdAtMs: (quote['created_at_ms'] as num?)?.toInt() ?? 0,
      expiresAtMs: (quote['expires_at_ms'] as num?)?.toInt() ?? 0,
      provider: _providerName(quote['provider']),
      signature: _intList(json['signature']),
      signerPublicKey: _intList(json['signer_public_key']),
      disclosureFields: ((json['disclosure_fields'] as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(QuoteDisclosure.fromJson)
          .toList(growable: false),
      totalGhsCostPesewas: (json['total_ghs_cost_pesewas'] as num?)?.toInt() ??
          ((quote['ghs_amount'] as num?)?.toInt() ?? 0),
      netOmniaPlancks: (json['net_omnia_plancks'] as num?)?.toInt() ??
          ((quote['omnia_quantity'] as num?)?.toInt() ?? 0),
    );
  }

  static String _providerName(dynamic value) {
    if (value is String) return value.toUpperCase();
    if (value is Map<String, dynamic>) {
      return value['name']?.toString().toUpperCase() ?? 'MTN';
    }
    return value?.toString().split('.').last.toUpperCase() ?? 'MTN';
  }

  static List<int> _intList(dynamic value) =>
      (value is List<dynamic> ? value : const [])
          .whereType<num>()
          .map((item) => item.toInt())
          .toList(growable: false);
}

class QuoteDisclosure {
  QuoteDisclosure({required this.label, required this.value});

  final String label;
  final String value;

  factory QuoteDisclosure.fromJson(Map<String, dynamic> json) =>
      QuoteDisclosure(
        label: json['label']?.toString() ?? '',
        value: json['value']?.toString() ?? '',
      );
}

/// Authoritative payment-order snapshot returned by the node.
class PaymentOrderStatus {
  PaymentOrderStatus({
    required this.orderId,
    required this.state,
    required this.customerRef,
    required this.recipientRef,
    required this.ghsAmountPesewas,
    required this.ghsReceivedPesewas,
    required this.omniaQuantityPlancks,
    required this.exchangeRate,
    required this.providerFeePesewas,
    required this.omniaFeePlancks,
    required this.providerName,
    required this.providerRef,
    required this.inventoryReservationRef,
    required this.isTerminal,
    required this.isEconomicallyDelivered,
    required this.eventCount,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.quoteExpiryMs,
    required this.refundStatus,
  });

  final String orderId;
  final String state;
  final String customerRef;
  final String recipientRef;
  final int ghsAmountPesewas;
  final int? ghsReceivedPesewas;
  final int omniaQuantityPlancks;
  final int exchangeRate;
  final int providerFeePesewas;
  final int omniaFeePlancks;
  final String providerName;
  final String? providerRef;
  final String? inventoryReservationRef;
  final bool isTerminal;
  final bool isEconomicallyDelivered;
  final int eventCount;
  final int createdAtMs;
  final int updatedAtMs;
  final int quoteExpiryMs;
  final String refundStatus;

  bool get isSuccessful => state == 'DELIVERED';
  bool get isFailed => const {
        'PAYMENT_FAILED',
        'QUOTE_EXPIRED',
        'PAYMENT_REVERSED',
        'RISK_REJECTED',
        'INVENTORY_UNAVAILABLE',
        'ALLOCATION_FAILED',
        'REFUNDED',
        'CANCELLED',
      }.contains(state);

  factory PaymentOrderStatus.fromJson(Map<String, dynamic> json) {
    final order = (json['order'] as Map<String, dynamic>?) ?? json;
    return PaymentOrderStatus(
      orderId: order['order_id']?.toString() ?? '',
      state: order['state']?.toString() ?? 'UNKNOWN',
      customerRef: order['customer_ref']?.toString() ?? '',
      recipientRef: order['recipient_ref']?.toString() ?? '',
      ghsAmountPesewas: (order['ghs_amount_pesewas'] as num?)?.toInt() ?? 0,
      ghsReceivedPesewas: (order['ghs_received_pesewas'] as num?)?.toInt(),
      omniaQuantityPlancks:
          (order['omnia_quantity_plancks'] as num?)?.toInt() ?? 0,
      exchangeRate: (order['exchange_rate'] as num?)?.toInt() ?? 0,
      providerFeePesewas: (order['provider_fee_pesewas'] as num?)?.toInt() ?? 0,
      omniaFeePlancks: (order['omnia_fee_plancks'] as num?)?.toInt() ?? 0,
      providerName: order['provider_name']?.toString() ?? '',
      providerRef: order['provider_ref']?.toString(),
      inventoryReservationRef: order['inventory_reservation_ref']?.toString(),
      isTerminal: order['is_terminal'] as bool? ?? false,
      isEconomicallyDelivered:
          order['is_economically_delivered'] as bool? ?? false,
      eventCount: (order['event_count'] as num?)?.toInt() ?? 0,
      createdAtMs: (order['created_at_ms'] as num?)?.toInt() ?? 0,
      updatedAtMs: (order['updated_at_ms'] as num?)?.toInt() ?? 0,
      quoteExpiryMs: (order['quote_expiry_ms'] as num?)?.toInt() ?? 0,
      refundStatus: order['refund_status']?.toString() ?? 'None',
    );
  }
}

class BuyOmniaResult {
  BuyOmniaResult({required this.order, this.providerRef, this.nextStep});

  final PaymentOrderStatus order;
  final String? providerRef;
  final String? nextStep;

  factory BuyOmniaResult.fromJson(Map<String, dynamic> json) => BuyOmniaResult(
        order: PaymentOrderStatus.fromJson(json),
        providerRef: json['provider_ref']?.toString(),
        nextStep: json['next_step']?.toString(),
      );
}

class MerchantPaymentRequest {
  MerchantPaymentRequest({
    required this.paymentId,
    required this.merchantId,
    required this.customerWallet,
    required this.ghsPricePesewas,
    required this.omniaAmountPlancks,
    required this.exchangeRate,
    required this.quoteExpiryMs,
    required this.protocolFeePlancks,
    required this.status,
    required this.createdAtMs,
    this.merchantPublicKey,
    this.qrPayload,
  });

  final String paymentId;
  final String merchantId;
  final String customerWallet;
  final int ghsPricePesewas;
  final int omniaAmountPlancks;
  final int exchangeRate;
  final int quoteExpiryMs;
  final int protocolFeePlancks;
  final String status;
  final int createdAtMs;
  final String? merchantPublicKey;
  final Map<String, dynamic>? qrPayload;

  factory MerchantPaymentRequest.fromJson(Map<String, dynamic> json) {
    final request = (json['payment_request'] as Map<String, dynamic>?) ?? json;
    final payload = (json['qr_payload'] as Map<String, dynamic>?) ?? json;
    return MerchantPaymentRequest(
      paymentId: request['payment_id']?.toString() ??
          payload['payment_id']?.toString() ??
          '',
      merchantId: request['merchant_id']?.toString() ??
          payload['merchant_id']?.toString() ??
          '',
      customerWallet: request['customer_wallet']?.toString() ?? '',
      ghsPricePesewas: (request['ghs_price'] as num?)?.toInt() ??
          (request['ghs_price_pesewas'] as num?)?.toInt() ??
          (payload['ghs_price_pesewas'] as num?)?.toInt() ??
          0,
      omniaAmountPlancks: (request['omnia_amount'] as num?)?.toInt() ??
          (request['omnia_amount_plancks'] as num?)?.toInt() ??
          (payload['omnia_amount_plancks'] as num?)?.toInt() ??
          0,
      exchangeRate: (request['exchange_rate'] as num?)?.toInt() ?? 0,
      quoteExpiryMs: (request['quote_expiry_ms'] as num?)?.toInt() ??
          (payload['quote_expiry_ms'] as num?)?.toInt() ??
          0,
      protocolFeePlancks: (request['protocol_fee'] as num?)?.toInt() ?? 0,
      status: request['status']?.toString() ?? 'Pending',
      createdAtMs: (request['created_at_ms'] as num?)?.toInt() ?? 0,
      merchantPublicKey: payload['merchant_public_key']?.toString(),
      qrPayload: json['qr_payload'] as Map<String, dynamic>?,
    );
  }
}

class MerchantReceipt {
  MerchantReceipt({
    required this.paymentId,
    required this.merchantId,
    required this.ghsPricePesewas,
    required this.omniaAmountPlancks,
    required this.exchangeRate,
    required this.protocolFeePlancks,
    required this.netOmniaPlancks,
    required this.confirmedAtMs,
    this.txReference,
  });

  final String paymentId;
  final String merchantId;
  final int ghsPricePesewas;
  final int omniaAmountPlancks;
  final int exchangeRate;
  final int protocolFeePlancks;
  final int netOmniaPlancks;
  final int confirmedAtMs;
  final String? txReference;

  factory MerchantReceipt.fromJson(Map<String, dynamic> json) {
    final receipt = (json['receipt'] as Map<String, dynamic>?) ?? json;
    return MerchantReceipt(
      paymentId: receipt['payment_id']?.toString() ?? '',
      merchantId: receipt['merchant_id']?.toString() ?? '',
      ghsPricePesewas: (receipt['ghs_price'] as num?)?.toInt() ?? 0,
      omniaAmountPlancks: (receipt['omnia_amount'] as num?)?.toInt() ?? 0,
      exchangeRate: (receipt['exchange_rate'] as num?)?.toInt() ?? 0,
      protocolFeePlancks: (receipt['protocol_fee'] as num?)?.toInt() ?? 0,
      netOmniaPlancks: (receipt['net_omnia'] as num?)?.toInt() ?? 0,
      confirmedAtMs: (receipt['confirmed_at_ms'] as num?)?.toInt() ?? 0,
      txReference: receipt['tx_reference']?.toString(),
    );
  }
}
