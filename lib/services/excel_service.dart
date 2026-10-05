import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quick_scanner/utils/export.dart';
import 'package:quick_scanner/utils/helper_widget.dart';
import 'package:quick_scanner/utils/helpers.dart';
import 'package:share_plus/share_plus.dart';

import 'models/scan_record.dart';

class ExcelService {
  // The symbol is written in each amount cell, so the header is just "Amount".
  static const _headers = ['Invoice No', 'Supplier', 'Date', 'Amount'];

  /// null / '' / '—' / '-' -> 'N/A'
  static String _na(String? v) {
    final t = (v ?? '').trim();
    return (t.isEmpty || t == '—' || t == '-') ? 'N/A' : t;
  }

  static Future<void> exportAndShareRecords(List<ScanRecord> input) async {
    final records = input.map(withInvoiceFields).toList();
    if (records.isEmpty) {
      throw Exception('No invoices available to export');
    }

    final excel = Excel.createExcel();
    final sheet = excel['Invoices'];
    if (excel.sheets.containsKey('Sheet1') && excel.sheets.length > 1) {
      excel.delete('Sheet1');
    }

    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final textStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final amountStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );
    final totalStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    for (var c = 0; c < _headers.length; c++) {
      _set(sheet, c, 0, TextCellValue(_headers[c]), headerStyle);
    }

    var row = 1;
    final totals = <String, double>{}; // total per currency
    for (final r in records) {
      final symbol = r.currency ?? '£';
      _set(sheet, 0, row, TextCellValue(_na(r.invoiceNo)), textStyle);
      _set(sheet, 1, row, TextCellValue(_na(r.supplier)), textStyle);
      _set(sheet, 2, row, TextCellValue(_na(recordDate(r))), textStyle);
      if ((r.gross ?? 0) != 0) {
        totals[symbol] = (totals[symbol] ?? 0) + r.gross!;
        _set(
          sheet,
          3,
          row,
          TextCellValue(formatMoney(r.gross!, symbol: symbol)),
          amountStyle,
        );
      } else {
        _set(sheet, 3, row, TextCellValue('N/A'), amountStyle);
      }
      row++;
    }

    // Never add £ and ₹ together: one total row per currency.
    if (totals.isEmpty) {
      _set(sheet, 2, row, TextCellValue('Total'), totalStyle);
      _set(sheet, 3, row, TextCellValue('N/A'), totalStyle);
    } else {
      for (final e in totals.entries) {
        _set(
          sheet,
          2,
          row,
          TextCellValue(totals.length == 1 ? 'Total' : 'Total (${e.key})'),
          totalStyle,
        );
        _set(
          sheet,
          3,
          row,
          TextCellValue(formatMoney(e.value, symbol: e.key)),
          totalStyle,
        );
        row++;
      }
    }

    sheet.setColumnWidth(0, 22);
    sheet.setColumnWidth(1, 36);
    sheet.setColumnWidth(2, 16);
    sheet.setColumnWidth(3, 18);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Unable to create Excel file');

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/Scanwoo_invoices.xlsx');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([
      XFile(
        file.path,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
    ], text: 'Invoice data');
  }

  static void _set(
    Sheet sheet,
    int column,
    int row,
    CellValue value,
    CellStyle style,
  ) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
    );
    cell.value = value;
    cell.cellStyle = style;
  }
}
