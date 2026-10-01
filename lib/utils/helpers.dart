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

/// 1234.5 -> £1,234.50
String formatMoney(num value) {
  final neg = value < 0;
  final parts = value.abs().toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  return '${neg ? '-' : ''}$kCurrency$whole.${parts[1]}';
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
  final l = date.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final m = l.minute.toString().padLeft(2, '0');
  final ap = l.hour >= 12 ? 'PM' : 'AM';
  return '${formatShortDate(l)} · $h:$m $ap';
}
