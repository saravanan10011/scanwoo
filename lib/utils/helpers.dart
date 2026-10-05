import 'package:intl/intl.dart';
import '../services/models/scan_record.dart';

String formatShortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day.toString().padLeft(2, '0')} '
      '${months[date.month - 1]} ${date.year}';
}

DateTime _lastSundayUtc(int year, int month, int hour) {
  final last = DateTime.utc(year, month + 1, 0);
  final back = last.weekday % 7;
  return DateTime.utc(year, month, last.day - back, hour);
}

bool _isUkSummerTime(DateTime utc) {
  final start = _lastSundayUtc(utc.year, 3, 1);
  final end = _lastSundayUtc(utc.year, 10, 1);
  return !utc.isBefore(start) && utc.isBefore(end);
}

DateTime toUkTime(DateTime date) {
  final utc = date.toUtc();
  return utc.add(Duration(hours: _isUkSummerTime(utc) ? 1 : 0));
}

String formatDateTime(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final h = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '$d/$m/${date.year} $h:$min';
}

String formatDateSlash(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String recordTitle(ScanRecord record) {
  if (record.text.isEmpty) return 'Untitled';
  final line = record.text.split('\n').first;
  return line.length > 30 ? '${line.substring(0, 30)}...' : line;
}

String invoiceCode(int index) {
  return 'INV-${index + 1000}';
}

const String kCurrency = '\u00A3';

String formatMoney(num value, {String symbol = '£'}) {
  final locale = symbol == '₹' ? 'en_IN' : 'en_GB';
  return '$symbol${NumberFormat('#,##0.00', locale).format(value)}';
}

/// formatMoney for the built-in PDF font (Helvetica has no ₹ glyph).
String formatMoneyPdf(num value, {String symbol = kCurrency}) {
  final s = symbol == '₹' ? 'Rs. ' : symbol;
  return formatMoney(value, symbol: s);
}

DateTime parseServerTime(dynamic raw) {
  final str = (raw ?? '').toString().trim();
  if (str.isEmpty) return DateTime.now();
  var iso =
      str.contains(' ') && !str.contains('T')
          ? str.replaceFirst(' ', 'T')
          : str;
  final hasZone =
      iso.endsWith('Z') ||
      RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(iso.split('T').last);
  if (!hasZone) iso = '${iso}Z';
  return (DateTime.tryParse(iso) ?? DateTime.now()).toLocal();
}

/// 01 Oct 2026 · 3:45 PM  (local time)
String formatUploaded(DateTime date) {
  // final l = date.toLocal();
  final l = toUkTime(date); // was: date.toLocal()

  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final m = l.minute.toString().padLeft(2, '0');
  final ap = l.hour >= 12 ? 'PM' : 'AM';
  return '${formatShortDate(l)} · $h:$m $ap';
}
