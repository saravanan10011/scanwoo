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

  /// "50,00" -> 50.0 (OCR printed a comma instead of a dot)
  /// "1,200" -> 1200.0   "12,34,567" -> 1234567.0
  static double? _toDouble(String s) {
    var t = s.trim();

    if (RegExp(r'^\d+,\d{1,2}$').hasMatch(t)) {
      t = t.replaceAll(',', '.');
    } else {
      t = t.replaceAll(',', '');
    }

    return double.tryParse(t);
  }

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
    final parts = <String>[];

    void add(dynamic v) {
      if (v is String && v.trim().isNotEmpty) {
        parts.add(v);
      }
    }

    // fields.raw_text
    final fields = inv['fields'];

    if (fields is Map) {
      add(fields['raw_text']);
    }

    // images[*].extracted_data.raw_text
    final images = inv['images'];

    if (images is List) {
      for (final img in images) {
        if (img is Map) {
          final data = img['extracted_data'];

          if (data is Map) {
            add(data['raw_text']);
          }
        }
      }
    }

    return parts.isEmpty ? null : parts.join('\n');
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

  /// Loyalty / reward lines, tolerant of OCR damage:
  /// "Loyaliy", "Poinits", "Redeemed", "Rewards" ...
  /// \b on the left so "Employee" / "Appointment" lines are not dropped.
  static const String _loyaltyRx =
      r'\bloy\w*|\bpoin\w*|\bredeem\w*|\breward\w*';

  static final RegExp _loyaltyLine = RegExp(_loyaltyRx, caseSensitive: false);

  /// Lines that should never be interpreted as invoice totals.
  static final RegExp _notMoney = RegExp(
    // ignore: prefer_interpolation_to_compose_strings
    _loyaltyRx +
        r'|'
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

  /// A bare "Total" label. These are NOT the amount payable:
  ///
  /// Total VAT | 4 May 2025          (VAT amount, e.g. £8.59)
  /// Total excluding VAT | ...       (net)
  /// Total for items where VAT ...   (net)
  /// Total Amount before Tax : 74.00
  static const String _genericTotal =
      r'total(?!\s+amount\s+before\b|\s+amount\s*:\s*gst\b|'
      r'\s+(?:vat|v\.a\.t|gst|tax|excl|exc|excluding|ex|before|for|items?|'
      r'qty|quantity|discount|savings?)\b)';

  static String _withoutLoyalty(String raw) {
    return raw
        .split('\n')
        .where((line) => !_loyaltyLine.hasMatch(line))
        .join('\n');
  }

  static String _moneyLines(String raw) {
    return raw
        .split('\n')
        .where((line) => !_notMoney.hasMatch(line))
        .join('\n');
  }

  static List<String> _cleanLines(String raw) {
    return raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// NEW: OCR prints "3.292.62" (dots as thousands separator) -> "3,292.62".
  static String _fixThousandDots(String raw) {
    return raw.replaceAllMapped(
      RegExp(r'(?<![\d.,])(\d{1,3})\.(\d{3})\.(\d{2})(?!\d)'),
      (m) => '${m[1]},${m[2]}.${m[3]}',
    );
  }

  // ===========================================================================
  // PARSE MONEY (whole remaining text must be an amount)
  // ===========================================================================

  /// Supports:
  ///
  /// £17.20   $17.20   €17.20   ₹456.88
  /// Rs.456.88   Rs.50,00 (OCR comma decimal)   Rs 456.88   INR 456.88
  /// 17.20   1,200   12,34,567
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
      final number = _toDouble(currencyMatch.group(1)!);

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
      final number = _toDouble(plainMatch.group(1)!);

      if (number != null && number > 0) {
        return number;
      }
    }

    return null;
  }

  // ===========================================================================
  // ALL MONEY VALUES IN A STRING (currency symbol OR exactly 2 decimals)
  // ===========================================================================

  static List<double> _moneyIn(String s) {
    final t = s
        .replaceAll(RegExp(r'\d+(?:[.,]\d+)?\s*%'), ' ') // rates
        .replaceAll(
          RegExp(r'\b\d{1,2}[.:]\d{2}\s*(?:AM|PM)\b', caseSensitive: false),
          ' ',
        ); // times

    final rx = RegExp(
      r'(?<![A-Za-z])(?:£|\$|€|₹|Rs\.?|INR)\s*(\d[\d,]*(?:[.,]\d{1,2})?)'
      r'|(?<![\d.,])(\d{1,3}(?:,\d{3})*|\d+)[.,](\d{2})(?!\d)',
      caseSensitive: false,
    );

    final out = <double>[];

    for (final m in rx.allMatches(t)) {
      double? v;

      if (m.group(1) != null) {
        v = _toDouble(m.group(1)!);
      } else {
        v = double.tryParse('${m.group(2)!.replaceAll(',', '')}.${m.group(3)}');
      }

      if (v != null && v > 0) {
        out.add(v);
      }
    }

    return out;
  }

  /// Last money value on the first line that contains [label]
  /// (or on the next line if the value is printed below).
  ///
  /// Works for lines like:
  ///   CGST 2.5% | 4.02
  ///   VAT | £84.30
  ///   Received By Cash | 50.00
  static double? _lineAmount(String raw, String label, {String? skip}) {
    final lines = _cleanLines(raw);

    final rx = RegExp('(?<![A-Za-z])$label(?![A-Za-z])', caseSensitive: false);

    final skipRx = RegExp(
      skip ?? r'\b(reg|registration|number|no)\b|gstin|summary|rate\b',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      final m = rx.firstMatch(line);

      if (m == null || skipRx.hasMatch(line)) {
        continue;
      }

      var amounts = _moneyIn(line.substring(m.end));

      if (amounts.isEmpty && i + 1 < lines.length) {
        final next = lines[i + 1];

        if (!RegExp(r'[A-Za-z]{2,}').hasMatch(next)) {
          amounts = _moneyIn(next);
        }
      }

      if (amounts.isNotEmpty) {
        return amounts.last;
      }
    }

    return null;
  }

  // ===========================================================================
  // AMOUNT AFTER LABEL (label must START the line)
  // ===========================================================================

  /// Finds an amount after a trusted label.
  ///
  /// Total | £79.13
  /// Amount Paid | Rs.456.88
  /// Total
  /// 17.20
  ///
  /// [amountOnly] = true: the text after the label on the same line must
  /// contain no words. This stops lines such as
  /// "Total Loyaliy Poinits : | 81.49" being read as a total even when OCR
  /// damaged the words so no keyword filter can recognise them.
  static double? _amountAfter(
    String raw,
    String label, {
    bool allowPlainNextLine = true,
    bool useNextLine = true,
    bool amountOnly = false,
  }) {
    final lines = _cleanLines(raw);

    final labelRegex = RegExp(r'^\s*' + label + r'\b', caseSensitive: false);

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (!labelRegex.hasMatch(line)) {
        continue;
      }

      // Same line
      final remaining = line.replaceFirst(labelRegex, '').trim();

      // "Total Loyaliy Poinits : 81.49" -> words after the label: not a total.
      // (Currency words such as Rs / INR / GBP are allowed.)
      if (amountOnly) {
        final words = remaining.replaceAll(
          RegExp(r'\b(?:Rs|INR|GBP|USD|EUR)\b\.?', caseSensitive: false),
          '',
        );

        if (RegExp(r'[A-Za-z]{3,}').hasMatch(words)) {
          continue;
        }
      }

      final sameLine = _parseMoney(remaining, allowPlainNumber: true);

      if (sameLine != null) {
        return sameLine;
      }

      // Next line
      if (useNextLine && i + 1 < lines.length) {
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
  // NEW: EVERY amount printed after a label (multi-page / multi-photo text
  // repeats the same label several times, each page can be read differently)
  // ===========================================================================

  static List<double> _allAfter(String raw, String label) {
    final labelRegex = RegExp(r'^\s*' + label + r'\b', caseSensitive: false);

    final out = <double>[];

    for (final line in _cleanLines(raw)) {
      final m = labelRegex.firstMatch(line);

      if (m == null) {
        continue;
      }

      final rest = line.substring(m.end);

      // "Total Invoice | 3,292.62" is fine, "Total Loyalty Points 81.49" is not.
      if (RegExp(r'[A-Za-z]{3,}').hasMatch(rest)) {
        continue;
      }

      var v = _parseMoney(rest, allowPlainNumber: true);

      // OCR lost the decimal point: "2,836 21" -> 2836.21
      if (v == null) {
        final sp = RegExp(
          r'^[^\d]*(\d[\d,]*)\s(\d{2})[^\d]*$',
        ).firstMatch(rest);

        if (sp != null) {
          v = double.tryParse(
            '${sp.group(1)!.replaceAll(',', '')}.${sp.group(2)}',
          );
        }
      }

      if (v != null && v > 0) {
        out.add(v);
      }
    }

    return out;
  }

  // Tolerates OCR damage: Total / Tatal, Invoice / Involce / "volce",
  // Goods / Goeds.
  static const String _totalInvoiceRx = r't[oa]tal\s+(?:inv\w*|vo\w*ce)';
  static const String _totalGoodsRx = r't[oa]tal\s+go\w+';
  static const String _totalVatRx = r't[oa]tal\s+vat';

  /// "Total Invoice" of a (multi page) wholesale invoice.
  ///
  /// OCR may read the same total differently on each photo
  /// (3.292.62 / 3,292.82). The candidate that equals
  /// Total Goods + Total VAT wins, otherwise the most frequent candidate.
  static double? _invoiceTotal(String raw) {
    final totals = _allAfter(raw, _totalInvoiceRx);

    final goods = _allAfter(raw, _totalGoodsRx);
    final vats = _allAfter(raw, _totalVatRx);

    if (totals.isNotEmpty) {
      for (final t in totals) {
        for (final g in goods) {
          for (final v in vats) {
            if ((g + v - t).abs() <= 0.02) {
              return t;
            }
          }
        }
      }

      final counts = <double, int>{};

      for (final t in totals) {
        counts[t] = (counts[t] ?? 0) + 1;
      }

      return counts.keys.reduce((a, b) => counts[b]! > counts[a]! ? b : a);
    }

    // No "Total Invoice" line, but goods + VAT are readable.
    if (goods.isNotEmpty && vats.isNotEmpty) {
      return _round2(goods.first + vats.first);
    }

    return null;
  }

  /// Net (Total Goods) and VAT (Total VAT) that add up to [gross].
  static List<double>? _goodsVat(String raw, double gross) {
    if (gross <= 0) {
      return null;
    }

    final goods = _allAfter(raw, _totalGoodsRx);
    final vats = _allAfter(raw, _totalVatRx);

    for (final g in goods) {
      for (final v in vats) {
        if ((g + v - gross).abs() <= 0.02) {
          return [g, v];
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
  /// National | 0:12:20
  /// 17.20
  /// Total
  static double? _amountBefore(
    String raw,
    String label, {
    int maxLookBack = 2,
  }) {
    final lines = _cleanLines(raw);

    final labelRegex = RegExp(r'^\s*' + label + r'\b', caseSensitive: false);

    for (var i = 0; i < lines.length; i++) {
      if (!labelRegex.hasMatch(lines[i])) {
        continue;
      }

      // Look back only a few lines so an account number much earlier in the
      // OCR is never selected.
      for (var j = 1; j <= maxLookBack; j++) {
        final index = i - j;

        if (index < 0) {
          break;
        }

        final previousLine = lines[index];

        // A line with words ("Discount | {1,061", "Net Amount | 68.00") is a
        // labelled line, not a bare amount printed above the Total: stop.
        final withoutCurrencyWords = previousLine.replaceAll(
          RegExp(r'\b(?:Rs|INR|GBP|USD|EUR)\b\.?', caseSensitive: false),
          '',
        );

        if (RegExp(r'[A-Za-z]{2,}').hasMatch(withoutCurrencyWords)) {
          break;
        }

        final amount = _parseMoney(previousLine, allowPlainNumber: true);

        if (amount != null && amount > 0) {
          return amount;
        }
      }
    }

    return null;
  }

  // ===========================================================================
  // TAX HELPERS
  // ===========================================================================

  /// CGST + SGST (+ IGST) for Indian bills, otherwise a VAT / GST / Tax line.
  static double? _taxTotal(String raw) {
    // "TAXABLE | GST% AMT SGST% ..." is a table header: never read the row
    // under it (the taxable value) as a tax amount.
    const headerSkip =
        r'taxab|\b(reg|registration|number|no)\b|gstin|summary|rate\b';

    final split =
        (_lineAmount(raw, 'cgst', skip: headerSkip) ?? 0) +
        (_lineAmount(raw, 'sgst', skip: headerSkip) ?? 0) +
        (_lineAmount(raw, 'igst', skip: headerSkip) ?? 0);

    if (split > 0) {
      return _round2(split);
    }

    return _lineAmount(
      raw,
      r'(?:vat|gst|tax)(?:\s*amount|\s*amt)?',
      skip:
          r'before|after|excl|incl|\bexc\b|\binc\b|total\s+amount|'
          r'\b(reg|registration|number|no)\b|gstin|summary|rate\b|invoice|date',
    );
  }

  /// Indian GST summary table:
  ///
  /// TAXABLE | GST% AMT SGST% / AMT CGST% / AMT
  /// 60.00   | 00 0.00 0.00 0.00 0.00
  /// 6.78    | 18 1.22 9.00 0.61 9.00 0.61
  ///
  /// Returns the sum of the taxable values (the net amount), or null.
  static double? _gstTableNet(String raw) {
    final lines = _cleanLines(raw);

    final header = RegExp(r'taxab', caseSensitive: false);
    final gst = RegExp(r'gst', caseSensitive: false);
    final row = RegExp(r'^\s*(\d[\d,]*\.\d{2})\b');

    for (var i = 0; i < lines.length; i++) {
      if (!header.hasMatch(lines[i]) || !gst.hasMatch(lines[i])) {
        continue;
      }

      var sum = 0.0;
      var rows = 0;

      for (var j = i + 1; j < lines.length; j++) {
        final m = row.firstMatch(lines[j]);

        if (m == null) {
          break;
        }

        final v = _toDouble(m.group(1)!);

        if (v == null) {
          break;
        }

        sum += v;
        rows++;
      }

      if (rows > 0) {
        return _round2(sum);
      }
    }

    return null;
  }

  // ===========================================================================
  // LAST RESORT TOTALS
  // ===========================================================================

  /// Payment line: "Received By Cash | 50.00", "UPI | 288.00".
  /// Skipped when the bill shows change / tendered amounts
  /// (cash given can be bigger than the bill).
  static double? _tenderAmount(String raw) {
    if (RegExp(
      r'\b(change|tendered|balance\s*return|return\s*amt)\b',
      caseSensitive: false,
    ).hasMatch(raw)) {
      return null;
    }

    return _lineAmount(
      raw,
      r'(?:cash|upi|card|gpay|google\s*pay|phonepe|paytm|visa|mastercard)'
      r'(?:\s*amount|\s*payment)?',
      skip: r'mode|method|card\s*no|account|gstin|\bno\b',
    );
  }

  /// Biggest amount that has an explicit currency symbol.
  static double? _largestSymbolAmount(String raw) {
    final rx = RegExp(
      r'(?<![A-Za-z])(?:£|\$|€|₹|Rs\.?)\s*(\d[\d,]*(?:[.,]\d{1,2})?)',
      caseSensitive: false,
    );

    double? best;

    for (final m in rx.allMatches(raw)) {
      final v = _toDouble(m.group(1)!);

      if (v != null && v > 0 && (best == null || v > best)) {
        best = v;
      }
    }

    return best;
  }

  /// Biggest amount with 2 decimals, ignoring balances / phone-like lines.
  static double? _largestDecimalAmount(String raw) {
    final skip = RegExp(
      r'previous|prev\.?\s*balance|outstanding|brought\s*forward|credit\s*limit|'
      r'gstin|fssai|\bph\b|phone|tel\b|mobile|account|sort\s*code|reg\s*no|'
      r'\bmrp\b|\brate\b|\bqty\b',
      caseSensitive: false,
    );

    double? best;

    for (final line in _cleanLines(raw)) {
      if (skip.hasMatch(line)) {
        continue;
      }

      for (final v in _moneyIn(line)) {
        if (best == null || v > best) {
          best = v;
        }
      }
    }

    return best;
  }

  // ===========================================================================
  // TOTAL EXTRACTION
  //
  // Tried in this order; the first one that returns an amount wins:
  //   0.  "Total Invoice" / Total Goods + Total VAT (wholesale invoices)
  //   1.  trusted "payable" style labels
  //   2.  receipt "#Items :3 | Rs.50,00"
  //   3a. generic Total (amount after label, amount-only line)
  //   3b. generic Total (amount before label)
  //   3c. Indian shop receipt: "Net Amount" is the payable total
  //   4.  Subtotal - Discount + Tax
  //   5.  payment line (Cash / UPI / Card amount)
  //   6.  biggest amount with a currency symbol
  //   7.  biggest amount with 2 decimals
  // ===========================================================================

  static const _totalLabels = [
    r'amount\s*paid',
    r'(?:total\s*)?amount\s*due',
    r'balance\s*due',
    r'total\s*due',
    r'grand\s*total',
    r'(?:net|total)\s*(?:amount\s*)?payable',
    r'amount\s*payable',
    r'total\s+charges?\s+for\s+this\s+bill',
    r'total\s+amount\s+after\s+tax',
    r'invoice\s+(?:total|amount)',
    r'bill\s*(?:total|amount|amt)',
    r'total\s+amount' + _notFinalTotal,
    r'total\s*amt',
    r'total\s+to\s+pay',
  ];

  /// Subtotal - Discount (+ tax) when the bill prints both, otherwise null.
  static double? _subtotalLessDiscount(String raw) {
    final sub = _amountAfter(raw, r'sub\s*total');
    final disc = _amountAfter(raw, r'discount');

    if (sub == null || disc == null || sub <= 0 || disc <= 0 || disc >= sub) {
      return null;
    }

    final calc = _round2(sub - disc + (_taxTotal(raw) ?? 0));

    return calc > 0 ? calc : null;
  }

  /// printed 71 vs calculated 1: the printed whole number ends with the
  /// calculated one, so the extra leading digit is a misread currency sign.
  static bool _looksLikeMisreadTotal(double printed, double calc) {
    if ((printed - calc).abs() < 0.005) {
      return false;
    }

    if (printed != printed.roundToDouble() || calc != calc.roundToDouble()) {
      return false;
    }

    return printed > calc &&
        printed.toStringAsFixed(0).endsWith(calc.toStringAsFixed(0));
  }

  /// Net + VAT worked out from the bill's own numbers.
  ///
  /// A VAT amount is taken from a line that mentions VAT / GST / Tax, and is
  /// accepted only if (gross - VAT) is also printed somewhere on the bill and
  /// the VAT is at most 30% of it. Handles column layouts where the labels and
  /// values are printed apart:
  ///
  /// TOTAL for items where VAT is charged at 20% | £42.96
  /// Total VAT at 20%                            | £8.59
  /// TOTAL which includes total VAT of £8.59       £51.55
  ///
  /// Returns [net, vat] or null.
  static List<double>? _vatFromArithmetic(String raw, double gross) {
    final vatWord = RegExp(r'\b(?:vat|gst|tax)', caseSensitive: false);

    final skip = RegExp(
      r'registration|\breg\b|number|\bno\b|gstin|rate\b|date|excl|before',
      caseSensitive: false,
    );

    final all = <double>[];
    final counts = <double, int>{};

    for (final line in _cleanLines(raw)) {
      final amounts = _moneyIn(line);

      all.addAll(amounts);

      if (!vatWord.hasMatch(line) || skip.hasMatch(line)) {
        continue;
      }

      for (final a in amounts) {
        counts[a] = (counts[a] ?? 0) + 1;
      }
    }

    final candidates =
        counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    for (final vat in candidates) {
      final net = _round2(gross - vat);

      if (vat <= 0 || net <= 0 || vat > net * 0.3) {
        continue;
      }

      if (all.any((a) => (a - net).abs() <= 0.02)) {
        return [net, vat];
      }
    }

    return null;
  }

  static double? _totalFromText(String rawText) {
    final raw = _moneyLines(rawText);

    // 0. NEW: wholesale invoice "Total Invoice" (checked against goods + VAT)
    final invoiceTotal = _invoiceTotal(raw);

    if (invoiceTotal != null) {
      return invoiceTotal;
    }

    // 1. Trusted labels
    for (final label in _totalLabels) {
      final v = _amountAfter(raw, label);

      if (v != null) {
        return v;
      }
    }

    // 2. Receipt style: "#Items :3 | Rs.50,00"
    final itemsTotal = _amountAfter(
      raw,
      r'#?\s*items?\s*(?:\(s\))?\s*:?\s*\d+',
      useNextLine: false,
    );

    if (itemsTotal != null) {
      return itemsTotal;
    }

    // 3a. Generic total - amount after label.
    // amountOnly: a "Total <words> 81.49" line is never a payable total.
    final totalAfter = _amountAfter(raw, _genericTotal, amountOnly: true);

    if (totalAfter != null) {
      // "Subtotal 1,062 / Discount 1,061 / Total 71": OCR read the rupee sign
      // as a digit ("₹1" -> "71"). The bill's own arithmetic wins.
      final calc = _subtotalLessDiscount(raw);

      if (calc != null && _looksLikeMisreadTotal(totalAfter, calc)) {
        return calc;
      }

      return totalAfter;
    }

    // 3b. Generic total - amount before label
    //
    // National | 0:12:20
    // 17.20
    // Total
    final totalBefore = _amountBefore(raw, _genericTotal, maxLookBack: 2);

    if (totalBefore != null) {
      return totalBefore;
    }

    // 3c. Indian shop receipts: "Net Amount | 60.00" is the payable total.
    // The label regex tolerates OCR damage ("Net Aniount", "Net Anount").
    if (_currencyOf(raw) == '₹') {
      final netPayable = _amountAfter(
        raw,
        r'net\s*a\w{3,6}t',
        amountOnly: true,
      );

      if (netPayable != null) {
        return netPayable;
      }
    }

    // 4. Subtotal - Discount + Tax
    final subTotal = _amountAfter(raw, r'sub\s*total');

    if (subTotal != null && subTotal > 0) {
      final discount = _amountAfter(raw, r'discount') ?? 0;
      final tax = _taxTotal(raw) ?? 0;

      final calculated = subTotal - discount + tax;

      if (calculated > 0) {
        return _round2(calculated);
      }
    }

    // 5. Payment line
    final tender = _tenderAmount(raw);

    if (tender != null) {
      return tender;
    }

    // 6. Biggest amount with a currency symbol
    final symbol = _largestSymbolAmount(raw);

    if (symbol != null) {
      return symbol;
    }

    // 7. Biggest amount with 2 decimals
    return _largestDecimalAmount(raw);
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

  /// First amount printed right after a payment label, stopping at the next
  /// word, so
  ///   "Cash A mount : 100.00 Balance | :32.00"  -> 100.00 (not the balance)
  ///   "Card Aount : 0.00 | UPI | 60.00"          -> nothing (UPI is separate)
  static double? _paidOn(String raw, String label) {
    final rx = RegExp('(?<![A-Za-z])$label(?![A-Za-z])', caseSensitive: false);

    final skip = RegExp(
      r'return|\bno\b|mode|method|account',
      caseSensitive: false,
    );

    for (final line in _cleanLines(raw)) {
      final m = rx.firstMatch(line);

      if (m == null || skip.hasMatch(line)) {
        continue;
      }

      var rest = line.substring(m.end);

      final nextWord = RegExp(r'[A-Za-z]{2,}').firstMatch(rest);

      if (nextWord != null) {
        rest = rest.substring(0, nextWord.start);
      }

      final amounts = _moneyIn(rest);

      if (amounts.isNotEmpty) {
        return amounts.first;
      }
    }

    return null;
  }

  static String? _paymentFromAmounts(String raw) {
    // Label regexes tolerate OCR damage: "Cash Anount", "Cash A mount".
    final cash = _paidOn(raw, r'cash\s*a\s*\w*') ?? 0;

    final card = _paidOn(raw, r'card\s*a\s*\w*') ?? 0;

    final upi = _paidOn(raw, r'upi') ?? 0;

    if (cash != 0 || card != 0 || upi != 0) {
      // UPI/wallet is represented as Card because the app currently
      // supports Cash / Card only.
      if (card + upi > cash) {
        return 'Card';
      }

      if (cash > 0) {
        return 'Cash';
      }
    }

    // "Payment Mode: CASH", "Received By Cash", "Paid by UPI" ...
    return InvoiceExtractionService.detectPaymentMode(raw);
  }

  // ===========================================================================
  // DATE
  // ===========================================================================

  static String _iso(DateTime d) {
    return '${d.year}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// - Blank date            -> upload date
  /// - Date in the future    -> OCR misread the last digit of the year
  ///                            (05-10-2028 -> 2026-10-05); pick the latest
  ///                            year in that decade that is not in the future,
  ///                            otherwise use the upload date.
  static String? _sanitizeDate(dynamic value, dynamic uploaded) {
    final today = DateTime.now();

    final uploadedDate = DateTime.tryParse('${uploaded ?? ''}');

    var d = DateTime.tryParse('${value ?? ''}');

    if (d == null) {
      return uploadedDate == null ? null : _iso(uploadedDate);
    }

    if (d.isAfter(today.add(const Duration(days: 1)))) {
      DateTime? best;

      final base = (d.year ~/ 10) * 10;

      for (var y = base; y < base + 10; y++) {
        final c = DateTime(y, d.month, d.day);

        if (c.month != d.month) {
          continue; // invalid, e.g. 29 Feb on a non leap year
        }

        if (!c.isAfter(today) && (best == null || c.isAfter(best))) {
          best = c;
        }
      }

      d = best ?? uploadedDate ?? d;
    }

    return _iso(d);
  }

  // ===========================================================================
  // SUPPLIER
  // ===========================================================================

  /// NEW: words printed by the keyboard / laptop in the photo background.
  static final RegExp _kbNoise = RegExp(
    r'^(zeb\w*|shift|ctrl|ctri|alt|caps\s*lock|search|enter|tab|esc|backspace)$',
    caseSensitive: false,
  );

  static bool _badSupplier(dynamic value) {
    final s = '${value ?? ''}'.trim();

    return _blank(s) ||
        s.length < 4 ||
        !RegExp(r'[A-Za-z]{3,}').hasMatch(s) ||
        _kbNoise.hasMatch(s) ||
        RegExp(
          r'^(tax\s*)?'
          r'(invoice|receipt|statement|bill|bill\s*to|date|cash\s*memo)\b',
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

    // NEW: "3.292.62" -> "3,292.62"
    raw = _fixThousandDots(raw);

    final out = Map<String, dynamic>.from(inv);

    // -------------------------------------------------------------------------
    // Currency
    // -------------------------------------------------------------------------

    out['currency'] = _currencyOf(raw);

    // -------------------------------------------------------------------------
    // Always check the explicit OCR total BEFORE trusting backend/extractor
    // money, otherwise a wrong extractor value would remain.
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

    // Explicit OCR total has the highest priority.
    if (explicitTotal != null && explicitTotal > 0) {
      out['gross'] = explicitTotal;

      // If net is missing, or the extractor produced a value larger
      // than the actual total, use the explicit total.
      if (_num(out['net']) == 0 || _num(out['net']) > explicitTotal) {
        out['net'] = explicitTotal;
      }

      // Extractor net + VAT that do not add up to the explicit total were read
      // from the wrong lines (e.g. VAT 1000 = Amount Due - Sub Total).
      // Drop that VAT; it is re-derived below.
      if (!trustBackendMoney &&
          (_num(out['net']) + _num(out['vat']) - explicitTotal).abs() > 0.02) {
        out['vat'] = 0;
      }
    }
    // If there is no explicit total, use net + VAT.
    else if (_num(out['gross']) == 0 && _num(out['net']) > 0) {
      out['gross'] = _num(out['net']) + _num(out['vat']);
    }

    // =========================================================================
    // NEW: TOTAL GOODS + TOTAL VAT = TOTAL INVOICE (wholesale invoices)
    // =========================================================================

    final goodsVat = _goodsVat(raw, _num(out['gross']).toDouble());

    if (goodsVat != null) {
      out['net'] = goodsVat[0];
      out['vat'] = goodsVat[1];
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
    final gross = _num(out['gross']).toDouble();

    if (gross > 0 && _num(out['vat']) == 0) {
      final tableNet = _gstTableNet(raw);

      final beforeTax = _amountAfter(raw, r'total\s+amount\s+before\s+tax');

      final gstAmount = _amountAfter(raw, r'total\s+amount\s*:\s*gst');

      // A VAT / GST / CGST+SGST line on the bill:
      //
      // Electricity Charges  421.52
      // VAT                  84.30
      // Total                505.82
      final arith = tableNet == null ? _vatFromArithmetic(raw, gross) : null;

      final tax = tableNet == null ? _taxTotal(raw) : null;

      if (tableNet != null && tableNet > 0 && tableNet <= gross + 0.02) {
        // GST table: taxable rows add up to net, the rest is GST.
        final net = tableNet > gross ? gross : tableNet;
        final vat = _round2(gross - net);

        out['net'] = net;
        out['vat'] = vat < 0.01 ? 0 : vat;
      } else if (beforeTax != null && beforeTax < gross) {
        out['net'] = beforeTax;
        out['vat'] = gstAmount ?? _round2(gross - beforeTax);
      } else if (gstAmount != null && gstAmount < gross) {
        out['vat'] = gstAmount;
        out['net'] = _round2(gross - gstAmount);
      } else if (arith != null) {
        out['net'] = arith[0];
        out['vat'] = arith[1];
      } else if (tax != null && tax > 0 && tax <= gross * 0.4) {
        out['vat'] = tax;
        out['net'] = _round2(gross - tax);
      } else if (_num(out['net']) > 0 && _num(out['net']) < gross) {
        // Fallback: derive VAT from gross - net.
        out['vat'] = _round2(gross - _num(out['net']));
      }
    }

    final payment = _paymentFromAmounts(raw);

    if (payment != null) {
      out['payment'] = payment;
    }

    final fixedDate = _sanitizeDate(out['date'], inv['uploaded_at']);

    if (fixedDate != null) {
      out['date'] = fixedDate;
    }

    return out;
  }
}
