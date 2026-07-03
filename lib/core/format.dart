import 'package:intl/intl.dart';

/// Shared formatting helpers.
class Fmt {
  Fmt._();

  static final _int = NumberFormat.decimalPattern();
  static final _date = DateFormat('MMM d, y · HH:mm');

  static String ubc(int amount) => '${_int.format(amount)} UBC';

  static String number(int n) => _int.format(n);

  static String dateTime(DateTime dt) => _date.format(dt);

  /// Abbreviate a DID for compact display: `did:omnia:1a2b…9f0e`.
  static String shortDid(String did) {
    const prefix = 'did:omnia:';
    if (!did.startsWith(prefix)) return did;
    final id = did.substring(prefix.length);
    if (id.length <= 10) return did;
    return '$prefix${id.substring(0, 4)}…${id.substring(id.length - 4)}';
  }
}
