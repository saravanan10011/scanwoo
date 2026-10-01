import 'invoice_exterst.dart';

class InvoiceReprocessor {
  static const _fields = [
    'supplier',
    'vat_number',
    'invoice_no',
    'branch',
    'date',
    'net',
    'vat',
    'gross',
    'payment',
  ];

  static num _num(dynamic v) =>
      v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

  static bool _blank(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s.isEmpty || s == '—' || s == '-' || s == 'null';
  }

  /// True when the backend result looks unusable.
  static bool needsReprocess(Map<String, dynamic> inv) =>
      _num(inv['gross']) == 0 ||
      _blank(inv['invoice_no']) ||
      _blank(inv['vat_number']) ||
      _blank(inv['branch']) ||
      inv['date'] == null;

  /// raw_text from `fields.raw_text`, or from the first image's extracted_data.
  static String? rawTextOf(Map<String, dynamic> inv) {
    String? pick(dynamic v) => v is String && v.trim().isNotEmpty ? v : null;

    final fields = inv['fields'];
    if (fields is Map) {
      final t = pick(fields['raw_text']);
      if (t != null) return t;
    }
    final images = inv['images'];
    if (images is List && images.isNotEmpty && images.first is Map) {
      final data = (images.first as Map)['extracted_data'];
      if (data is Map) return pick(data['raw_text']);
    }
    return null;
  }

  /// Returns a copy of [inv] with the extracted values filled in.
  /// id, status, images, uploaded_at, fields etc. are left untouched.
  static Map<String, dynamic> reprocess(Map<String, dynamic> inv) {
    if (!needsReprocess(inv)) return inv;

    var raw = rawTextOf(inv);
    if (raw == null) return inv;

    // Text that still has literal "\n" instead of real line breaks.
    if (!raw.contains('\n') && raw.contains(r'\n')) {
      raw = raw.replaceAll(r'\n', '\n');
    }

    final extracted = InvoiceExtractionService.extract(raw);
    final out = Map<String, dynamic>.from(inv);

    for (final key in _fields) {
      final v = extracted[key];
      if (v == null) continue;
      if (v is num && v == 0) {
        continue; // keep backend value if we found nothing
      }
      if (v is String && v.trim().isEmpty) continue;
      if (key == 'payment' && v is String) {
        final p = v.toLowerCase();
        if (p.contains('cash')) {
          out[key] = 'Cash';
        } else if (p.contains('card')) {
          out[key] = 'Card';
        }
        continue; // the app only knows Cash / Card
      }
      out[key] = v;
    }
    return out;
  }
}
