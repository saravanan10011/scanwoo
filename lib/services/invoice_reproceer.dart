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

  static const _moneyKeys = ['net', 'vat', 'gross'];

  static num _num(dynamic v) =>
      v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

  /// Blank = empty, dash, "null" or "N/A" (the model turns empty values
  /// into 'N/A', so it must count as blank here).
  static bool _blank(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s.isEmpty ||
        s == '—' ||
        s == '-' ||
        s.toLowerCase() == 'null' ||
        s.toUpperCase() == 'N/A';
  }

  /// True when the backend result looks unusable.
  static bool needsReprocess(Map<String, dynamic> inv) =>
      _num(inv['gross']) == 0 ||
      _num(inv['net']) == 0 ||
      _badSupplier(inv['supplier']) ||
      _blank(inv['invoice_no']) ||
      _blank(inv['vat_number']) ||
      _blank(inv['branch']) ||
      _blank(inv['date']);

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

  static bool _missing(String key, dynamic v) {
    if (key == 'supplier') return _badSupplier(v);
    if (_moneyKeys.contains(key)) return _num(v) == 0;
    return _blank(v);
  }

  // ---------------------------------------------------------------------------
  // Money helpers
  // ---------------------------------------------------------------------------

  /// Lines that can never hold a money total (loyalty points, quantities ...).
  static final RegExp _notMoney = RegExp(
    r'loyalty|points?|redeem|\bqty\b|quantity|\bmrp\b|you\s*saved|ph\b|gstin|fssai|fsn',
    caseSensitive: false,
  );

  static String _withoutLoyalty(String raw) => raw
      .split('\n')
      .where(
        (l) =>
            !RegExp(
              r'loyalty|redeem|points?\b',
              caseSensitive: false,
            ).hasMatch(l),
      )
      .join('\n');

  static String _moneyLines(String raw) =>
      raw.split('\n').where((l) => !_notMoney.hasMatch(l)).join('\n');

  /// Last amount that follows [label] on the same line
  /// (e.g. "Subtotal | F1,062" -> 1062). [label] is a regex source.
  static double? _amountAfter(String raw, String label) {
    final re = RegExp(
      '(?<![a-z])$label\\s*[:\\-|]?\\s*[^\\d\\n]{0,4}([\\d,]+(?:\\.\\d{1,2})?)',
      caseSensitive: false,
    );
    double? found;
    for (final m in re.allMatches(raw)) {
      final v = double.tryParse(m.group(1)!.replaceAll(',', ''));
      if (v != null) found = v;
    }
    return found;
  }

  /// Last "Total" amount in the text (ignores "Subtotal" and non-money lines).
  /// Falls back to Subtotal - Discount when "Total" has no amount.
  static double? _totalFromText(String rawText) {
    final raw = _moneyLines(rawText);
    final re = RegExp(
      r'(?<![a-z])(?:grand\s*total|total|amount\s*due)\s*[:\-|]?\s*[^\d\n]{0,4}([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    double? found;
    for (final m in re.allMatches(raw)) {
      final v = double.tryParse(m.group(1)!.replaceAll(',', ''));
      if (v != null && v > 0) found = v;
    }
    if (found != null) return found;

    final sub = _amountAfter(raw, r'sub\s*total');
    if (sub != null && sub > 0) {
      final disc = _amountAfter(raw, r'discount') ?? 0;
      final t = sub - disc;
      if (t > 0) return t;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Currency / payment helpers
  // ---------------------------------------------------------------------------

  /// Extractor first; Indian GST bills with no symbol -> ₹; otherwise £.
  static String _currencyOf(String raw) {
    final detected = InvoiceExtractionService.detectCurrency(raw);
    if (detected != null && detected.trim().isNotEmpty) return detected;
    if (RegExp(
      r'gstin|cgst|sgst|igst|\bgst\b|\brs\.?\s*\d|₹|\binr\b',
      caseSensitive: false,
    ).hasMatch(raw)) {
      return '₹';
    }
    return '£';
  }

  /// Payment method from the amounts printed on the bill
  /// ("Cash Amount : 0.00 ... UPI | 60.00" -> Card).
  /// The app only knows Cash / Card, so UPI and wallets map to Card.
  static String? _paymentFromAmounts(String raw) {
    final cash = _amountAfter(raw, r'cash\s*amount') ?? 0;
    final card = _amountAfter(raw, r'card\s*am\w*') ?? 0;
    final upi = _amountAfter(raw, r'upi') ?? 0;
    if (cash == 0 && card == 0 && upi == 0) return null;
    if (card + upi > cash) return 'Card';
    if (cash > 0) return 'Cash';
    return null;
  }

  static bool _badSupplier(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return _blank(s) ||
        s.length < 4 ||
        !RegExp(r'[A-Za-z]{3,}').hasMatch(s) ||
        RegExp(
          r'^(tax\s*)?(invoice|receipt|statement|bill\s*to|date)\b',
          caseSensitive: false,
        ).hasMatch(s);
  }

  // ---------------------------------------------------------------------------
  // Main entry
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> reprocess(Map<String, dynamic> inv) {
    var raw = rawTextOf(inv);
    if (raw == null) return inv;

    // Text that still has literal "\n" instead of real line breaks.
    if (!raw.contains('\n') && raw.contains(r'\n')) {
      raw = raw.replaceAll(r'\n', '\n');
    }

    final out = Map<String, dynamic>.from(inv);

    // Currency is never sent by the backend, so always detect it from the text.
    out['currency'] = _currencyOf(raw);

    // Backend result is fine -> keep it, only the currency was added.
    if (!needsReprocess(inv)) return out;

    // FIX: drop loyalty / points lines first so "Total Loyalty Points : 81.49"
    // can never be read as the invoice total, whatever the extractor does.
    final extracted = InvoiceExtractionService.extract(_withoutLoyalty(raw));

    // FIX: backend money is trusted only when net AND gross are both present.
    // A result like net: 1, gross: 0 is a bad parse (it read the "1" of the
    // first line item), so all three money fields are recomputed from the text.
    final trustBackendMoney = _num(inv['net']) > 0 && _num(inv['gross']) > 0;
    if (!trustBackendMoney) {
      for (final k in _moneyKeys) {
        out[k] = 0;
      }
    }

    for (final key in _fields) {
      final isMoney = _moneyKeys.contains(key);
      if (trustBackendMoney && isMoney) continue;

      final v = extracted[key];
      if (v == null) continue;
      if (v is num && v == 0) continue;
      if (isMoney && v is num && v < 0) continue; // never a negative amount
      if (v is String && v.trim().isEmpty) continue;

      // Never overwrite a value the backend already gave us
      final current = (isMoney && !trustBackendMoney) ? 0 : inv[key];
      if (!_missing(key, current)) continue;

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

    // Gross still missing -> net + vat, then a "Total" line in the text.
    if (_num(out['gross']) == 0 && _num(out['net']) > 0) {
      out['gross'] = _num(out['net']) + _num(out['vat']);
    }
    if (_num(out['gross']) == 0) {
      final t = _totalFromText(raw);
      if (t != null) {
        out['gross'] = t;
        if (_num(out['net']) == 0) out['net'] = t;
      }
    }

    // Subtotal 1,200 - Discount 900 = Total 300: net can't exceed gross when
    // there is no VAT, so net was the pre-discount subtotal.
    if (!trustBackendMoney &&
        _num(out['gross']) > 0 &&
        _num(out['net']) > _num(out['gross']) &&
        _num(out['vat']) == 0) {
      out['net'] = out['gross'];
    }

    // Payment: trust the printed amounts over a default "Cash" from the backend.
    final pay = _paymentFromAmounts(raw);
    if (pay != null) out['payment'] = pay;

    return out;
  }
}
