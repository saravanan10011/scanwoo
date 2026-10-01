import 'package:quick_scanner/utils/common_color.dart';
import 'package:quick_scanner/utils/common_size.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/features/history/model/history_model.dart';

const primary = ColorConstants.primary;
const primaryDark = ColorConstants.primaryDark;
const primaryLight = ColorConstants.primaryLight;
const background = ColorConstants.background;

class InvoiceViewDialog extends StatelessWidget {
  final InvoiceData invoice;
  const InvoiceViewDialog({super.key, required this.invoice});

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sept',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${l.day} ${_months[l.month - 1]} ${l.year}';
  }

  String _dash(String? v) => (v == null || v.trim().isEmpty) ? '—' : v;

  ({String label, Color color}) _ocr() {
    final raw = invoice.ocrStatus.toString().split('.').last.toLowerCase();
    switch (raw) {
      case 'complete':
      case 'done':
        return (label: 'Done', color: ColorConstants.blue);
      case 'failed':
      case 'error':
        return (label: 'Failed', color: ColorConstants.redAccent);
      default:
        return (label: 'Pending', color: ColorConstants.warning);
    }
  }

  // invoice_no -> Invoice No, supplierName -> Supplier Name, items.0 -> Items 0
  String _pretty(String key) {
    final spaced =
        key
            .replaceAllMapped(
              RegExp(r'([a-z0-9])([A-Z])'),
              (m) => '${m[1]} ${m[2]}',
            )
            .replaceAll(RegExp(r'[._]+'), ' ')
            .trim();
    return spaced
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  // Flattens Fields into label/value rows, skipping empty values
  List<MapEntry<String, String>> _scannedRows() {
    final rows = <MapEntry<String, String>>[];

    void add(String key, dynamic v) {
      if (v == null) return;
      if (v is bool) {
        rows.add(MapEntry(key, v ? 'Yes' : 'No'));
      } else if (v is Map) {
        v.forEach((k, val) => add('$key.$k', val));
      } else if (v is List) {
        if (v.isEmpty) return;
        final lines = v
            .map((e) {
              if (e is Map) {
                final qty = e['qty'] ?? '';
                final desc = e['description'] ?? '';
                final amt = e['amount'] ?? '';
                return '$qty × $desc — $amt';
              }
              return '$e';
            })
            .join('\n');
        rows.add(MapEntry(key, lines));
      } else {
        final s = v.toString().trim();
        if (s.isNotEmpty) rows.add(MapEntry(key, s));
      }
    }

    invoice.fields.toJson().forEach(add);
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final ocr = _ocr();
    final rows = _scannedRows();

    return Dialog(
      backgroundColor: ColorConstants.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: Sizes.w(16),
        vertical: Sizes.h(40),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.w(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: Sizes.hp(0.86)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(ocr),

            // ---- Body
            Flexible(
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    Sizes.w(18),
                    Sizes.h(4),
                    Sizes.w(18),
                    Sizes.h(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heroCard(),
                      SizedBox(height: Sizes.h(18)),
                      _sectionTitle('INVOICE SUMMARY'),
                      _card(
                        children: [
                          _summaryRow(
                            Icons.receipt_long_rounded,
                            'Invoice Number',
                            _dash(invoice.invoiceNo),
                          ),
                          _summaryRow(
                            Icons.storefront_outlined,
                            'Supplier',
                            _dash(invoice.supplier),
                          ),
                          _summaryRow(
                            Icons.event_outlined,
                            'Invoice Date',
                            _dash(invoice.date?.toString()),
                            last: true,
                          ),
                        ],
                      ),
                      if (rows.isNotEmpty) ...[
                        SizedBox(height: Sizes.h(18)),
                        _scannedSection(rows),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            _footer(),
          ],
        ),
      ),
    );
  }

  // ---- Header
  Widget _header(({String label, Color color}) ocr) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Sizes.w(18),
        Sizes.h(14),
        Sizes.w(8),
        Sizes.h(12),
      ),
      child: Row(
        children: [
          Container(
            width: Sizes.w(40),
            height: Sizes.w(40),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(Sizes.w(12)),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: Sizes.w(20),
              color: primary,
            ),
          ),
          SizedBox(width: Sizes.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice ${invoice.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Sizes.sp(16),
                    fontWeight: FontWeight.w800,
                    color: ColorConstants.textDark,
                  ),
                ),
                SizedBox(height: Sizes.h(2)),
                Text(
                  'Uploaded ${_fmt(invoice.uploadedAt)}',
                  style: TextStyle(
                    fontSize: Sizes.sp(12),
                    color: ColorConstants.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: Sizes.w(10),
              vertical: Sizes.h(4),
            ),
            decoration: BoxDecoration(
              color: ocr.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Sizes.w(20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: Sizes.w(6),
                  height: Sizes.w(6),
                  decoration: BoxDecoration(
                    color: ocr.color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: Sizes.w(5)),
                Text(
                  ocr.label,
                  style: TextStyle(
                    fontSize: Sizes.sp(11),
                    fontWeight: FontWeight.w700,
                    color: ocr.color,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: Get.back,
            icon: Icon(
              Icons.close_rounded,
              size: Sizes.w(22),
              color: ColorConstants.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Hero amount card
  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Sizes.w(18)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, primaryDark],
        ),
        borderRadius: BorderRadius.circular(Sizes.w(18)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GROSS AMOUNT',
            style: TextStyle(
              fontSize: Sizes.sp(10.5),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: Sizes.h(6)),
          Text(
            invoice.gross.toStringAsFixed(2),
            style: TextStyle(
              fontSize: Sizes.sp(28),
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: Sizes.h(10)),
          Row(
            children: [
              Icon(
                Icons.storefront_outlined,
                size: Sizes.w(15),
                color: Colors.white70,
              ),
              SizedBox(width: Sizes.w(6)),
              Expanded(
                child: Text(
                  _dash(invoice.supplier),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Sizes.sp(13),
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Section helpers
  Widget _sectionTitle(String t) {
    return Padding(
      padding: EdgeInsets.only(bottom: Sizes.h(8), left: Sizes.w(2)),
      child: Text(
        t,
        style: TextStyle(
          fontSize: Sizes.sp(10.5),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: ColorConstants.textMuted,
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Sizes.w(14)),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Sizes.w(16)),
      ),
      child: Column(children: children),
    );
  }

  Widget _summaryRow(
    IconData icon,
    String label,
    String value, {
    bool last = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: Sizes.h(12)),
      decoration: BoxDecoration(
        border:
            last
                ? null
                : const Border(
                  bottom: BorderSide(color: ColorConstants.divider),
                ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: Sizes.w(32),
            height: Sizes.w(32),
            decoration: BoxDecoration(
              color: ColorConstants.white,
              borderRadius: BorderRadius.circular(Sizes.w(10)),
            ),
            child: Icon(icon, size: Sizes.w(16), color: primary),
          ),
          SizedBox(width: Sizes.w(12)),
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: Sizes.sp(12.5),
                color: ColorConstants.textMuted,
              ),
            ),
          ),
          SizedBox(width: Sizes.w(8)),
          Expanded(
            flex: 6,
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: Sizes.sp(13),
                fontWeight: FontWeight.w700,
                color: ColorConstants.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Collapsible scanned fields
  Widget _scannedSection(List<MapEntry<String, String>> rows) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Sizes.w(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: Sizes.w(14)),
          childrenPadding: EdgeInsets.fromLTRB(
            Sizes.w(14),
            0,
            Sizes.w(14),
            Sizes.h(8),
          ),
          iconColor: primary,
          collapsedIconColor: ColorConstants.textMuted,
          title: Row(
            children: [
              Text(
                'ALL SCANNED FIELDS',
                style: TextStyle(
                  fontSize: Sizes.sp(10.5),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: ColorConstants.textMuted,
                ),
              ),
              SizedBox(width: Sizes.w(8)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Sizes.w(8),
                  vertical: Sizes.h(2),
                ),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Sizes.w(20)),
                ),
                child: Text(
                  '${rows.length}',
                  style: TextStyle(
                    fontSize: Sizes.sp(10.5),
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
          children: [
            for (var i = 0; i < rows.length; i++)
              _fieldRow(
                _pretty(rows[i].key),
                rows[i].value,
                last: i == rows.length - 1,
              ),
          ],
        ),
      ),
    );
  }

  Widget _fieldRow(String label, String value, {bool last = false}) {
    final isLong = value.length > 38 || value.contains('\n');

    final labelText = Text(
      label,
      style: TextStyle(fontSize: Sizes.sp(12), color: ColorConstants.textMuted),
    );
    final valueText = SelectableText(
      value,
      textAlign: isLong ? TextAlign.start : TextAlign.end,
      style: TextStyle(
        fontSize: Sizes.sp(13),
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: ColorConstants.textDark,
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(vertical: Sizes.h(10)),
      decoration: BoxDecoration(
        border:
            last
                ? null
                : const Border(top: BorderSide(color: ColorConstants.divider)),
      ),
      child:
          isLong
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [labelText, SizedBox(height: Sizes.h(6)), valueText],
              )
              : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: labelText),
                  SizedBox(width: Sizes.w(12)),
                  Expanded(flex: 6, child: valueText),
                ],
              ),
    );
  }

  // ---- Footer
  Widget _footer() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Sizes.w(18),
        Sizes.h(10),
        Sizes.w(18),
        Sizes.h(16),
      ),
      decoration: const BoxDecoration(
        color: ColorConstants.white,
        border: Border(top: BorderSide(color: ColorConstants.divider)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: Sizes.h(48),
        child: FilledButton(
          onPressed: Get.back,
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: ColorConstants.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Sizes.w(14)),
            ),
          ),
          child: Text(
            'Close',
            style: TextStyle(
              fontSize: Sizes.sp(14),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
