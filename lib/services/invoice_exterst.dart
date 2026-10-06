library;

class InvoiceExtractionService {
  // ---------------------------------------------------------------------
  // Label lists (priority order)
  // ---------------------------------------------------------------------
  static const _netLabels = [
    'Sub Total',
    'Subtotal',
    'Net Amount',
    'Net Total',
    'Total Net',
    'Total Goods', // NEW
    'Goods Total',
    'Total Amount (Exc. VAT)',
    'Total Excluding VAT',
    'Total Ex VAT',
    'Total (Ex VAT)',
    'Amount Exc VAT',
    'Total Amount Before Tax',
    'Total Before Tax',
    'Taxable Value',
    'Taxable Amount',
    'Net Value',
    'Goods',
  ];

  static const _vatLabels = [
    'VAT Total',
    'Total V.A.T.',
    'Total VAT',
    'VAT Amount',
    'VAT Amt',
    'Total GST',
    'GST Amount',
    'GST Amt',
    'Total Tax',
    'Tax Amount',
    'Sales Tax',
    'V.A.T.',
    'VAT',
    'GST',
  ];

  static const _grossLabels = [
    'Total Amount (Inc. VAT)',
    'Total Inc VAT',
    'Total (Inc. VAT)',
    'Total Including VAT',
    'Amount Inc VAT',
    "Today's Total",
    'Total Due',
    'Total Amount Due',
    'Amount Due',
    'Balance Due',
    'Grand Total',
    'Total Invoice', // NEW
    'Invoice Total',
    'Net Payable',
    'Amount Payable',
    'Bill Amount',
    'Bill Amt',
    'Total Payable',
    'Total Amount',
    'Total Amt',
    'TOTAL',
  ];

  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static String? detectCurrency(String text) {
    int count(String pattern, {bool ci = true}) =>
        RegExp(pattern, caseSensitive: !ci).allMatches(text).length;
    final explicit = <String, int>{
      '£': count(r'£|\bGBP\b'),
      '€': count(r'€|\bEUR\b'),
      r'$': count(r'\$|\bUSD\b'),
      '₹': count(r'₹|\bINR\b|\bRs\.?(?=\s*\d)|\bRupees?\b'),
    };
    String? best;
    var max = 0;
    explicit.forEach((symbol, n) {
      if (n > max) {
        max = n;
        best = symbol;
      }
    });
    if (best != null) return best;

    if (count(
          r'\bGSTIN?\b|\bCGST\b|\bSGST\b|\bIGST\b|\bFSSAI\b|\bCHENNAI\b|\bMUMBAI\b|\bDELHI\b|\bBANGALORE\b|\bBENGALURU\b|\bHYDERABAD\b|\bKOLKATA\b|\bPUNE\b|\bTAMIL\s*NADU\b|\bINDIA\b',
        ) >
        0) {
      return '₹';
    }
    if (count(r'\bVAT\b|\bLtd\b|\bLimited\b|\bPLC\b|\bUnited\s*Kingdom\b') >
        0) {
      return '£';
    }
    if (count(r'\bUSA\b|\bUnited\s*States\b|\bSales\s*Tax\b') > 0) {
      return r'$';
    }
    return null;
  }

