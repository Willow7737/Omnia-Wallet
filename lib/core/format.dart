import 'package:intl/intl.dart';

/// Shared formatting helpers.
class Fmt {
  Fmt._();

  static final _int = NumberFormat.decimalPattern();
  static final _date = DateFormat('MMM d, y · HH:mm');
  static final _time = DateFormat('HH:mm');
  static final _dayThisYear = DateFormat('EEEE, MMM d');
  static final _dayOtherYear = DateFormat('MMM d, y');

  static String ubc(int amount) => '${_int.format(amount)} UBC';

  static String number(int n) => _int.format(n);

  static String dateTime(DateTime dt) => _date.format(dt);

  static String time(DateTime dt) => _time.format(dt);

  /// Compact relative time for feeds: `now`, `5m`, `3h`, `2d`, else a date.
  static String relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return _date.format(dt);
  }

  /// Section label for a day of activity: `Today`, `Yesterday`, then the
  /// weekday, and finally a full date once the year no longer matches.
  ///
  /// Compared on calendar date rather than elapsed hours, so something sent at
  /// 23:50 says "Yesterday" the next morning instead of "1d".
  static String dayLabel(DateTime dt) {
    final now = DateTime.now();
    final day = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final delta = today.difference(day).inDays;

    if (delta == 0) return 'Today';
    if (delta == 1) return 'Yesterday';
    if (dt.year == now.year) return _dayThisYear.format(dt);
    return _dayOtherYear.format(dt);
  }

  /// Abbreviate a DID for compact display: `did:omnia:1a2b…9f0e`.
  static String shortDid(String did) {
    const prefix = 'did:omnia:';
    if (!did.startsWith(prefix)) return did;
    final id = did.substring(prefix.length);
    if (id.length <= 10) return did;
    return '$prefix${id.substring(0, 4)}…${id.substring(id.length - 4)}';
  }

  /// Shorten a long opaque identifier (a tx hash, an event id) to its head and
  /// tail, leaving the middle elided.
  static String shortId(String id, {int edge = 8}) {
    if (id.length <= edge * 2 + 2) return id;
    return '${id.substring(0, edge)}…${id.substring(id.length - edge)}';
  }
}
