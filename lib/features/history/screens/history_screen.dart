import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/features/history/logic/history_controller.dart';
import 'package:quick_scanner/features/history/model/history_model.dart';
import 'package:quick_scanner/features/history/screens/sub_screen/edit_screen.dart';
import 'package:quick_scanner/features/history/screens/view_img.dart';
import 'package:quick_scanner/features/history/screens/view_invoice.dart';

const primary = Color(0xFF4038D8);
const primaryDark = Color(0xFF2C2AC0);
const primaryLight = Color(0xFF6C63FF);
const background = Color(0xFFF5F7FB);
const _textDark = Color(0xFF1A1B25);
const _textMuted = Color(0xFF8B8D98);
const _cardIconBg = Color(0xFFEDEDFF);
const _divider = Color(0xFFE7E8F2);

const _maxContentWidth = 720.0;

/// One scale factor for everything. Based on width only (never height), so
/// landscape / split-screen / tablets don't blow the layout up.
double _k() => (Get.width / 375).clamp(0.9, 1.25);
double _sw(double px) => px * _k();
double _sh(double px) => px * _k();
double _sp(double px) => px * _k();

class ScanHistoryScreen extends StatelessWidget {
  final VoidCallback? onBack;
  ScanHistoryScreen({super.key, this.onBack});

  final c = Get.put(HistoryController());