  static String? detectPaymentMode(String text) {
    String? classify(String s) {
      final l = s.toLowerCase();
      if (RegExp(
        r'\b(upi|gpay|google\s*pay|phonepe|paytm|visa|master\s*card|mastercard|debit|credit\s*card|card|contactless|wallet|net\s*banking|direct\s*debit)\b',
      ).hasMatch(l)) {
        return 'Card';
      }
      if (RegExp(r'\bcash\b').hasMatch(l)) {
        return 'Cash';
      }
      return null;
    }

    final lines = text.split('\n');

    // "Payment Mode: CASH", "Received By Cash", "Paid by UPI" ...
    final hint = RegExp(
      r'mode|method|paid\s*by|paid\s*(?:in|with|via)|received\s*by|tender|payment|settled',
      caseSensitive: false,
    );
    for (final line in lines) {
      if (hint.hasMatch(line)) {
        final c = classify(line);
        if (c != null) return c;
      }
    }

    // Tender line: "Cash | 50.00", "UPI PayTm | 288.00", "Card 12.50"
    final tender = RegExp(
      r'^\W*(cash|upi|card|visa|mastercard|gpay|phonepe|paytm)\b[^\n]*\d',
      caseSensitive: false,
    );
    for (final line in lines) {
      final t = line.trim();
      if (tender.hasMatch(t)) {
        final c = classify(t);
        if (c != null) return c;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Main entry point
  // ---------------------------------------------------------------------
  static Map<String, dynamic> extract(String rawText) {
    final text = _normalize(rawText);
    final lines =
        text
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

    // Rupee invoices use whole-number amounts (no decimals).
    final rupee = detectCurrency(text) == '₹';

    double? net = _extractAmount(lines, _netLabels, rupee: rupee);
    double? vat = _extractAmount(lines, _vatLabels, isVat: true, rupee: rupee);
    double? gross = _extractAmount(
      lines,
      _grossLabels,
      fromBottom: true,
      strictTotal: true,
      rupee: rupee,
    );
    if (gross != null && gross <= 0) gross = null;

    // "Subtotal" + "Discount" and a "Total" line with no value.
    if (gross == null && net != null) {
      final disc = _extractAmount(lines, const ['Discount'], rupee: rupee);
      if (disc != null && disc > 0 && disc < net) net = _r2(net - disc);
    }

    // Shop receipts print "Net Amount" as the payable total and have no
    // separate VAT line -> gross = net (do not guess from other numbers).
    if (rupee && gross == null && net != null && vat == null) {
      gross = net;
    }

    // Ignore payment lines (cash given, change, card, UPI ...) so the
    // inference below never picks "Cash Amount : 100.00" as the total.
    final paymentLine = RegExp(
      r'cash|card|upi|sodexo|credit|balance|change|tender|\bloy\w*|\bpoin\w*|saved|round',
      caseSensitive: false,
    );
    final allAmounts =
        lines
            .where((l) => !paymentLine.hasMatch(l))
            .expand(_parseAmounts)
            .toList();
    bool close(double a, double b) => (a - b).abs() <= 0.02;

    // Nothing usable found by label: infer the total from the numbers.
    if (gross == null && !(net != null && vat != null)) {
      gross = _inferGross(allAmounts);
    }

    // UK VAT is at most 20%. If the VAT we found is bigger than that, it was
    // read from the wrong place (e.g. a line-item amount). Net and gross are
    // reliable here, so derive VAT from them instead.
    if (net != null && gross != null && vat != null && !rupee) {
      final maxVat = net * 0.21 + 0.02;
      final diff = _r2(gross - net);
      if (vat > maxVat && diff >= 0 && diff <= maxVat) {
        vat = diff;
      }
    }

    // Cross-check the three amounts against each other.
    if (net != null && vat != null) {
      final sum = _r2(net + vat);
      if (gross == null) {
        gross = sum;
      } else if (!close(gross, sum) && allAmounts.any((a) => close(a, sum))) {
        // Gross was picked from the wrong line (e.g. previous balance).
        gross = sum;
      }
    } else if (gross != null && vat != null && net == null) {
      net = _r2(gross - vat);
    } else if (gross != null && net != null && vat == null) {
      vat = _r2(gross - net);
    }

    // No VAT/GST line (e.g. Indian invoices): total = net.
    if (rupee && gross == null && net != null) {
      gross = _r2(net + (vat ?? 0));
    }

    return {
      'supplier': _extractSupplier(lines),
      'vat_number': _extractVatNumber(lines, text),
      'invoice_no': _extractInvoiceNo(lines),
      'branch': _extractCustomer(lines),
      'date': _extractDate(text),
      'net': net ?? 0.0,
      'vat': vat ?? 0.0,
      'gross': gross ?? 0.0,
      'sr': 0,
      'zr': 0,
      'exempt': 0,
      'payment': _extractPaymentTerm(text),
      'currency': detectCurrency(text) ?? '£',
      'extraction_method': 'ai',
      'ocr_status': 'complete',
      'status': 'pending',
    };
  }

  // ---------------------------------------------------------------------
  // Normalisation of common OCR mistakes before parsing
  // ---------------------------------------------------------------------
  static String _normalize(String raw) {
    var t = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\t', ' ');
    t = t.replaceAll(RegExp(r' {2,}'), ' ');
    t = t.replaceAll(RegExp(r'\b[l1]nvoice\b'), 'Invoice');
    t = t.replaceAll(RegExp(r'\bT[0O]TAL\b'), 'TOTAL');
    t = t.replaceAll(RegExp(r'\bV[4A]T\b'), 'VAT');
    t = t.replaceAll(RegExp(r'\bUmited\b'), 'Limited'); // "Magna ... Umited"
    t = t.replaceAll(
      RegExp(r'\bDel{1,2}[il1]?very\b', caseSensitive: false),
      'Delivery',
    ); // Dellvery / Delvery
    // NEW: OCR prints "3.292.62" (dots as thousands separator) -> "3,292.62"
    t = t.replaceAllMapped(
      RegExp(r'(?<![\d.,])(\d{1,3})\.(\d{3})\.(\d{2})(?!\d)'),
      (m) => '${m[1]},${m[2]}.${m[3]}',
    );
    return t;
  }

  // ---------------------------------------------------------------------
  // Supplier
  // ---------------------------------------------------------------------
  static final _supplierNoise = RegExp(
    r'(\b(TEL|TELEPHONE|PHONE|MOBILE|FAX|WWW|HTTP|HTTPS|EMAIL|E-MAIL|ORDER|VAT|V\.A\.T|DATE|PAGE|COPY|ORIGINAL|DUPLICATE|INVOICE|STATEMENT|RECEIPT|CUSTOMER|ACCOUNT|WEBSITE|VISIT|DELIVERY|CREDIT NOTE|BILL|GST|GSTIN|TAX|MEMO|CASH MEMO|FSSAI)\b|@|\d{5,})',
    caseSensitive: false,
  );

  static final _addressLike = RegExp(
    r'^\d+[\s,\-]|\b[A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2}\b|\b(UNIT|ROAD|RD|STREET|ST|WAY|LANE|PARK|HOUSE|AVENUE|AVE|UNITED KINGDOM|LONDON)\b',
    caseSensitive: false,
  );

  /// NEW: words printed by the keyboard / laptop that is in the photo
  /// background (Zebronics, Shift, Alt, Search ...). Never a supplier.
  static final _kbNoise = RegExp(
    r'^(zeb\w*|shift|ctrl|ctri|alt|caps\s*lock|search|enter|tab|esc|backspace)$',
    caseSensitive: false,
  );

  static String? _extractSupplier(List<String> lines) {
    if (lines.isEmpty) return null;

    // NEW step 0: multi page invoices repeat "<Supplier> <Depot>" right above
    // the "Tel:-" line on every page ("Parfetts Sheffield"). OCR damages the
    // word differently each time, so use the most frequent spelling. Needs at
    // least 2 identical hits, so single page invoices are not affected.
    final tel = RegExp(r'^\W*Tel\b', caseSensitive: false);
    final counts = <String, int>{};
    for (var i = 1; i < lines.length; i++) {
      if (!tel.hasMatch(lines[i])) continue;
      final prev = lines[i - 1].split('|').first.trim();
      final w = RegExp(r'^[A-Za-z][A-Za-z&\-]{3,}').firstMatch(prev)?.group(0);
      if (w == null ||
          _kbNoise.hasMatch(w) ||
          _supplierNoise.hasMatch(w) ||
          _addressLike.hasMatch(prev)) {
        continue;
      }
      counts[w] = (counts[w] ?? 0) + 1;
    }
    if (counts.isNotEmpty) {
      final best = counts.keys.reduce(
        (a, b) => counts[b]! > counts[a]! ? b : a,
      );
      if (counts[best]! >= 2) return best;
    }

    // Only look above the customer / delivery block so we never return the
    // customer's name (e.g. "VENPA Trading Ltd"). "Ship Te" is OCR for
    // "Ship To".
    final blockStart = RegExp(
      r'^\W*(Invoice|B[il1]{1,3}|Deliver(?:y)?|Ship|Sold)\s*(To|Te|Address)\b',
      caseSensitive: false,
    );
    var limit = lines.length < 25 ? lines.length : 25;
    for (var i = 1; i < limit; i++) {
      if (blockStart.hasMatch(lines[i])) {
        limit = i;
        break;
      }
    }
    final head = lines.sublist(0, limit);

    final legalSuffix = RegExp(
      r'\b(LTD\.?|LIMITED|PLC|LLP|INC\.?|LLC|CORP(?:ORATION)?|PVT\.?|PRIVATE)\b',
      caseSensitive: false,
    );
    final businessWord = RegExp(
      r'\b(COMPANY|CO\.|WHOLESALE|FOODS?|FOODSERVICE|TRADING|SUPPLIES|DISTRIBUTION|DISTRIBUTORS|TRADERS|GROUP|ENTERPRISES|SERVICES|HOLDINGS|CASH\s*&\s*CARRY|IMPORTS?|EXPORTS?|STORES?|MART|SUPERMARKET|RESTAURANT|HOTEL|PHARMACY|MEDICALS?|BAKERY|CAFE)\b',
      caseSensitive: false,
    );

    // Column layouts: OCR often glues the right-hand labels onto the supplier
    // line, e.g. "Magna Foodservice Limited Invoice Date 01/12/2025".
    final columnCut = RegExp(
      r'\s+(Invoice\s*(Date|No|Number)|Tax\s*Date|Date\b|VAT\s*(No|Number|Reg)|V\.A\.T|Tel\b|Phone|Customer\s*Copy|Page\b)',
      caseSensitive: false,
    );
    String clean(String l) {
      var c = l
          .replaceAll(RegExp(r'[|].*'), '')
          .replaceFirst(RegExp(r'^\s*from\s*:\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'^[^A-Za-z0-9]+'), '');
      final cut = columnCut.firstMatch(c);
      if (cut != null && cut.start > 0) c = c.substring(0, cut.start);
      final suffix = legalSuffix.firstMatch(c);
      if (suffix != null) c = c.substring(0, suffix.end);
      return c.trim();
    }

    // 1. Legal company name (Ltd / Limited / PLC ...)
    for (final line in head) {
      final c = clean(line);
      if (c.length > 3 &&
          legalSuffix.hasMatch(c) &&
          !_kbNoise.hasMatch(c) &&
          !_supplierNoise.hasMatch(c)) {
        return c;
      }
    }

    // 2. Business-sounding line
    for (final line in head) {
      final c = clean(line);
      if (c.length > 3 &&
          businessWord.hasMatch(c) &&
          !_kbNoise.hasMatch(c) &&
          !_supplierNoise.hasMatch(c)) {
        return c;
      }
    }

    // 3. First clean, non-address line near the top
    for (final line in head.take(6)) {
      final c = clean(line);
      if (c.length > 3 &&
          RegExp(r'[A-Za-z]{3,}').hasMatch(c) &&
          !_kbNoise.hasMatch(c) &&
          !_supplierNoise.hasMatch(c) &&
          !_addressLike.hasMatch(c)) {
        return c;
      }
    }

    // Last resort: first line that is not keyboard noise.
    for (final l in lines) {
      if (!_kbNoise.hasMatch(l.trim())) return l;
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // VAT number (UK style: 9 or 12 digits, optional GB prefix)
  // ---------------------------------------------------------------------
  static String? _extractVatNumber(List<String> lines, String text) {
    final label = RegExp(
      r'V\.?A\.?T\.?\s*(?:Reg(?:istration)?\.?|No\.?|Number|#)',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      final match = label.firstMatch(lines[i]);
      if (match == null) continue;

      // OCR rows look like "VAT Number | 186 3464 79": drop the leading pipe
      // first, otherwise the cut below would empty the segment.
      var segment = lines[i]
          .substring(match.end)
          .replaceFirst(RegExp(r'^[\s|:]+'), '');
      final stop = segment.indexOf(RegExp(r'\||\bTerm', caseSensitive: false));
      if (stop != -1) segment = segment.substring(0, stop);

      var found = _vatDigits(segment);
      if (found == null && i + 1 < lines.length) {
        found = _vatDigits(lines[i + 1]);
      }
      if (found != null) return found;
    }

    // Fallback: a bare GB-prefixed number anywhere.
    final gb = RegExp(
      r'\bGB\s?(\d{3}\s?\d{4}\s?\d{2})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (gb != null) return gb.group(1)!.replaceAll(RegExp(r'\s'), '');

    // Fallback: value printed on its own line in 3-4-2 grouping (186 3464 79)
    final grouped = RegExp(r'^(?:GB\s*)?(\d{3})\s(\d{4})\s(\d{2})$');
    for (final line in lines) {
      final g = grouped.firstMatch(line);
      if (g != null) return '${g.group(1)}${g.group(2)}${g.group(3)}';
    }

    // Indian GSTIN: 15 chars, e.g. 33AAACW1234A1Z5
    final gstin = RegExp(
      r'\b(\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z])\b',
    ).firstMatch(text.toUpperCase());
    if (gstin != null) return gstin.group(1);

    return null;
  }

  static String? _vatDigits(String s) {
    var seg = s.replaceFirst(
      RegExp(r'^[\s.:#\-]*(?:GB)?', caseSensitive: false),
      '',
    );
    seg = _fixNumericTokens(seg);
    seg = seg.replaceAll(
      RegExp(r'(?<=\d)[.\-](?=\d)'),
      '',
    ); // 3464.79 -> 346479
    final m = RegExp(r'(\d[\d ]{7,13}\d)').firstMatch(seg);
    if (m == null) return null;
    final digits = m.group(1)!.replaceAll(' ', '');
    if (digits.length < 9) return null;
    return digits.substring(0, digits.length >= 12 ? 12 : 9);
  }

  // ---------------------------------------------------------------------
  // Invoice number
  // ---------------------------------------------------------------------
  static String? _extractInvoiceNo(List<String> lines) {
    final labelPatterns = [
      r'Invoice\s*(?:No\.?|Number|Num\.?|#|Ref\.?)',
      r'\bI\w{1,5}ce\s*No\.?', // OCR-damaged "Ivofce No.", "Involce No."
      r'Inv\.?\s*(?:No\.?|#)',
      r'Bill(?:ing)?\s*(?:No\.?|Number|#)',
      r'Receipt\s*(?:No\.?|Number|#)',
      r'(?:Cash\s*)?Memo\s*No\.?',
      r'Document\s*No\.?',
      r'\bNo\.?\s*[:#-]\s*(?=\d)',
    ];
    final tokenRx = RegExp(r'[A-Za-z0-9][A-Za-z0-9\-\/]{2,14}');
    final noise = RegExp(
      r'(Tax|Date|Term|Tel|Fax|Website|Page|Account)',
      caseSensitive: false,
    );
    final dateLike = RegExp(r'^\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}$');
    // Lines that carry other numbers; ignored by the loose patterns.
    final otherNumberLine = RegExp(
      r'V\.?A\.?T|Account|Acc\.?\s*No|Tel|Phone|Customer|Order|Sort|Delivery|Cheque|Auth',
      caseSensitive: false,
    );

    String? pick(String window) {
      window = window.replaceAll(RegExp(r'^[|:#\s\-.]+'), '');
      for (final m in tokenRx.allMatches(window)) {
        final t = m.group(0)!;
        if (!RegExp(r'\d').hasMatch(t)) continue;
        if (noise.hasMatch(t) || dateLike.hasMatch(t)) continue;
        return t;
      }
      return null;
    }

    for (var p = 0; p < labelPatterns.length; p++) {
      final regex = RegExp(labelPatterns[p], caseSensitive: false);
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (p >= 3 && otherNumberLine.hasMatch(line)) continue;

        final m = regex.firstMatch(line);
        if (m == null) continue;

        final rest = line.substring(m.end);
        var result = pick(rest);

        // Value may sit on one of the next lines (column layouts).
        if (result == null &&
            rest.replaceAll(RegExp(r'[\s:|#.\-]'), '').isEmpty) {
          for (
            var k = 1;
            k <= 2 && i + k < lines.length && result == null;
            k++
          ) {
            final next = lines[i + k];
            if (RegExp(r'^\S+$').hasMatch(next)) result = pick(next);
          }
        }
        if (result != null) return result;
      }
    }

    // Fallback 1: "#IN0511167" style reference with no "Invoice No" label.
    for (final line in lines.take(40)) {
      if (otherNumberLine.hasMatch(line)) continue;
      final m = RegExp(r'#\s*([A-Za-z0-9\-\/]{4,15})').firstMatch(line);
      if (m != null && RegExp(r'\d').hasMatch(m.group(1)!)) {
        return _fixRefPrefix(m.group(1)!);
      }
    }

    // Fallback 2: a line that is only a reference (e.g. "82937", "SI-20931").
    final onlyRef = RegExp(r'^[A-Za-z]{0,4}[-\/]?\d{4,10}$');
    for (final line in lines.take(30)) {
      if (!onlyRef.hasMatch(line) || dateLike.hasMatch(line)) continue;
      if (line.startsWith('0') && line.length >= 10) continue; // phone
      return line;
    }
    return null;
  }

  /// "#INO511167" (letter O read for zero) -> "IN0511167".
  static String _fixRefPrefix(String ref) {
    final m = RegExp(r'^[1lI]N([0-9OoIlSs]{5,})$').firstMatch(ref);
    if (m != null) return 'IN${_cleanNumericOcr(m.group(1)!)}';
    return ref.replaceFirst(RegExp(r'^[1lI]N(?=\d)'), 'IN');
  }

  // ---------------------------------------------------------------------
  // Customer / branch
  // ---------------------------------------------------------------------
  static String? _extractCustomer(List<String> lines) {
    final regex = RegExp(
      r'(?:Invoice|B[il1]{1,3})\s*To\b\s*[:|]?\s*([^\n|]*)',
      caseSensitive: false,
    );
    final stopRx = RegExp(
      r'(Invoice\s*No|Tax\s*Date|\bDate\b|Ship\s*To|Deliver|[|])',
      caseSensitive: false,
    );
    final codeLike = RegExp(r'^[A-Za-z]?\d{2,8}$');
    // "Invoice Details" (right-hand column header) is not a name.
    bool bad(String v) =>
        v.isEmpty ||
        codeLike.hasMatch(v) ||
        RegExp(
          r'^(Ship|Deliver|Phone|Tel|Invoice\s*Details?)',
          caseSensitive: false,
        ).hasMatch(v);

    for (var i = 0; i < lines.length; i++) {
      final match = regex.firstMatch(lines[i]);
      if (match == null) continue;

      var value = match.group(1)!.trim();
      final stop = value.indexOf(stopRx);
      if (stop != -1) value = value.substring(0, stop).trim();

      // Customer name often sits on the following line(s).
      var k = i;
      while (bad(value) && k + 1 < lines.length && k < i + 3) {
        k++;
        value = lines[k].split('|').first.trim();
      }

      // "VENPA Trading Ltd T/A" -> the trading name is on the next line.
      if (RegExp(r'\bT\/A\b', caseSensitive: false).hasMatch(value) &&
          k + 1 < lines.length) {
        final next = lines[k + 1].split('|').first.trim();
        if (next.length > 2 &&
            !RegExp(
              r'^(United|Phone|Tel)',
              caseSensitive: false,
            ).hasMatch(next)) {
          value = next;
        }
      }

      if (!bad(value)) return value;
    }

    return _extractCustomerFromShipTo(lines);
  }

  /// Magna-style layout: a "Ship To | Delivery Date | ..." header row, then a
  /// row starting with the customer code (V144), then the customer name,
  /// optionally "X Ltd T/A" followed by the trading name.
  static String? _extractCustomerFromShipTo(List<String> lines) {
    final header = RegExp(r'\bShip\s*T[oe0]\b', caseSensitive: false);
    final codeLike = RegExp(r'^[A-Za-z]?\d{2,8}$');
    final skipNext = RegExp(r'^(United|Phone|Tel)', caseSensitive: false);

    for (var i = 0; i < lines.length; i++) {
      if (!header.hasMatch(lines[i])) continue;

      for (var k = i + 1; k <= i + 4 && k < lines.length; k++) {
        final first = lines[k].split('|').first.trim();
        if (first.isEmpty || codeLike.hasMatch(first)) continue;
        if (!RegExp(r'[A-Za-z]{3,}').hasMatch(first)) continue;

        if (RegExp(r'\bT\/A\b', caseSensitive: false).hasMatch(first) &&
            k + 1 < lines.length) {
          final next = lines[k + 1].split('|').first.trim();
          if (next.length > 2 && !skipNext.hasMatch(next)) return next;
        }
        return first;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Date
  //
  // Supports:
  //   2025-01-12   2025/01/12   2025.01.12
  //   12/01/2025   12-01-25     12.01.2025   (dd/mm, auto-swaps mm/dd)
  //   12 Jan 2025  12th January, 2025
  //   Jan 12, 2025 January 12th 2025
  // ---------------------------------------------------------------------
  static String? _extractDate(String text) {
    final labelRx = RegExp(
      r'(?:Tax\s*Date|Invoice\s*Date|Date\s*of\s*Invoice|Bill\s*Date|Date\s*of\s*Issue|Date)\s*[:|]?\s*([^\n|]{6,24})',
      caseSensitive: false,
    );
    for (final m in labelRx.allMatches(text)) {
      final d = _parseDate(m.group(1)!);
      if (d != null) return d;
    }
    for (final line in text.split('\n')) {
      final d = _parseDate(line);
      if (d != null) return d;
    }
    return null;
  }

  static int? _monthOf(String word) {
    final w = word.toLowerCase();
    if (w.length < 3) return null;
    final month = _months[w.substring(0, 3)];
    if (month == null) return null;
    // Must really look like a month name, not "Marketing" / "Decimal".
    const full = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'sept',
      'october',
      'november',
      'december',
    ];
    final ok = full.any((f) => f.startsWith(w)) || w.length == 3;
    return ok ? month : null;
  }

  static String? _parseDate(String s) {
    // 1. Year first: 2025-01-12 / 2025/01/12 / 2025.01.12
    var m = RegExp(
      r'(?<!\d)(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?!\d)',
    ).firstMatch(s);
    if (m != null) {
      final d = _buildDate(
        m.group(1)!,
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
      if (d != null) return d;
    }

    // 2. dd/mm/yyyy, dd-mm-yy, dd.mm.yyyy (mm/dd if the 2nd part is > 12)
    m = RegExp(
      r'(?<![\d.])(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{4}|\d{2})(?!\d)',
    ).firstMatch(s);
    if (m != null) {
      var day = int.parse(m.group(1)!);
      var month = int.parse(m.group(2)!);
      if (month > 12 && day <= 12) {
        final t = day;
        day = month;
        month = t;
      }
      final d = _buildDate(m.group(3)!, month, day);
      if (d != null) return d;
    }

    // 3. 12 Jan 2025 / 12th January, 2025
    for (final mm in RegExp(
      r'(\d{1,2})(?:st|nd|rd|th)?[\s\-]*([A-Za-z]{3,9})\.?,?[\s\-]*(\d{2,4})',
    ).allMatches(s)) {
      final month = _monthOf(mm.group(2)!);
      if (month != null) {
        final d = _buildDate(mm.group(3)!, month, int.parse(mm.group(1)!));
        if (d != null) return d;
      }
    }

    // 4. Jan 12, 2025 / January 12th 2025
    for (final mm in RegExp(
      r'([A-Za-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})',
    ).allMatches(s)) {
      final month = _monthOf(mm.group(1)!);
      if (month != null) {
        final d = _buildDate(mm.group(3)!, month, int.parse(mm.group(2)!));
        if (d != null) return d;
      }
    }
    return null;
  }

  static String? _buildDate(String year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    if (year.length == 2) year = '20$year';
    if (year.length != 4) return null;

    // NEW: OCR garbage such as "v2102" / "2036" must never become a date.
    final y = int.tryParse(year);
    if (y == null || y < 2000 || y > DateTime.now().year + 1) return null;

    return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------
  // Amounts
  // ---------------------------------------------------------------------
  static double? _extractAmount(
    List<String> lines,
    List<String> labels, {
    bool fromBottom = false,
    bool isVat = false,
    bool strictTotal = false,
    bool rupee = false, // whole-number currency (₹)
  }) {
    final vatIdLine = RegExp(
      r'(?:V\.?A\.?T|GST)\.?\s*(?:Reg|No|Number|#|IN\b)',
      caseSensitive: false,
    );

    final vatHeaderLine = RegExp(
      r'vat\s*rate|unit\s*price|description|\bqty\b|item\s*no|breakup|summary|hsn',
      caseSensitive: false,
    );
    final vatBadPrefix = RegExp(
      r'(exc|excl|excluding|ex|inc|incl|including)[.,]?\s*\(?\s*$',
      caseSensitive: false,
    );
    final badPrefix = RegExp(
      r'(sub|net|vat|v\.a\.t\.?|goods)\s*[-.]?\s*$',
      caseSensitive: false,
    );

    final badSuffix = RegExp(
      r'^\s*(vat|v\.a\.t|net|goods|items|qty|quantity|weight|lines)',
      caseSensitive: false,
    );
    // Lines that look like a total but are not the amount payable.
    final grossSkip = RegExp(
      r'previous\s*balance|prev\.?\s*balance|outstanding|brought\s*forward|customer\s*total|credit\s*limit|opening\s*balance|before\s*(?:tax|vat|gst)|\b(?:exc|excl|excluding|ex)[.,]?\s*\(?\s*vat',
      caseSensitive: false,
    );

    final indices = List<int>.generate(lines.length, (i) => i);
    if (fromBottom) indices.sort((a, b) => b.compareTo(a));

    for (final label in labels) {
      final regex = _labelRegex(label);

      for (final i in indices) {
        final line = lines[i];
        final m = regex.firstMatch(line);
        if (m == null) continue;

        final before = line.substring(0, m.start);
        final rest = line.substring(m.end);

        if (isVat) {
          if (vatIdLine.hasMatch(line)) continue;
          if (vatHeaderLine.hasMatch(line)) continue;
          if (vatBadPrefix.hasMatch(before)) continue;
        }
        if (strictTotal) {
          if (grossSkip.hasMatch(line)) continue;
          if (badPrefix.hasMatch(before)) continue;
          if (badSuffix.hasMatch(rest)) continue;
        }

        var amounts = _parseAmounts(rest);

        // Labels printed as a block, values as a second block below
        // (TOTAL EXC VAT / VAT / TOTAL INC VAT  then  £67.95 / £2.80 / £70.75).
        if (amounts.isEmpty) {
          final v = _blockValue(lines, i);
          if (v != null) amounts = [v];
        }

        // Value on the next line, e.g. "Subtotal" then "GBP 9.25".
        if (amounts.isEmpty &&
            i + 1 < lines.length &&
            _isAmountOnly(lines[i + 1])) {
          amounts = _parseAmounts(lines[i + 1]);
        }
        if (amounts.isNotEmpty) return amounts.last;

        // Last resort: amounts with no decimal point, only when the rest of
        // the line is just that number.
        if (_isAmountOnly(rest)) {
          final fixed = _fixNumericTokens(rest);

          // Thousands separator, no decimals ("F1,062", "{1,061", "1,23,456")
          // -> whole amount. "F" / "{" are OCR misreads of ₹ and are ignored.
          final comma = RegExp(
            r'(?<![\d.,])(\d{1,2}(?:,\d{2})+,\d{3}|\d{1,3}(?:,\d{3})+)(?![\d,]|\.\d)',
          ).firstMatch(fixed);
          if (comma != null) {
            final v = double.tryParse(comma.group(1)!.replaceAll(',', ''));
            if (v != null) return v;
          }

          // Bare digits (5790 -> 57.90). Rupee amounts are whole numbers.
          final raw = RegExp(
            rupee
                ? r'(?<![\d.,])(\d{1,7})(?![\d.,])'
                : r'(?<![\d.,])(\d{3,6})(?![\d.,])',
          ).firstMatch(fixed);
          if (raw != null) {
            final v = int.tryParse(raw.group(1)!);
            if (v != null) {
              final isRupee =
                  rupee ||
                  RegExp(r'₹|Rs\.?|INR', caseSensitive: false).hasMatch(rest);
              return isRupee ? v.toDouble() : v / 100.0;
            }
          }
        }
      }
    }
    return null;
  }

  static final _headerWord = RegExp(
    r'\b(rate|amt|unit\s*price|qty|description|u\.?o\.?m|item\s*no)\b',
    caseSensitive: false,
  );
  static final _totalsWord = RegExp(
    r'\b(total|vat|sub\s*total|subtotal|net|balance|amount|due|goods|discount|carriage|delivery|paid|payable)\b',
    caseSensitive: false,
  );

  static bool _isTotalsLabel(String l) =>
      l.length <= 40 &&
      _totalsWord.hasMatch(l) &&
      !_headerWord.hasMatch(l) &&
      _parseAmounts(l).isEmpty &&
      !_isAmountOnly(l);

  /// For a totals label whose value is not on its own line: find the block of
  /// consecutive totals labels, then take the value at the same position in
  /// the block of amount-only lines that follows it.
  static double? _blockValue(List<String> lines, int i) {
    if (!_isTotalsLabel(lines[i])) return null;
    var s = i;
    while (s > 0 && _isTotalsLabel(lines[s - 1])) {
      s--;
    }
    var e = i;
    while (e + 1 < lines.length && _isTotalsLabel(lines[e + 1])) {
      e++;
    }
    final n = e - s + 1;
    final values = <double>[];
    for (var j = e + 1; j < lines.length && values.length < n; j++) {
      if (!_isAmountOnly(lines[j])) break;
      final a = _parseAmounts(lines[j]);
      if (a.isEmpty) break;
      values.add(a.last);
    }
    return values.length >= n ? values[i - s] : null;
  }

  /// Total inferred from the numbers alone: the largest value that either
  /// appears at least twice, or equals the sum of two other amounts.
  static double? _inferGross(List<double> amounts) {
    double? best;
    for (final g in amounts.toSet()) {
      if (g <= 0) continue;
      final count = amounts.where((a) => (a - g).abs() <= 0.005).length;
      var ok = count >= 2;
      if (!ok) {
        for (final n in amounts) {
          final v = g - n;
          if (v > 0.005 && amounts.any((a) => (a - v).abs() <= 0.005)) {
            ok = true;
            break;
          }
        }
      }
      if (ok && (best == null || g > best)) best = g;
    }
    return best;
  }

  static bool _isAmountOnly(String s) {
    final t =
        s
            .replaceAll(RegExp(r'GBP|USD|EUR|[£$€]', caseSensitive: false), '')
            .trim();
    return t.isNotEmpty && !RegExp(r'[A-Za-z]{2,}').hasMatch(t);
  }

  static RegExp _labelRegex(String label) {
    final chars = label
        .replaceAll(RegExp(r"[^A-Za-z0-9']"), '')
        .split('')
        .map((c) => c == "'" ? r"['’]?" : RegExp.escape(c))
        .join(r'[\s\-_.,()/:]*');
    return RegExp('(?<![A-Za-z])$chars(?![A-Za-z])', caseSensitive: false);
  }

  // ---------------------------------------------------------------------
  // PARSE AMOUNTS
  //
  // An amount is accepted ONLY if it has:
  //   - a currency prefix (£ € $ ₹ GBP EUR USD INR Rs), OR
  //   - exactly 2 decimals (12.50 / 12,50 / 1,234.56)
  //
  // Supported number styles:
  //   1,234.56   (UK / US)
  //   12,34,567.00 (Indian lakh grouping)
  //   1.234,56   (European)
  //   3.292.62   (OCR: dots as thousands separator)
  //   50,00      (OCR comma decimal)
  //
  // Plain integers (phone numbers, GST numbers, dates, qty, "250g") are
  // ignored. Times like "9.42 PM" are removed first.
  // ---------------------------------------------------------------------
  static List<double> _parseAmounts(String s) {
    var t = s
        .replaceAll(RegExp(r'\d+(?:[.,]\d+)?\s*%'), ' ') // rates
        .replaceAll(
          RegExp(r'\b\d{1,2}[.:]\d{2}\s*(?:AM|PM)\b', caseSensitive: false),
          ' ',
        ); // times like 9.42 PM

    // NEW: 3.292.62 -> 3,292.62
    t = t.replaceAllMapped(
      RegExp(r'(?<![\d.,])(\d{1,3})\.(\d{3})\.(\d{2})(?!\d)'),
      (m) => '${m[1]},${m[2]}.${m[3]}',
    );

    t = _fixNumericTokens(t);

    // European style 1.234,56 -> 1234.56
    t = t.replaceAllMapped(
      RegExp(r'(?<![\d.,])(\d{1,3}(?:\.\d{3})+),(\d{2})(?!\d)'),
      (m) => '${m.group(1)!.replaceAll('.', '')}.${m.group(2)}',
    );

    final rx = RegExp(
      r'(?<![\d.,])'
      r'((?:£|€|\$|₹|GBP|EUR|USD|INR|Rs\.?)\s*)?'
      r'(\d{1,2}(?:,\d{2})+,\d{3}|\d{1,3}(?:,\d{3})+|\d+)'
      r'(?:[.,](\d{2})(?!\d))?',
      caseSensitive: false,
    );

    final out = <double>[];

    for (final m in rx.allMatches(t)) {
      final hasCurrency = m.group(1) != null;
      final decimal = m.group(3);

      // Plain integer with no currency symbol: not money.
      if (!hasCurrency && decimal == null) continue;

      final whole = m.group(2)!.replaceAll(',', '');
      final value = double.tryParse(
        decimal == null ? whole : '$whole.$decimal',
      );

      if (value != null) {
        out.add(value);
      }
    }

    return out;
  }

  /// Fix O/S/I/l/Z only inside tokens that already contain a digit, and never
  /// when the token is glued to a word (so the "s" in "Rs.50" is untouched).
  static String _fixNumericTokens(String s) {
    return s.replaceAllMapped(RegExp(r'(?<![A-Za-z])[0-9OoSsIlZz,.]{3,}'), (m) {
      final t = m.group(0)!;
      return RegExp(r'\d').hasMatch(t) ? _cleanNumericOcr(t) : t;
    });
  }

  static String _cleanNumericOcr(String raw) {
    return raw
        .replaceAll(RegExp(r'[Oo]'), '0')
        .replaceAll(RegExp(r'[Ss]'), '5')
        .replaceAll(RegExp(r'[Il]'), '1')
        .replaceAll(RegExp(r'[zZ]'), '2');
  }

  static double _r2(double v) => (v * 100).roundToDouble() / 100;

  // ---------------------------------------------------------------------
  // Payment term
  // ---------------------------------------------------------------------
  static String? _extractPaymentTerm(String text) {
    final match = RegExp(
      r'\bTerm[s]?\s*[:|]\s*([^\n|]+)',
      caseSensitive: false,
    ).firstMatch(text);

    if (match != null) {
      final value = match.group(1)!.trim();
      final looksLikeHeading = RegExp(
        r'^[&\s]*Condition',
        caseSensitive: false,
      ).hasMatch(value);
      if (!looksLikeHeading && value.isNotEmpty) return value;
    }

    // OCR-damaged "Payment Terms | Cash on Delivery-C" ("Paynent Ters").
    final pay = RegExp(
      r'\bPay\w{0,8}\s+Ter\w{0,2}\s*[:|]\s*([^\n|]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (pay != null) {
      final v =
          pay
              .group(1)!
              .trim()
              .replaceFirst(RegExp(r'[\s\-]+[A-Za-z]$'), '')
              .trim();
      if (v.isNotEmpty) return v;
    }

    if (RegExp(r'due on receipt', caseSensitive: false).hasMatch(text)) {
      return 'Due on receipt';
    }

    if (RegExp(r'cash\s*on\s*delivery', caseSensitive: false).hasMatch(text)) {
      return 'Cash on Delivery';
    }

    final within = RegExp(
      r'\b(?:payment\s*(?:due\s*)?)?(?:within|in)\s*(\d{1,3})\s*days\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (within != null) return 'Net ${within.group(1)}';

    final netTerm = RegExp(
      r'\bNet\s*(\d{1,3})\s*(?:days)?\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (netTerm != null) return 'Net ${netTerm.group(1)}';

    // Receipts: "Payment Mode: CASH", "Paid by UPI", "Cash | 50.00" ...
    return detectPaymentMode(text);
  }
}
