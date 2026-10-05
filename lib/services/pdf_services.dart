import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:quick_scanner/utils/export.dart';
import 'package:quick_scanner/utils/helper_widget.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/helpers.dart';
import 'models/scan_record.dart';

class PdfService {
  static const _headers = ['S.no', 'Invoice No', 'Supplier', 'Date', 'Amount'];

  /// null / '' / '—' / '-' -> 'N/A'
  static String _na(String? v) {
    final t = (v ?? '').trim();
    return (t.isEmpty || t == '—' || t == '-') ? 'N/A' : t;
  }

  static Future<void> exportAndShareRecords(List<ScanRecord> input) async {
    final records = input.map(withInvoiceFields).toList();
    if (records.isEmpty) {
      throw Exception('No documents available to export');
    }

    // Noto Sans has the ₹ glyph (Helvetica does not).
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    // Total per currency (never add £ and ₹ together), same as the Excel.
    final totals = <String, double>{};
    for (final r in records) {
      final g = r.gross ?? 0;
      if (g == 0) continue;
      final c = r.currency ?? '£';
      totals[c] = (totals[c] ?? 0) + g;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header:
            (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Invoice Report',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generated ${formatShortDate(DateTime.now())}  |  '
                  '${records.length} invoice${records.length == 1 ? '' : 's'}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 10),
              ],
            ),
        footer:
            (ctx) => pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ),
        build:
            (_) => [
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(36), // S.no
                  1: const pw.FlexColumnWidth(2.6), // Invoice No
                  2: const pw.FlexColumnWidth(3.4), // Supplier
                  3: const pw.FlexColumnWidth(2.2), // Date
                  4: const pw.FlexColumnWidth(2.4), // Amount
                },
                defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: [
                  // ---- Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      for (var c = 0; c < _headers.length; c++)
                        _cell(
                          _headers[c],
                          bold: true,
                          center: c == 0,
                          right: c == 4,
                        ),
                    ],
                  ),
                  // ---- Rows
                  for (var i = 0; i < records.length; i++)
                    pw.TableRow(
                      children: [
                        _cell('${i + 1}', center: true),
                        _cell(_na(records[i].invoiceNo)),
                        _cell(_na(records[i].supplier)),
                        _cell(recordDate(records[i])),
                        _cell(
                          records[i].gross == null || records[i].gross == 0
                              ? 'N/A'
                              : formatMoney(
                                records[i].gross!,
                                symbol: records[i].currency ?? '£',
                              ),
                          right: true,
                        ),
                      ],
                    ),
                  // ---- Totals (one row per currency, like the Excel)
                  if (totals.isEmpty)
                    _totalRow('Total', 'N/A')
                  else
                    for (final e in totals.entries)
                      _totalRow(
                        totals.length == 1 ? 'Total' : 'Total (${e.key})',
                        formatMoney(e.value, symbol: e.key),
                      ),
                ],
              ),
            ],
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/Scanwoo_invoices.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);

    await Share.shareXFiles([XFile(file.path)], text: 'Invoice Report');
  }

  static pw.TableRow _totalRow(String label, String amount) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(label, bold: true, right: true),
        _cell(amount, bold: true, right: true),
      ],
    );
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    bool right = false,
    bool center = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign:
            center
                ? pw.TextAlign.center
                : (right ? pw.TextAlign.right : pw.TextAlign.left),
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
