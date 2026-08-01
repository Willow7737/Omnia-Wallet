/// A payment request: a recipient DID plus an optional requested amount.
///
/// Encoded as an `omnia:` URI (BIP21-style) so a single QR/share payload can
/// carry both the DID and how much the requester is asking for:
///
/// ```text
/// omnia:did:omnia:<hex>            (DID only)
/// omnia:did:omnia:<hex>?amount=500 (DID + requested amount)
/// ```
///
/// Parsing is deliberately lenient — a bare `did:omnia:<hex>` (no scheme) is
/// accepted too, so scanning/pasting a plain DID still works. UBC is
/// soulbound, so a "payment request" is really a *spend* request: it prefills
/// the sender's Send form; nothing is credited to the recipient.
class PaymentRequest {
  const PaymentRequest({required this.did, this.amount, this.publicKeyHex});

  /// Recipient DID (`did:omnia:...`), lower-cased.
  final String did;

  /// Requested amount, or null if the request is DID-only. Always
  /// positive when present.
  final int? amount;

  /// Recipient's hex-encoded Ed25519 public key, when the request carries
  /// one (`&pk=`).
  ///
  /// **Required to be paid on the financial ledger.** A `did:omnia:` is a
  /// truncated SHA-256 of this key, so it cannot be reversed back into one
  /// — a DID-only request can prefill a soulbound UBC spend, but nobody
  /// can send transferable value to it. Older QR codes predate this field
  /// and parse with it null.
  final String? publicKeyHex;

  /// Whether this request can receive a transferable-asset payment.
  bool get isPayable => publicKeyHex != null;

  /// URI scheme for Omnia payment requests.
  static const String scheme = 'omnia';

  /// Encode as an `omnia:` URI. Emits each optional component only when
  /// it carries a value, so a DID-only request round-trips unchanged.
  String toUri() {
    final query = <String>[
      if (amount != null && amount! > 0) 'amount=$amount',
      if (publicKeyHex != null) 'pk=$publicKeyHex',
    ];
    final base = '$scheme:$did';
    return query.isEmpty ? base : '$base?${query.join('&')}';
  }

  /// Parse a scanned/pasted payload into a [PaymentRequest].
  ///
  /// Accepts a bare DID or an `omnia:<did>?amount=<n>` URI, tolerating
  /// surrounding whitespace/junk. Returns null when no well-formed Omnia DID
  /// is present. A non-positive or non-numeric amount is dropped (treated as
  /// DID-only) rather than rejecting the whole request.
  static PaymentRequest? parse(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    final didMatch = RegExp(
      r'did:omnia:[0-9a-fA-F]{8,64}',
      caseSensitive: false,
    ).firstMatch(text);
    if (didMatch == null) return null;
    final did = didMatch.group(0)!.toLowerCase();

    final amtMatch = RegExp(r'[?&]amount=(\d+)').firstMatch(text);
    final parsed = amtMatch != null ? int.tryParse(amtMatch.group(1)!) : null;
    final amount = (parsed != null && parsed > 0) ? parsed : null;

    // Exactly 64 hex characters — a malformed key is dropped rather than
    // carried forward, so a corrupted QR degrades to a DID-only request
    // instead of producing an address that silently fails to be paid.
    final pkMatch = RegExp(
      r'[?&]pk=([0-9a-fA-F]{64})(?![0-9a-fA-F])',
    ).firstMatch(text);
    final publicKeyHex = pkMatch?.group(1)?.toLowerCase();

    return PaymentRequest(did: did, amount: amount, publicKeyHex: publicKeyHex);
  }
}
