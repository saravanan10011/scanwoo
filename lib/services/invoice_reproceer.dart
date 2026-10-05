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

  static num _num(dynamic v) {
    return v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);
  }

  static double _round2(num v) => double.parse(v.toStringAsFixed(2));

  // ===========================================================================
  // COMMON HELPERS
  // ===========================================================================

  static bool _blank(dynamic v) {
    final s = '${v ?? ''}'.trim();

    return s.isEmpty ||
        s == '—' ||
        s == '-' ||
        s.toLowerCase() == 'null' ||
        s.toUpperCase() == 'N/A';
  }

  static bool needsReprocess(Map<String, dynamic> inv) {
    return _num(inv['gross']) == 0 ||
        _num(inv['net']) == 0 ||
        _badSupplier(inv['supplier']) ||
        _blank(inv['invoice_no']) ||
        _blank(inv['vat_number']) ||
        _blank(inv['branch']) ||
        _blank(inv['date']);
  }

  static String? rawTextOf(Map<String, dynamic> inv) {
    String? pick(dynamic v) {
      return v is String && v.trim().isNotEmpty ? v : null;
    }

    // fields.raw_text
    final fields = inv['fields'];

    if (fields is Map) {
      final text = pick(fields['raw_text']);

      if (text != null) {
        return text;
      }
    }

    // images[0].extracted_data.raw_text
    final images = inv['images'];

    if (images is List && images.isNotEmpty && images.first is Map) {
      final data = (images.first as Map)['extracted_data'];

      if (data is Map) {
        return pick(data['raw_text']);
      }
    }

    return null;
  }

  static bool _missing(String key, dynamic value) {
    if (key == 'supplier') {
      return _badSupplier(value);
    }

    if (_moneyKeys.contains(key)) {
      return _num(value) == 0;
    }

    return _blank(value);
  }

  // ===========================================================================
  // MONEY HELPERS
  // ===========================================================================

  /// Lines that should never be interpreted as invoice totals.
  static final RegExp _notMoney = RegExp(
    r'loyalty|points?|redeem|'
    r'\bqty\b|quantity|'
    r'\bmrp\b|you\s*saved|'
    r'\bph\b|gstin|fssai|fsn|'
    r'pan\s*no|confirmation',
    caseSensitive: false,
  );

  /// "Total Amount" lines that are NOT the final payable total:
  ///
  /// Total Amount before Tax : 74.00
  /// Total Amount : GST: 13.32
  /// Total Amount excl. tax
  static const String _notFinalTotal = r'(?!\s+before\b|\s*:\s*gst\b|\s+excl)';

  static String _withoutLoyalty(String raw) {
    return raw
        .split('\n')
        .where(
          (line) =>
              !RegExp(
                r'loyalty|redeem|points?\b',
                caseSensitive: false,
              ).hasMatch(line),
        )
        .join('\n');
  }

  static String _moneyLines(String raw) {
    return raw
        .split('\n')
        .where((line) => !_notMoney.hasMatch(line))
        .join('\n');
  }

  // ===========================================================================
  // PARSE MONEY
  // ===========================================================================

  /// Supports:
  ///
  /// £17.20
  /// $17.20
  /// €17.20
  /// ₹456.88
  /// Rs.456.88
  /// Rs 456.88
  /// INR 456.88
  /// 17.20
  /// 1,200
  static double? _parseMoney(String text, {bool allowPlainNumber = false}) {
    final value = text.trim();

    if (value.isEmpty) {
      return null;
    }

    // -------------------------------------------------------------------------
    // Currency amount
    // -------------------------------------------------------------------------

    final currencyRegex = RegExp(
      r'(?:£|\$|€|₹|Rs\.?|INR)\s*'
      r'([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );

    final currencyMatch = currencyRegex.firstMatch(value);

    if (currencyMatch != null) {
      final number = double.tryParse(
        currencyMatch.group(1)!.replaceAll(',', ''),
      );

      if (number != null && number > 0) {
        return number;
      }
    }

    // -------------------------------------------------------------------------
    // Plain amount
    // -------------------------------------------------------------------------

    if (!allowPlainNumber) {
      return null;
    }

    // The complete line must basically be a number.
    //
    // This prevents:
    //
    // 999799
    // PAN123456
    // GSTIN123456
    // Invoice 26475692
    //
    // from being selected accidentally.
    final plainRegex = RegExp(
      r'^[^\d]*'
      r'([\d,]+(?:\.\d{1,2})?)'
      r'[^\d]*$',
    );

    final plainMatch = plainRegex.firstMatch(value);

    if (plainMatch != null) {
      final number = double.tryParse(plainMatch.group(1)!.replaceAll(',', ''));

      if (number != null && number > 0) {
        return number;
      }
    }

    return null;
  }

  // ===========================================================================
  // AMOUNT AFTER LABEL
  // ===========================================================================

  /// Finds an amount after a trusted label.
  ///
  /// Examples:
  ///
  /// Total | £79.13
  ///
  /// Amount Paid | Rs.456.88
  ///
  /// Total
  /// 17.20
  ///
  /// Subtotal | 1,200
  static double? _amountAfter(
    String raw,
    String label, {
    bool allowPlainNextLine = true,
  }) {
    final lines =
        raw
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    final labelRegex = RegExp(r'^\s*' + label + r'\b', caseSensitive: false);

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (!labelRegex.hasMatch(line)) {
        continue;
      }

      // -----------------------------------------------------------------------
      // Same line
      // -----------------------------------------------------------------------

      final remaining = line.replaceFirst(labelRegex, '').trim();

      final sameLine = _parseMoney(remaining, allowPlainNumber: true);

      if (sameLine != null) {
        return sameLine;
      }

      // -----------------------------------------------------------------------
      // Next line
      // -----------------------------------------------------------------------

      if (i + 1 < lines.length) {
        final nextLine = lines[i + 1].trim();

        final next = _parseMoney(
          nextLine,
          allowPlainNumber: allowPlainNextLine,
        );

        if (next != null) {
          return next;
        }
      }
    }

    return null;
  }

  // ===========================================================================
  // AMOUNT BEFORE LABEL
  // ===========================================================================

  /// Handles OCR where the amount appears BEFORE the total label.
  ///
  /// Example:
  ///
  /// National | 0:12:20
  /// 17.20
  /// Total
  ///
  /// Returns:
  ///
  /// 17.20
  static double? _amountBefore(
    String raw,
    String label, {
    int maxLookBack = 2,
  }) {
    final lines =
        raw
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    final labelRegex = RegExp(r'^\s*' + label + r'\b', caseSensitive: false);

    for (var i = 0; i < lines.length; i++) {
      if (!labelRegex.hasMatch(lines[i])) {
        continue;
      }

      // Look back only a few lines.
      //
      // This prevents an invoice number or account number
      // much earlier in the OCR from being selected.
      for (var j = 1; j <= maxLookBack; j++) {
        final index = i - j;

        if (index < 0) {
          break;
        }

        final previousLine = lines[index];

        final amount = _parseMoney(previousLine, allowPlainNumber: true);

        if (amount != null && amount > 0) {
          return amount;
        }

        // If we hit another labelled line,
        // stop looking further backwards.
        if (RegExp(
          r'[A-Za-z]{2,}\s*(?:[:|]|$)',
          caseSensitive: false,
        ).hasMatch(previousLine)) {
          break;
        }
      }
    }

    return null;
  }

  // ===========================================================================
  // TOTAL EXTRACTION
  // ===========================================================================

  static double? _totalFromText(String rawText) {
    final raw = _moneyLines(rawText);

    // -------------------------------------------------------------------------
    // 1. AMOUNT PAID
    // -------------------------------------------------------------------------

    final amountPaid = _amountAfter(raw, r'amount\s*paid');

    if (amountPaid != null) {
      return amountPaid;
    }

    // -------------------------------------------------------------------------
    // 2. AMOUNT DUE
    // -------------------------------------------------------------------------

    final amountDue = _amountAfter(raw, r'amount\s*due');

    if (amountDue != null) {
      return amountDue;
    }

    // -------------------------------------------------------------------------
    // 3. GRAND TOTAL
    // -------------------------------------------------------------------------

    final grandTotal = _amountAfter(raw, r'grand\s*total');

    if (grandTotal != null) {
      return grandTotal;
    }

    // -------------------------------------------------------------------------
    // 4. TOTAL CHARGES FOR THIS BILL
    // -------------------------------------------------------------------------

    final totalCharges = _amountAfter(
      raw,
      r'total\s+charges?\s+for\s+this\s+bill',
    );

    if (totalCharges != null) {
      return totalCharges;
    }

    // -------------------------------------------------------------------------
    // 5. TOTAL AMOUNT AFTER TAX / PAYABLE
    //
    // Must be checked BEFORE the generic "total amount", otherwise
    // "Total Amount before Tax | 74.00" is picked instead of
    // "Total Amount after Tax | 87.32".
    // -------------------------------------------------------------------------

    final totalAfterTax = _amountAfter(
      raw,
      r'(?:total\s+amount\s+after\s+tax|'
      r'total\s+(?:amount\s+)?payable|'
      r'net\s+payable|'
      r'invoice\s+total)',
    );

    if (totalAfterTax != null) {
      return totalAfterTax;
    }

    // -------------------------------------------------------------------------
    // 5b. TOTAL AMOUNT (excluding "before tax" and "GST" lines)
    // -------------------------------------------------------------------------

    final totalAmount = _amountAfter(raw, r'total\s+amount' + _notFinalTotal);

    if (totalAmount != null) {
      return totalAmount;
    }

    // -------------------------------------------------------------------------
    // 6. GENERIC TOTAL - amount after label
    // -------------------------------------------------------------------------

    final totalAfter = _amountAfter(
      raw,
      r'total(?!\s+amount\s+before\b|\s+amount\s*:\s*gst\b)',
    );

    if (totalAfter != null) {
      return totalAfter;
    }

    // -------------------------------------------------------------------------
    // 7. GENERIC TOTAL - amount before label
    // -------------------------------------------------------------------------
    //
    // Handles:
    //
    // National | 0:12:20
    // 17.20
    // Total
    //
    // Correct = 17.20
    // -------------------------------------------------------------------------

    final totalBefore = _amountBefore(
      raw,
      r'total(?!\s+amount\s+before\b|\s+amount\s*:\s*gst\b)',
      maxLookBack: 2,
    );

    if (totalBefore != null) {
      return totalBefore;
    }

    // -------------------------------------------------------------------------
    // 8. SUBTOTAL - DISCOUNT
    // -------------------------------------------------------------------------

    final subTotal = _amountAfter(raw, r'sub\s*total');

    if (subTotal != null && subTotal > 0) {
      final discount = _amountAfter(raw, r'discount') ?? 0;

      final calculated = subTotal - discount;

      if (calculated > 0) {
        return calculated;
      }
    }

    return null;
  }

  // ===========================================================================
  // CURRENCY
  // ===========================================================================

  static String _currencyOf(String raw) {
    final detected = InvoiceExtractionService.detectCurrency(raw);

    if (detected != null && detected.trim().isNotEmpty) {
      return detected;
    }

    // Indian invoice detection.
    if (RegExp(
      r'gstin|cgst|sgst|igst|\bgst\b|₹|'
      r'\brs\.?\s*[\d,]+|'
      r'\binr\b',
      caseSensitive: false,
    ).hasMatch(raw)) {
      return '₹';
    }

    // Default application currency.
    return '£';
  }

  // ===========================================================================
  // PAYMENT
  // ===========================================================================

  static String? _paymentFromAmounts(String raw) {
    final cash = _amountAfter(raw, r'cash\s*amount') ?? 0;

    final card = _amountAfter(raw, r'card\s*am\w*') ?? 0;

    final upi = _amountAfter(raw, r'upi') ?? 0;

    if (cash == 0 && card == 0 && upi == 0) {
      return null;
    }

    // UPI/wallet is represented as Card
    // because the app currently supports
    // Cash / Card only.
    if (card + upi > cash) {
      return 'Card';
    }

    if (cash > 0) {
      return 'Cash';
    }

    return null;
  }

  // ===========================================================================
  // SUPPLIER
  // ===========================================================================

  static bool _badSupplier(dynamic value) {
    final s = '${value ?? ''}'.trim();

    return _blank(s) ||
        s.length < 4 ||
        !RegExp(r'[A-Za-z]{3,}').hasMatch(s) ||
        RegExp(
          r'^(tax\s*)?'
          r'(invoice|receipt|statement|bill\s*to|date)\b',
          caseSensitive: false,
        ).hasMatch(s);
  }

  // ===========================================================================
  // MAIN REPROCESS
  // ===========================================================================

  static Map<String, dynamic> reprocess(Map<String, dynamic> inv) {
    var raw = rawTextOf(inv);

    if (raw == null) {
      return inv;
    }

    // -------------------------------------------------------------------------
    // Convert literal "\n" to real line breaks.
    // -------------------------------------------------------------------------

    if (!raw.contains('\n') && raw.contains(r'\n')) {
      raw = raw.replaceAll(r'\n', '\n');
    }

    final out = Map<String, dynamic>.from(inv);

    // -------------------------------------------------------------------------
    // Currency
    // -------------------------------------------------------------------------

    out['currency'] = _currencyOf(raw);

    // -------------------------------------------------------------------------
    // IMPORTANT:
    // Always check explicit OCR total BEFORE trusting backend/extractor money.
    //
    // Otherwise:
    //
    // extractor gross = 756
    //
    // while OCR says:
    //
    // 17.20
    // Total
    //
    // and the wrong 756 would remain.
    // -------------------------------------------------------------------------

    final explicitTotal = _totalFromText(raw);

    // -------------------------------------------------------------------------
    // If backend result is complete AND we don't have a better explicit
    // total, keep backend values.
    // -------------------------------------------------------------------------

    if (!needsReprocess(inv) && explicitTotal == null) {
      return out;
    }

    // -------------------------------------------------------------------------
    // Remove loyalty / points lines before extraction.
    // -------------------------------------------------------------------------

    final cleanedRaw = _withoutLoyalty(raw);

    final extracted = InvoiceExtractionService.extract(cleanedRaw);

    // -------------------------------------------------------------------------
    // Backend money trust
    // -------------------------------------------------------------------------

    final trustBackendMoney = _num(inv['net']) > 0 && _num(inv['gross']) > 0;

    if (!trustBackendMoney) {
      for (final key in _moneyKeys) {
        out[key] = 0;
      }
    }

    // -------------------------------------------------------------------------
    // Extract missing fields
    // -------------------------------------------------------------------------

    for (final key in _fields) {
      final isMoney = _moneyKeys.contains(key);

      if (trustBackendMoney && isMoney) {
        continue;
      }

      final value = extracted[key];

      if (value == null) {
        continue;
      }

      if (value is num && value == 0) {
        continue;
      }

      if (isMoney && value is num && value < 0) {
        continue;
      }

      if (value is String && value.trim().isEmpty) {
        continue;
      }

      final current = (isMoney && !trustBackendMoney) ? 0 : inv[key];

      if (!_missing(key, current)) {
        continue;
      }

      // -----------------------------------------------------------------------
      // Payment normalization
      // -----------------------------------------------------------------------

      if (key == 'payment' && value is String) {
        final payment = value.toLowerCase();

        if (payment.contains('cash')) {
          out[key] = 'Cash';
        } else if (payment.contains('card') ||
            payment.contains('upi') ||
            payment.contains('wallet')) {
          out[key] = 'Card';
        }

        continue;
      }

      out[key] = value;
    }

    // =========================================================================
    // GROSS CALCULATION
    // =========================================================================

    // -------------------------------------------------------------------------
    // EXPLICIT OCR TOTAL HAS HIGHEST PRIORITY.
    //
    // This fixes:
    //
    // OCR:
    //
    // 17.20
    // Total
    //
    // Extractor:
    //
    // gross = 756
    //
    // Final:
    //
    // gross = 17.20
    // -------------------------------------------------------------------------

    if (explicitTotal != null && explicitTotal > 0) {
      out['gross'] = explicitTotal;

      // If net is missing, or the extractor produced a value larger
      // than the actual total, use the explicit total.
      if (_num(out['net']) == 0 || _num(out['net']) > explicitTotal) {
        out['net'] = explicitTotal;
      }
    }
    // -------------------------------------------------------------------------
    // If there is no explicit total, use net + VAT.
    // -------------------------------------------------------------------------
    else if (_num(out['gross']) == 0 && _num(out['net']) > 0) {
      out['gross'] = _num(out['net']) + _num(out['vat']);
    }

    // =========================================================================
    // DISCOUNT CORRECTION
    // =========================================================================

    if (!trustBackendMoney &&
        _num(out['gross']) > 0 &&
        _num(out['net']) > _num(out['gross']) &&
        _num(out['vat']) == 0) {
      out['net'] = out['gross'];
    }

    // =========================================================================
    // NET / VAT BREAKDOWN
    // =========================================================================
    //
    // Example:
    //
    // Total Amount before Tax : 74.00
    // Total Amount : GST      : 13.32
    // Total Amount after Tax  : 87.32
    //
    // net = 74.00, vat = 13.32, gross = 87.32
    // -------------------------------------------------------------------------

    final gross = _num(out['gross']);

    if (gross > 0 && _num(out['vat']) == 0) {
      final beforeTax = _amountAfter(raw, r'total\s+amount\s+before\s+tax');

      final gstAmount = _amountAfter(raw, r'total\s+amount\s*:\s*gst');

      if (beforeTax != null && beforeTax < gross) {
        out['net'] = beforeTax;
        out['vat'] = gstAmount ?? _round2(gross - beforeTax);
      } else if (gstAmount != null && gstAmount < gross) {
        out['vat'] = gstAmount;
        out['net'] = _round2(gross - gstAmount);
      } else if (_num(out['net']) > 0 && _num(out['net']) < gross) {
        // Fallback: derive VAT from gross - net.
        out['vat'] = _round2(gross - _num(out['net']));
      }
    }

    // =========================================================================
    // PAYMENT CORRECTION
    // =========================================================================

    final payment = _paymentFromAmounts(raw);

    if (payment != null) {
      out['payment'] = payment;
    }

    return out;
  }
}