  static const _filters = [
    ('All', Icons.apps_rounded),
    ('Today', Icons.today_rounded),
    ('This Week', Icons.date_range_rounded),
    ('This Month', Icons.calendar_month_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Centre content on tablets / landscape, normal gutter on phones.
    final side =
        width > _maxContentWidth + 32
            ? (width - _maxContentWidth) / 2
            : _sw(16);
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: primary,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      // Keep big system font sizes from breaking cards.
      child: MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.3,
        child: Scaffold(
          backgroundColor: background,
          body: Column(
            children: [
              // Solid status-bar area so icons stay readable while scrolling.
              Container(height: topInset, color: primary),
              Expanded(child: Obx(() => _body(side))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(double side) {
    final list = c.filtered; // all matches
    final pageList = c.paged; // only 7
    final cur = c.safePage;
    final pages = c.totalPages;
    final grouped = c.grouped(pageList);
    final total = c.invoices.length;
    final searching = c.query.value.trim().isNotEmpty;
    final isFiltered = searching || c.filter.value != 'All';
    final loadingFirst = c.isLoading.value && c.invoices.isEmpty;
    final offset = (cur - 1) * HistoryController.perPage;

    final serials = <dynamic, int>{
      for (var i = 0; i < pageList.length; i++) pageList[i].id: offset + i + 1,
    };
    final rows = <Object>[];
    for (final e in grouped.entries) {
      rows.add((e.key, e.value.length));
      rows.addAll(e.value);
    }

    return RefreshIndicator(
      color: primary,
      onRefresh: c.fetchInvoices,
      child: CustomScrollView(
        controller: c.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Title block (scrolls away)
          SliverToBoxAdapter(
            child: _titleBlock(total, list.length, isFiltered, side),
          ),
          // Search + filters (pinned)
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedBar(
              extent: _sh(8 + 48 + 12 + 36 + 16),
              child: Padding(
                padding: EdgeInsets.fromLTRB(side, _sh(8), side, _sh(16)),
                child: Column(
                  children: [
                    SizedBox(height: _sh(48), child: _searchBar()),
                    SizedBox(height: _sh(12)),
                    SizedBox(height: _sh(36), child: _filterChips()),
                  ],
                ),
              ),
            ),
          ),
          if (loadingFirst)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, _sh(16), side, 0),
              sliver: SliverList.separated(
                itemCount: 5,
                separatorBuilder: (_, _) => SizedBox(height: _sh(12)),
                itemBuilder: (_, _) => const _SkeletonCard(),
              ),
            )
          else if (list.isEmpty)
            SliverToBoxAdapter(child: _emptyState(searching))
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, _sh(16), side, _sh(24)),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final r = rows[i];
                  if (r is (String, int)) {
                    return Padding(
                      padding: EdgeInsets.only(
                        top: i == 0 ? 0 : _sh(10),
                        bottom: _sh(10),
                      ),
                      child: _sectionLabel(r.$1, r.$2),
                    );
                  }
                  final inv = r as InvoiceData;
                  return Padding(
                    padding: EdgeInsets.only(bottom: _sh(12)),
                    child: _InvoiceCard(
                      serial: serials[inv.id] ?? i,
                      invoice: inv,
                      onView: () => Get.dialog(InvoiceViewDialog(invoice: inv)),
                      onImages:
                          () => Get.dialog(InvoiceImagesDialog(invoice: inv)),
                      // was hard-coded to 104 -> use the tapped invoice
                      onDownload: () => c.downloadInvoicePdf(inv.id),
                      onEdit:
                          () => Get.to(
                            () => EditRawTextScreen(
                              invoice: inv,
                              initialText: c.rawTextOf(inv),
                              onSave: (text) => c.updateRawText(inv.id, text),
                            ),
                          ),
                    ),
                  );
                },
              ),
            ),
          if (c.isLoadingMore.value)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(_sw(16)),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: primary,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: _sh(16))),
          if (list.isNotEmpty && pages > 1)
            SliverToBoxAdapter(
              child: _paginationBar(side, cur, pages, offset, list.length),
            ),
        ],
      ),
    );
  }

  Widget _paginationBar(
    double side,
    int cur,
    int pages,
    int offset,
    int count,
  ) {
    Widget box({
      required Widget child,
      VoidCallback? onTap,
      bool active = false,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: _sw(36),
          height: _sw(36),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? primary : Colors.white,
            borderRadius: BorderRadius.circular(_sw(10)),
            border: Border.all(color: active ? primary : _divider),
          ),
          child: child,
        ),
      );
    }

    final from = offset + 1;
    final to = (offset + HistoryController.perPage).clamp(1, count);

    return Padding(
      padding: EdgeInsets.fromLTRB(side, 0, side, _sh(8)),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: _sw(6),
            runSpacing: _sw(6),
            children: [
              box(
                onTap: cur > 1 ? () => c.goToPage(cur - 1) : null,
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: _sw(22),
                  color: cur > 1 ? _textDark : _divider,
                ),
              ),
              for (final p in c.pageItems)
                p == -1
                    ? SizedBox(
                      width: _sw(20),
                      child: Text(
                        '…',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: _sp(14), color: _textMuted),
                      ),
                    )
                    : box(
                      active: p == cur,
                      onTap: p == cur ? null : () => c.goToPage(p),
                      child: Text(
                        '$p',
                        style: TextStyle(
                          fontSize: _sp(13),
                          fontWeight: FontWeight.w700,
                          color: p == cur ? Colors.white : _textDark,
                        ),
                      ),
                    ),
              box(
                onTap: cur < pages ? () => c.goToPage(cur + 1) : null,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: _sw(22),
                  color: cur < pages ? _textDark : _divider,
                ),
              ),
            ],
          ),
          SizedBox(height: _sh(8)),
          Text(
            'Showing $from–$to of $count',
            style: TextStyle(fontSize: _sp(11.5), color: _textMuted),
          ),
        ],
      ),
    );
  }

  Widget _titleBlock(int total, int visible, bool isFiltered, double side) {
    return Container(
      width: double.infinity,
      color: primary,
      padding: EdgeInsets.fromLTRB(side, _sh(10), side, _sh(6)),
      child: Row(
        children: [
          // if (onBack != null) ...[
          //   InkWell(
          //     onTap: onBack,
          //     borderRadius: BorderRadius.circular(_sw(12)),
          //     child: Container(
          //       width: _sw(40),
          //       height: _sw(40),
          //       decoration: BoxDecoration(
          //         color: Colors.white.withValues(alpha: 0.15),
          //         borderRadius: BorderRadius.circular(_sw(12)),
          //       ),
          //       child: Icon(
          //         Icons.arrow_back_rounded,
          //         color: Colors.white,
          //         size: _sw(22),
          //       ),
          //     ),
          //   ),
          //   SizedBox(width: _sw(12)),
          // ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice History',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _sp(21),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: _sh(2)),
                Text(
                  isFiltered
                      ? '$visible of $total invoices'
                      : '$total ${total == 1 ? 'invoice' : 'invoices'} saved',
                  style: TextStyle(
                    fontSize: _sp(12.5),
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_sw(14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: c.searchController,
        onChanged: c.setQuery,
        textInputAction: TextInputAction.search,
        style: TextStyle(
          fontSize: _sp(14),
          color: _textDark,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search supplier, invoice no, text...',
          hintStyle: TextStyle(fontSize: _sp(13.5), color: _textMuted),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: _textMuted,
            size: _sw(22),
          ),
          suffixIcon:
              c.query.value.isNotEmpty
                  ? IconButton(
                    tooltip: 'Clear',
                    icon: Icon(
                      Icons.close_rounded,
                      size: _sw(20),
                      color: _textMuted,
                    ),
                    onPressed: c.clearSearch,
                  )
                  : null,
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: _sh(12)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_sw(14)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_sw(14)),
            borderSide: const BorderSide(color: primaryLight, width: 1.6),
          ),
        ),
      ),
    );
  }

  Widget _filterChips() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _filters.length,
      separatorBuilder: (_, _) => SizedBox(width: _sw(8)),
      itemBuilder: (_, i) {
        final (label, icon) = _filters[i];
        final active = label == c.filter.value;

        return Semantics(
          button: true,
          selected: active,
          label: label,
          child: GestureDetector(
            onTap: () => c.filter.value = label,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: _sw(14)),
              decoration: BoxDecoration(
                color:
                    active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(_sw(18)),
                border: Border.all(
                  color: active ? Colors.white : Colors.white24,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: _sw(15),
                    color: active ? primaryDark : Colors.white,
                  ),
                  SizedBox(width: _sw(6)),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: _sp(12.5),
                      fontWeight: FontWeight.w600,
                      color: active ? primaryDark : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------ body

  Widget _sectionLabel(String label, int count) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: _sp(13),
            fontWeight: FontWeight.w800,
            color: _textDark,
          ),
        ),
        SizedBox(width: _sw(8)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: _sw(8), vertical: _sh(1.5)),
          decoration: BoxDecoration(
            color: _cardIconBg,
            borderRadius: BorderRadius.circular(_sw(20)),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: _sp(11),
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
        ),
        SizedBox(width: _sw(10)),
        Expanded(child: Container(height: 1, color: _divider)),
      ],
    );
  }

  Widget _emptyState(bool searching) {
    return Padding(
      padding: EdgeInsets.fromLTRB(_sw(24), _sh(48), _sw(24), _sh(24)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            children: [
              Container(
                width: _sw(88),
                height: _sw(88),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_cardIconBg, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  searching
                      ? Icons.search_off_rounded
                      : Icons.receipt_long_outlined,
                  size: _sw(38),
                  color: primary,
                ),
              ),
              SizedBox(height: _sh(20)),
              Text(
                searching ? 'No invoices found' : 'No invoices yet',
                style: TextStyle(
                  fontSize: _sp(16.5),
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
              SizedBox(height: _sh(6)),
              Text(
                searching
                    ? 'Try a different keyword or clear your search.'
                    : 'Your saved invoices will appear here once you scan one.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: _sp(13),
                  color: _textMuted,
                  height: 1.4,
                ),
              ),
              if (searching) ...[
                SizedBox(height: _sh(18)),
                OutlinedButton.icon(
                  onPressed: c.clearSearch,
                  icon: Icon(Icons.refresh_rounded, size: _sw(16)),
                  label: const Text('Clear search'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: const BorderSide(color: primary, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_sw(11)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pinned search + filter bar
// ---------------------------------------------------------------------------

class _PinnedBar extends SliverPersistentHeaderDelegate {
  final double extent;
  final Widget child;
  _PinnedBar({required this.extent, required this.child});

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_sw(24)),
          bottomRight: Radius.circular(_sw(24)),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: overlapsContent ? 0.25 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedBar old) => true;
}

// ---------------------------------------------------------------------------
// Loading placeholder
// ---------------------------------------------------------------------------

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  Widget _bar(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: _divider,
      borderRadius: BorderRadius.circular(6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(_sw(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_sw(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _bar(_sw(30), _sw(30)),
              SizedBox(width: _sw(10)),
              _bar(_sw(140), _sh(14)),
              const Spacer(),
              _bar(_sw(60), _sh(14)),
            ],
          ),
          SizedBox(height: _sh(16)),
          Row(
            children: [
              _bar(_sw(70), _sh(24)),
              SizedBox(width: _sw(16)),
              _bar(_sw(60), _sh(24)),
              SizedBox(width: _sw(16)),
              _bar(_sw(80), _sh(24)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invoice card
// ---------------------------------------------------------------------------

class _InvoiceCard extends StatelessWidget {
  final int serial;
  final InvoiceData invoice;
  final VoidCallback onView;
  final VoidCallback onImages;
  final VoidCallback onDownload;
  final VoidCallback onEdit;

  const _InvoiceCard({
    required this.serial,
    required this.invoice,
    required this.onView,
    required this.onImages,
    required this.onDownload,
    required this.onEdit,
  });

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

  String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${l.day} ${_months[l.month - 1]} ${l.year}';
  }

  String _dash(String? v) => (v == null || v.trim().isEmpty) ? '—' : v;

  String _dateText() {
    final Object? d = invoice.date;
    if (d is DateTime) return _fmt(d);
    return _dash(d?.toString());
  }

  // Works whether ocrStatus is an enum or a String
  ({String label, Color color, IconData icon}) _ocr() {
    final raw = invoice.ocrStatus.toString().split('.').last.toLowerCase();
    switch (raw) {
      case 'complete':
      case 'done':
        return (
          label: 'Done',
          color: const Color(0xFF2456D6),
          icon: Icons.check_circle_rounded,
        );
      case 'failed':
      case 'error':
        return (
          label: 'Failed',
          color: Colors.redAccent,
          icon: Icons.error_rounded,
        );
      default:
        return (
          label: 'Pending',
          color: const Color(0xFFF29D1F),
          icon: Icons.schedule_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ocr = _ocr();
    final hasImages = invoice.images.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_sw(18)),
        border: Border.all(color: _divider.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_sw(18)),
        child: InkWell(
          borderRadius: BorderRadius.circular(_sw(18)),
          onTap: onView,
          child: Padding(
            padding: EdgeInsets.fromLTRB(_sw(14), _sw(14), _sw(8), _sw(6)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- SL.NO + Supplier + Gross
                Padding(
                  padding: EdgeInsets.only(right: _sw(6)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: _sw(32),
                        height: _sw(32),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _cardIconBg,
                          borderRadius: BorderRadius.circular(_sw(10)),
                        ),
                        child: Text(
                          '$serial',
                          style: TextStyle(
                            fontSize: _sp(12),
                            fontWeight: FontWeight.w800,
                            color: primary,
                          ),
                        ),
                      ),
                      SizedBox(width: _sw(10)),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: _sh(1)),
                          child: Text(
                            _dash(invoice.supplier),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: _sp(14.5),
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: _sw(8)),
                      Text(
                        '£${invoice.gross.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: _sp(15.5),
                          fontWeight: FontWeight.w800,
                          color: primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: _sh(12)),

                // ---- Invoice No / Date / Uploaded (soft panel)
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(right: _sw(6)),
                  padding: EdgeInsets.symmetric(
                    horizontal: _sw(12),
                    vertical: _sh(10),
                  ),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(_sw(12)),
                  ),
                  child: Row(
                    children: [
                      _info('Invoice No', _dash(invoice.invoiceNo), flex: 3),
                      _info('Date', _dateText(), flex: 3),
                      _info('Uploaded', _fmt(invoice.uploadedAt), flex: 3),
                    ],
                  ),
                ),
                SizedBox(height: _sh(6)),

                // ---- OCR + Actions
                Row(
                  children: [
                    _statusPill(ocr),
                    const Spacer(),
                    _action(Icons.visibility_outlined, 'View', onView),
                    _action(
                      Icons.image_outlined,
                      'Images',
                      hasImages ? onImages : null,
                    ),
                    _action(
                      Icons.file_download_outlined,
                      'Download',
                      onDownload,
                    ),
                    _action(Icons.edit_outlined, 'Edit', onEdit),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusPill(({String label, Color color, IconData icon}) ocr) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _sw(10), vertical: _sh(4)),
      decoration: BoxDecoration(
        color: ocr.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(_sw(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ocr.icon, size: _sw(13), color: ocr.color),
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

  Widget _info(String label, String value, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _sp(10.5),
              color: _textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: _sh(2)),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _sp(12.5),
              color: _textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// 40x40 minimum touch target (was ~32).
  Widget _action(IconData icon, String tooltip, VoidCallback? onTap) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints(minWidth: _sw(40), minHeight: _sw(40)),
      padding: EdgeInsets.zero,
      icon: Icon(
        icon,
        size: _sw(21),
        color: onTap == null ? _divider : _textMuted,
      ),
    );
  }
}
