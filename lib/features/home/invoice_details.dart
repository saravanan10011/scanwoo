import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/utils/common_color.dart';
import 'package:quick_scanner/features/history/logic/history_controller.dart';
import 'package:quick_scanner/features/history/model/history_model.dart';
import 'package:quick_scanner/features/history/screens/view_img.dart';
import 'package:quick_scanner/features/history/screens/view_invoice.dart';
import 'package:quick_scanner/utils/helpers.dart';

// ───────────────── Responsive helpers (375 x 812 baseline) ─────────────────
double _sw(double v) => Get.width / 375 * v;
double _sh(double v) => Get.height / 812 * v;

/// Font / icon scaling: follows width but is clamped so tablets don't get giant text.
double _sp(double v) => v * (Get.width / 375).clamp(0.85, 1.3);

/// Opens the individual invoice screen.
void openInvoiceDetail(InvoiceData inv) {
  Get.to(() => InvoiceDetailScreen(invoice: inv));
}

class InvoiceDetailScreen extends StatelessWidget {
  final InvoiceData invoice;
  const InvoiceDetailScreen({super.key, required this.invoice});

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  double get _statH => _sh(78);
  double get _overlap => _statH / 2;

  String _fmtDate(DateTime d) {
    final l = d.toLocal();
    return '${l.day} ${_months[l.month - 1]} ${l.year}';
  }

