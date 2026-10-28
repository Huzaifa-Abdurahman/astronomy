import 'package:intl/intl.dart';

/// Display formatting. Times are stored in UTC and converted to the device's
/// local time only here (CLAUDE.md §6).

String formatClock(DateTime? utc) => utc == null ? '—' : DateFormat.Hm().format(utc.toLocal());

String formatRange(DateTime? a, DateTime? b) => (a == null || b == null) ? '—' : '${formatClock(a)}–${formatClock(b)}';

String formatDay(DateTime utc) => DateFormat('EEE d MMM').format(utc.toLocal());

/// "60.9°"
String formatDeg(double? deg, {int digits = 1}) => deg == null ? '—' : '${deg.toStringAsFixed(digits)}°';

/// "in 2 h 14 min", "12 min ago"
String formatRelative(DateTime target, DateTime now) {
  final d = target.difference(now);
  final mins = d.inMinutes.abs();
  final text = mins < 60 ? '$mins min' : '${mins ~/ 60} h ${mins % 60} min';
  return d.isNegative ? '$text ago' : 'in $text';
}

String formatMag(double? mag) => mag == null ? '—' : mag.toStringAsFixed(1);
