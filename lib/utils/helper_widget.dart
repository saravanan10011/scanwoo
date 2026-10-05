import 'package:quick_scanner/services/models/scan_record.dart';
import 'package:quick_scanner/utils/helpers.dart';

String recordTitle(ScanRecord record) {
  final s = (record.supplier ?? '').trim();
  if (s.isNotEmpty) return s;
  final n = (record.invoiceNo ?? '').trim();
  if (n.isNotEmpty) return n;
  return 'Invoice';
}

/// null / empty / '—' / '-' -> 'N/A'
String recordText(String? v) {
  final t = (v ?? '').trim();
  return (t.isEmpty || t == '—' || t == '-') ? 'N/A' : t;
}

/// Invoice date from the invoice itself; falls back to the upload date.
String recordDate(ScanRecord r) {
  final d = (r.date ?? '').trim();
  return d.isNotEmpty ? d : formatShortDate(r.createdAt.toLocal());
}