  String _fmtTime(DateTime d) {
    // final l = d.toLocal();
    final l = toUkTime(d);

    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final m = l.minute.toString().padLeft(2, '0');
    final ap = l.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  String _dash(String? v) => (v == null || v.trim().isEmpty) ? '—' : v;

  ({String label, Color color, IconData icon}) _ocr() {
    final raw = invoice.ocrStatus.toString().split('.').last.toLowerCase();
    switch (raw) {
      case 'complete':
      case 'done':
        return (
          label: 'Done',
          color: ColorConstants.blue,
          icon: Icons.check_circle_rounded,
        );
      case 'failed':
      case 'error':
        return (
          label: 'Failed',
          color: ColorConstants.redAccent,
          icon: Icons.error_rounded,
        );
      default:
        return (
          label: 'Pending',
          color: ColorConstants.warning,
          icon: Icons.schedule_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<HistoryController>();
    final ocr = _ocr();
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status-bar icons over the gradient header.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: ColorConstants.backgroundHome,
        body: SingleChildScrollView(
          // physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, ocr),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _sw(20),
                  _overlap + _sh(24),
                  _sw(20),
                  _sh(24) + bottomInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Details'),
                    SizedBox(height: _sh(12)),
                    _details(),
                    SizedBox(height: _sh(26)),
                    _sectionTitle('Quick actions'),
                    SizedBox(height: _sh(12)),
                    _quickActions(c),
                    SizedBox(height: _sh(20)),
                    // _viewButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Header ─────────────────────────
  /// Upload moment in the device's local time (from uploaded_at_iso).
  DateTime? get _uploadedLocal {
    final iso = invoice.uploadedAtIso.trim();
    if (iso.isEmpty) return null;
    return DateTime.tryParse(iso)?.toLocal();
  }

  String get _uploadedDate {
    final d = _uploadedLocal;
    if (d != null) return _fmtDate(d);
    return _fmtDate(invoice.uploadedAt);
  }

  String get _uploadedTime {
    final d = _uploadedLocal;
    return d != null ? _fmtTime(d) : '';
  }

  Widget _stat(IconData icon, String label, String value, {String sub = ''}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _sw(8)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: _sp(12), color: ColorConstants.textMuted),
              SizedBox(width: _sw(4)),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _sp(11),
                    color: ColorConstants.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: _sh(6)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _sp(13.5),
                color: ColorConstants.textDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (sub.isNotEmpty) ...[
            SizedBox(height: _sh(2)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                sub,
                maxLines: 1,
                style: TextStyle(
                  fontSize: _sp(11),
                  color: ColorConstants.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _header(
    BuildContext context,
    ({String label, Color color, IconData icon}) ocr,
  ) {
    final top = MediaQuery.of(context).padding.top;
    final supplier =
        invoice.supplier.trim().isEmpty ? 'Unknown supplier' : invoice.supplier;
    final radius = _sw(32);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            _sw(20),
            top + _sh(10),
            _sw(20),
            _overlap + _sh(30),
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                ColorConstants.primaryBright,
                ColorConstants.accent,
                ColorConstants.primaryDeep,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(radius),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(radius),
            ),
            child: Stack(
              children: [
                // Decorative circles
                Positioned(
                  right: -_sw(50),
                  top: -_sh(40),
                  child: Container(
                    width: _sw(150),
                    height: _sw(150),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ColorConstants.white.withValues(alpha: 0.07),
                    ),
                  ),
                ),
                Positioned(
                  left: -_sw(40),
                  bottom: -_sh(50),
                  child: Container(
                    width: _sw(110),
                    height: _sw(110),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ColorConstants.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar: back • title • status
                    Row(
                      children: [
                        _circleButton(
                          Icons.arrow_back_ios_new_rounded,
                          Get.back,
                        ),
                        SizedBox(width: _sw(12)),
                        Expanded(
                          child: Text(
                            'Invoice Details',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: _sp(17),
                              fontWeight: FontWeight.w700,
                              color: ColorConstants.white,
                            ),
                          ),
                        ),
                        _statusPill(ocr),
                      ],
                    ),
                    SizedBox(height: _sh(24)),
                    // Supplier
                    Row(
                      children: [
                        Container(
                          width: _sw(42),
                          height: _sw(42),
                          decoration: BoxDecoration(
                            color: ColorConstants.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(_sw(12)),
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: ColorConstants.white,
                            size: _sp(22),
                          ),
                        ),
                        SizedBox(width: _sw(12)),
                        Expanded(
                          child: Text(
                            supplier,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: _sp(15),
                              fontWeight: FontWeight.w600,
                              color: ColorConstants.white,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: _sh(22)),
                    Padding(
                      padding: EdgeInsets.only(left: Get.width * 0.04),
                      child: Text(
                        'TOTAL AMOUNT',
                        style: TextStyle(
                          color: ColorConstants.white70,
                          fontSize: _sp(11.5),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    SizedBox(height: _sh(6)),
                    Padding(
                      padding: EdgeInsets.only(left: Get.width * 0.04),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          invoice.grossFormatted,

                          style: TextStyle(
                            color: ColorConstants.white,
                            fontSize: _sp(30),
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: _sw(20),
          right: _sw(20),
          bottom: -_overlap,
          child: _statsCard(),
        ),
      ],
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: ColorConstants.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: _sw(40),
          height: _sw(40),
          child: Icon(icon, size: _sp(17), color: ColorConstants.white),
        ),
      ),
    );
  }

  Widget _statusPill(({String label, Color color, IconData icon}) ocr) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _sw(10), vertical: _sh(5)),
      decoration: BoxDecoration(
        color: ColorConstants.white,
        borderRadius: BorderRadius.circular(_sw(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ocr.icon, size: _sp(13), color: ocr.color),
          SizedBox(width: _sw(4)),
          Text(
            ocr.label,
            style: TextStyle(
              fontSize: _sp(11),
              fontWeight: FontWeight.w700,
              color: ocr.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsCard() {
    return Container(
      height: _statH,
      decoration: BoxDecoration(
        color: ColorConstants.white,
        borderRadius: BorderRadius.circular(_sw(20)),
        boxShadow: [
          BoxShadow(
            color: ColorConstants.primaryDeep.withValues(alpha: 0.14),
            blurRadius: _sw(20),
            offset: Offset(0, _sh(8)),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: _stat(
              Icons.receipt_long_rounded,
              'Invoice No',
              _dash(invoice.invoiceNo),
            ),
          ),
          _vDivider(),
          Expanded(
            flex: 5,
            child: _stat(
              Icons.calendar_today_rounded,
              'Uploaded',
              _uploadedDate,
              sub: _uploadedTime,
            ),
          ),
          _vDivider(),
          Expanded(
            flex: 3,
            child: _stat(
              Icons.photo_library_outlined,
              'Images',
              '${invoice.images.length}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
    width: 1,
    height: _sh(36),
    color: ColorConstants.divider.withValues(alpha: 0.7),
  );

  // ───────────────────────── Details ─────────────────────────

  Widget _sectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: _sw(4),
          height: _sh(16),
          decoration: BoxDecoration(
            color: ColorConstants.primaryBright,
            borderRadius: BorderRadius.circular(_sw(2)),
          ),
        ),
        SizedBox(width: _sw(8)),
        Text(
          text,
          style: TextStyle(
            fontSize: _sp(14.5),
            fontWeight: FontWeight.w800,
            color: ColorConstants.textDark,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _details() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _sw(14), vertical: _sh(4)),
      decoration: BoxDecoration(
        color: ColorConstants.white,
        borderRadius: BorderRadius.circular(_sw(20)),
        boxShadow: [
          BoxShadow(
            color: ColorConstants.primaryDeep.withValues(alpha: 0.06),
            blurRadius: _sw(14),
            offset: Offset(0, _sh(4)),
          ),
        ],
      ),
      child: Column(
        children: [
          _row(
            Icons.storefront_outlined,
            'Supplier',
            _dash(invoice.supplier),
            // copyable: invoice.supplier.trim().isNotEmpty,
          ),
          _divider(),
          _row(
            Icons.receipt_long_rounded,
            'Invoice No',
            _dash(invoice.invoiceNo),
            // copyable: invoice.invoiceNo.toString().trim().isNotEmpty,
          ),
          _divider(),
          _row(Icons.payments_outlined, 'Gross total', invoice.grossFormatted),
          _divider(),
          _row(
            Icons.cloud_upload_outlined,
            'Uploaded',

            // _fmtDate(invoice.uploadedAt),
            '${_fmtDate(invoice.uploadedAt)} · ${_fmtTime(invoice.uploadedAt)}',
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
    height: 1,
    indent: _sw(44),
    color: ColorConstants.divider.withValues(alpha: 0.6),
  );

  Widget _row(
    IconData icon,
    String label,
    String value, {
    bool copyable = false,
  }) {
    final content = Padding(
      padding: EdgeInsets.symmetric(vertical: _sh(13)),
      child: Row(
        children: [
          Container(
            width: _sw(34),
            height: _sw(34),
            decoration: BoxDecoration(
              color: ColorConstants.primarySoft,
              borderRadius: BorderRadius.circular(_sw(10)),
            ),
            child: Icon(
              icon,
              size: _sp(17),
              color: ColorConstants.primaryBright,
            ),
          ),
          SizedBox(width: _sw(12)),
          Text(
            label,
            style: TextStyle(
              fontSize: _sp(12.5),
              color: ColorConstants.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: _sw(12)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: _sp(13.5),
                color: ColorConstants.textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (copyable) ...[
            SizedBox(width: _sw(8)),
            Icon(
              Icons.copy_rounded,
              size: _sp(15),
              color: ColorConstants.textMuted,
            ),
          ],
        ],
      ),
    );

    if (!copyable) return content;

    return InkWell(
      borderRadius: BorderRadius.circular(_sw(12)),
      onTap: () {
        HapticFeedback.selectionClick();
        Clipboard.setData(ClipboardData(text: value));
        Get.snackbar(
          'Copied',
          '$label copied to clipboard',
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(_sw(16)),
          duration: const Duration(seconds: 2),
        );
      },
      child: content,
    );
  }

  // ───────────────────────── Quick actions ─────────────────────────
  Widget _quickActions(HistoryController c) {
    final count = invoice.images.length;
    final hasImages = count > 0;

    return _actionCard(
      icon: Icons.photo_library_outlined,
      title: 'Invoice images',
      subtitle:
          hasImages
              ? '$count ${count == 1 ? 'image' : 'images'} attached'
              : 'No images attached',
      onTap:
          hasImages
              ? () => Get.dialog(InvoiceImagesDialog(invoice: invoice))
              : null,
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    final fg =
        enabled ? ColorConstants.primaryBright : ColorConstants.textMuted;
    final r = BorderRadius.circular(_sw(20));

    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: ColorConstants.primaryDeep.withValues(alpha: 0.06),
            blurRadius: _sw(14),
            offset: Offset(0, _sh(4)),
          ),
        ],
      ),
      child: Material(
        color: ColorConstants.white,
        borderRadius: r,
        child: InkWell(
          borderRadius: r,
          onTap:
              enabled
                  ? () {
                    HapticFeedback.lightImpact();
                    onTap();
                  }
                  : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _sw(14),
              vertical: _sh(14),
            ),
            child: Row(
              children: [
                Container(
                  width: _sw(48),
                  height: _sw(48),
                  decoration: BoxDecoration(
                    color:
                        enabled
                            ? ColorConstants.primarySoft
                            : ColorConstants.divider.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(_sw(14)),
                  ),
                  child: Icon(icon, size: _sp(23), color: fg),
                ),
                SizedBox(width: _sw(14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _sp(14.5),
                          fontWeight: FontWeight.w700,
                          color:
                              enabled
                                  ? ColorConstants.textDark
                                  : ColorConstants.textMuted,
                        ),
                      ),
                      SizedBox(height: _sh(3)),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _sp(12),
                          fontWeight: FontWeight.w500,
                          color: ColorConstants.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: _sw(8)),
                Container(
                  width: _sw(32),
                  height: _sw(32),
                  decoration: BoxDecoration(
                    color:
                        enabled
                            ? ColorConstants.primarySoft
                            : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: _sp(14),
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _viewButton() {
    return SizedBox(
      width: double.infinity,
      height: _sh(54),
      child: FilledButton.icon(
        onPressed: () => Get.dialog(InvoiceViewDialog(invoice: invoice)),
        icon: Icon(Icons.visibility_outlined, size: _sp(20)),
        label: const Text('View Full Invoice'),
        style: FilledButton.styleFrom(
          backgroundColor: ColorConstants.primaryBright,
          foregroundColor: ColorConstants.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_sw(16)),
          ),
          textStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: _sp(15)),
        ),
      ),
    );
  }
}
