import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/routes_list.dart';
import 'package:quick_scanner/utils/common_color.dart';
import 'package:quick_scanner/utils/common_size.dart';
import 'package:quick_scanner/features/history/logic/history_controller.dart';
import 'package:quick_scanner/features/history/model/history_model.dart';
import 'package:quick_scanner/features/history/screens/view_img.dart';
import 'package:quick_scanner/features/history/screens/view_invoice.dart';

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

  static const double _statH = 78;
  static const double _overlap = _statH / 2;

  String _fmtDate(DateTime d) {
    final l = d.toLocal();
    return '${l.day} ${_months[l.month - 1]} ${l.year}';
  }

  String _fmtTime(DateTime d) {
    final l = d.toLocal();
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
          label: 'Processed',
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status-bar icons over the gradient header.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: ColorConstants.backgroundHome,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, ocr),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Sizes.w(20),
                  Sizes.h(_overlap + 22),
                  Sizes.w(20),
                  Sizes.h(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Details'),
                    SizedBox(height: Sizes.h(10)),
                    _details(),
                    SizedBox(height: Sizes.h(24)),
                    _sectionTitle('Quick actions'),
                    SizedBox(height: Sizes.h(10)),
                    _quickActions(c),
                    SizedBox(height: Sizes.h(20)),
                    // _viewButton(),
                    // SizedBox(height: MediaQuery.of(context).padding.bottom),
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

  Widget _header(
    BuildContext context,
    ({String label, Color color, IconData icon}) ocr,
  ) {
    final top = MediaQuery.of(context).padding.top;
    final supplier =
        invoice.supplier.trim().isEmpty ? 'Unknown supplier' : invoice.supplier;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            Sizes.w(20),
            top + 8,
            Sizes.w(20),
            Sizes.h(_overlap + 28),
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ColorConstants.primaryBright,
                ColorConstants.accent,
                ColorConstants.primaryDeep,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -50,
                  top: -40,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ColorConstants.white.withValues(alpha: 0.07),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Invoice Details',
                            style: TextStyle(
                              fontSize: Sizes.sp(17),
                              fontWeight: FontWeight.w700,
                              color: ColorConstants.white,
                            ),
                          ),
                        ),
                        _statusPill(ocr),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Supplier
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: ColorConstants.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: ColorConstants.white,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            supplier,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: Sizes.sp(15),
                              fontWeight: FontWeight.w600,
                              color: ColorConstants.white,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'TOTAL AMOUNT',
                      style: TextStyle(
                        color: ColorConstants.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '£${invoice.gross.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: ColorConstants.white,
                          fontSize: Sizes.sp(40),
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          letterSpacing: -0.8,
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
          left: Sizes.w(20),
          right: Sizes.w(20),
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
          width: 38,
          height: 38,
          child: Icon(icon, size: 17, color: ColorConstants.white),
        ),
      ),
    );
  }

  Widget _statusPill(({String label, Color color, IconData icon}) ocr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ColorConstants.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ocr.icon, size: 13, color: ocr.color),
          const SizedBox(width: 4),
          Text(
            ocr.label,
            style: TextStyle(
              fontSize: 11,
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ColorConstants.primaryDeep.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: _stat(
              Icons.tag_rounded,
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
              _fmtDate(invoice.uploadedAt),
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
    height: 36,
    color: ColorConstants.divider.withValues(alpha: 0.7),
  );

  Widget _stat(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: ColorConstants.textMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: ColorConstants.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: ColorConstants.textDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Details ─────────────────────────

  Widget _sectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: ColorConstants.primaryBright,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: Sizes.sp(14),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: ColorConstants.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ColorConstants.primaryDeep.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
            Icons.tag_rounded,
            'Invoice No',
            _dash(invoice.invoiceNo),
            // copyable: invoice.invoiceNo.toString().trim().isNotEmpty,
          ),
          _divider(),
          _row(
            Icons.payments_outlined,
            'Gross total',
            '£${invoice.gross.toStringAsFixed(2)}',
          ),
          _divider(),
          _row(
            Icons.cloud_upload_outlined,
            'Uploaded',
            '${_fmtDate(invoice.uploadedAt)} · ${_fmtTime(invoice.uploadedAt)}',
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
    height: 1,
    indent: 44,
    color: ColorConstants.divider.withValues(alpha: 0.6),
  );

  Widget _row(
    IconData icon,
    String label,
    String value, {
    bool copyable = false,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ColorConstants.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: ColorConstants.primaryBright),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: ColorConstants.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                color: ColorConstants.textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (copyable) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.copy_rounded,
              size: 15,
              color: ColorConstants.textMuted,
            ),
          ],
        ],
      ),
    );

    if (!copyable) return content;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.selectionClick();
        Clipboard.setData(ClipboardData(text: value));
        Get.snackbar(
          'Copied',
          '$label copied to clipboard',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        );
      },
      child: content,
    );
  }

  // ───────────────────────── Actions ─────────────────────────

  Widget _quickActions(HistoryController c) {
    final hasImages = invoice.images.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: _actionTile(
            Icons.image_outlined,
            'Images',
            hasImages ? '${invoice.images.length} attached' : 'None',
            hasImages
                ? () => Get.dialog(InvoiceImagesDialog(invoice: invoice))
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionTile(
            Icons.file_download_outlined,
            'Download',
            'CSV',
            () => c.downloadInvoice(invoice.id, format: 'csv'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionTile(Icons.edit_outlined, 'Edit', 'Raw text', () async {
            await Get.toNamed(
              RouteList.editRawText,
              arguments: {
                'invoice': invoice,
                'initialText': c.rawTextOf(invoice),
                'onSave': (String text) => c.updateRawText(invoice.id, text),
              },
            );
            c.refreshList();
          }),
        ),
      ],
    );
  }

  Widget _actionTile(
    IconData icon,
    String label,
    String sub,
    VoidCallback? onTap,
  ) {
    final enabled = onTap != null;
    final fg =
        enabled ? ColorConstants.primaryBright : ColorConstants.textMuted;

    return Material(
      color: ColorConstants.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap:
            onTap == null
                ? null
                : () {
                  HapticFeedback.lightImpact();
                  onTap();
                },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  enabled
                      ? ColorConstants.primaryBright.withValues(alpha: 0.25)
                      : ColorConstants.divider,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      enabled
                          ? ColorConstants.primarySoft
                          : ColorConstants.divider.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 21, color: fg),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                      enabled
                          ? ColorConstants.textDark
                          : ColorConstants.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: ColorConstants.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Full-width primary action at the end of the page (replaces the old
  /// bottom bar, so "View Full Invoice" stays reachable).
  Widget _viewButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: () => Get.dialog(InvoiceViewDialog(invoice: invoice)),
        icon: const Icon(Icons.visibility_outlined, size: 20),
        label: const Text('View Full Invoice'),
        style: FilledButton.styleFrom(
          backgroundColor: ColorConstants.primaryBright,
          foregroundColor: ColorConstants.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}
