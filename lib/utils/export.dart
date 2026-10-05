import 'package:quick_scanner/features/history/model/history_model.dart';
import 'package:quick_scanner/services/invoice_exterst.dart';
import 'package:quick_scanner/services/models/scan_record.dart';
import 'package:quick_scanner/utils/helpers.dart';

String _clean(String? v) {
  final t = (v ?? '').trim();
  return (t == '—' || t == '-' || t.toUpperCase() == 'N/A') ? '' : t;
}

double? _toDouble(String? v) {
  if (v == null) return null;
  return double.tryParse(v.replaceAll(RegExp(r'[^0-9.\-]'), ''));
}

/// "2026-09-12" / "2026-09-12T00:00:00Z" -> "12 Sep 2026", anything else as-is.
String _date(InvoiceData inv) {
  final raw = _clean(inv.date?.toString());
  final src =
      raw.isNotEmpty ? raw : _clean(inv.fields.parsedHeader?.invoiceDate);
  if (src.isEmpty) return '';
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(src)) {
    final d = DateTime.tryParse(src.substring(0, 10));
    if (d != null) return formatShortDate(d);
  }
  return src;
}

/// One invoice from the API -> the exact values the "View details" dialog shows
/// (falling back to the parsed header only when the main field is empty).
ScanRecord invoiceToRecord(InvoiceData inv) {
  final h = inv.fields.parsedHeader;

  final invoiceNo =
      _clean(inv.invoiceNo).isNotEmpty
          ? _clean(inv.invoiceNo)
          : _clean(h?.invoiceNo);

  final supplier =
      _clean(inv.supplier).isNotEmpty
          ? _clean(inv.supplier)
          : _clean(h?.companyName);

  final gross = inv.gross != 0 ? inv.gross : (_toDouble(h?.grandTotal) ?? 0.0);

  var payment = _clean(paymentValues.reverse[inv.payment]);
  if (payment.isEmpty && h?.paymentTerms != null) {
    payment = _clean(paymentValues.reverse[h!.paymentTerms]);
  }
  if (payment.isEmpty) payment = _clean(inv.fields.paymentTerms);

  return ScanRecord(
    // raw OCR text lets withInvoiceFields() fill anything still missing
    text:
        inv.fields.rawText?.trim().isNotEmpty == true
            ? inv.fields.rawText!.trim()
            : inv.images
                .map((i) => i.extractedData.rawText.trim())
                .where((t) => t.isNotEmpty)
                .join('\n\n'),
    imagePath: inv.images.isNotEmpty ? inv.images.first.url : '',
    createdAt: inv.uploadedAt,
    invoiceNo: invoiceNo,
    supplier: supplier,
    date: _date(inv),
    gross: gross,
    payment: payment,
    currency: inv.currency,
  );
}

bool _blank(String? v) => _clean(v).isEmpty;

/// Guarantees invoice no / supplier / date / amount / payment / currency are
/// filled. Anything missing is read from the record's OCR text, so exports
/// never lose the values (e.g. after the text was edited, or for old scans).
ScanRecord withInvoiceFields(ScanRecord r) {
  // Currency: keep the record's own, else detect it from the OCR text.
  final currency =
      r.currency ??
      (r.text.trim().isEmpty
          ? null
          : InvoiceExtractionService.detectCurrency(r.text)) ??
      '£';

  final needs =
      _blank(r.invoiceNo) ||
      _blank(r.supplier) ||
      (r.gross ?? 0) == 0 ||
      _blank(r.date) ||
      _blank(r.payment);

  if (!needs || r.text.trim().isEmpty) {
    return ScanRecord(
      text: r.text,
      imagePath: r.imagePath,
      createdAt: r.createdAt,
      supplier: r.supplier,
      vatNumber: r.vatNumber,
      invoiceNo: r.invoiceNo,
      branch: r.branch,
      date: r.date,
      net: r.net,
      vat: r.vat,
      gross: r.gross,
      sr: r.sr,
      zr: r.zr,
      exempt: r.exempt,
      payment: r.payment,
      currency: currency,
      extractionMethod: r.extractionMethod,
      ocrStatus: r.ocrStatus,
      status: r.status,
    );
  }

  final d = InvoiceExtractionService.extract(r.text);
  String? pick(String? current, dynamic found) =>
      !_blank(current) ? current : (found?.toString());

  final g = (d['gross'] is num) ? (d['gross'] as num).toDouble() : 0.0;

  return ScanRecord(
    text: r.text,
    imagePath: r.imagePath,
    createdAt: r.createdAt,
    supplier: pick(r.supplier, d['supplier']),
    vatNumber: r.vatNumber,
    invoiceNo: pick(r.invoiceNo, d['invoice_no']),
    branch: r.branch,
    date: pick(r.date, d['date']),
    net: r.net,
    vat: r.vat,
    gross: (r.gross ?? 0) != 0 ? r.gross : (g != 0 ? g : r.gross),
    sr: r.sr,
    zr: r.zr,
    exempt: r.exempt,
    payment: pick(r.payment, d['payment']),
    currency: currency,
    extractionMethod: r.extractionMethod,
    ocrStatus: r.ocrStatus,
    status: r.status,
  );
}
