import 'package:quick_scanner/utils/common_color.dart';
import 'package:quick_scanner/utils/helpers.dart';
import 'package:quick_scanner/routes_list.dart';
import 'package:quick_scanner/utils/common_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/features/history/logic/history_controller.dart';
import 'package:quick_scanner/features/history/model/history_model.dart';
import 'package:quick_scanner/features/history/screens/view_img.dart';
import 'package:quick_scanner/features/history/screens/view_invoice.dart';

const primary = ColorConstants.primary;
const primaryDark = ColorConstants.primaryDark;
const primaryLight = ColorConstants.primaryLight;
const background = ColorConstants.background;

const _maxContentWidth = 720.0;

class ScanHistoryScreen extends StatelessWidget {
  final VoidCallback? onBack;
  const ScanHistoryScreen({super.key, this.onBack});

  HistoryController get c => Get.find<HistoryController>();

  static const _filters = [
    ('All', Icons.apps_rounded),
    ('Today', Icons.today_rounded),
    ('This Week', Icons.date_range_rounded),
    ('This Month', Icons.calendar_month_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final side =
        width > _maxContentWidth + 32
            ? (width - _maxContentWidth) / 2
            : Sizes.s(16);
    final topInset = MediaQuery.paddingOf(context).top;

    return GetBuilder<HistoryController>(
      // fires only when the screen is really removed
      dispose: (_) => c.resetFilters(),
      builder:
          (_) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: primary,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            ),
            child: MediaQuery.withClampedTextScaling(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.3,
              child: Scaffold(
                backgroundColor: background,
                body: Column(
                  children: [
                    Container(height: topInset, color: primary),
                    Expanded(child: Obx(() => _body(side))),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _body(double side) {
    final list = c.filtered;
    final pageList = c.paged;
    final cur = c.safePage;
    final pages = c.totalPages;
    final grouped = c.grouped(pageList);
    final total = c.invoices.length;
    final searching = c.query.value.trim().isNotEmpty;
    final isFiltered = searching || c.filter.value != 'All';
    final loadingFirst = c.isLoading.value && c.invoices.isEmpty;
    final error = c.invoices.isEmpty ? c.errorMessage.value : null;
    final busyLoading = c.isRefreshing.value || c.isLoadingMore.value;
    final downloadingId = c.downloadingId.value;
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
      onRefresh: c.refreshList,
      child: CustomScrollView(
        controller: c.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _titleBlock(total, list.length, isFiltered, side),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedBar(
              extent: Sizes.s(6 + 46 + 10 + 34 + 16),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  side,
                  Sizes.s(6),
                  side,
                  Sizes.s(16),
                ),
                child: Column(
                  children: [
                    SizedBox(height: Sizes.s(46), child: _searchBar()),
                    SizedBox(height: Sizes.s(10)),
                    SizedBox(height: Sizes.s(34), child: _filterChips()),
                  ],
                ),
              ),
            ),
          ),
          if (busyLoading && !loadingFirst)
            SliverToBoxAdapter(
              child: LinearProgressIndicator(
                minHeight: 2.5,
                color: primary,
                backgroundColor: ColorConstants.primarySoft,
              ),
            ),
          if (loadingFirst)
            SliverFillRemaining(hasScrollBody: false, child: _loadingState())
          else if (error != null)
            SliverFillRemaining(hasScrollBody: false, child: _errorState(error))
          else if (list.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _emptyState(isFiltered, c.isLoadingMore.value),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                side,
                Sizes.s(16),
                side,
                Sizes.s(24),
              ),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final r = rows[i];
                  if (r is (String, int)) {
                    return Padding(
                      padding: EdgeInsets.only(
                        top: i == 0 ? 0 : Sizes.s(8),
                        bottom: Sizes.s(10),
                      ),
                      child: _sectionLabel(r.$1, r.$2),
                    );
                  }
                  final inv = r as InvoiceData;
                  return Padding(
                    padding: EdgeInsets.only(bottom: Sizes.s(14)),
                    child: _InvoiceCard(
                      serial: serials[inv.id] ?? i,
                      invoice: inv,
                      onView: () => Get.dialog(InvoiceViewDialog(invoice: inv)),
                      onImages:
                          () => Get.dialog(InvoiceImagesDialog(invoice: inv)),
                      downloading: downloadingId == inv.id,
                      onDownload:
                          () => c.downloadInvoice(inv.id, format: 'csv'),
                      onEdit:
                          () => Get.toNamed(
                            RouteList.editRawText,
                            arguments: {
                              'invoice': inv,
                              'initialText': c.rawTextOf(inv),
                              'onSave':
                                  (String text) =>
                                      c.updateRawText(inv.id, text),
                            },
                          ),
                    ),
                  );
                },
              ),
            ),
          if (c.isLoadingMore.value && list.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(Sizes.s(16)),
                child: Center(
                  child: Text(
                    'Loading more invoices…',
                    style: TextStyle(
                      fontSize: Sizes.s(12),
                      color: ColorConstants.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          if (list.isNotEmpty)
            SliverToBoxAdapter(child: SizedBox(height: Sizes.s(8))),
          if (list.isNotEmpty && pages > 1)
            SliverToBoxAdapter(
              child: _paginationBar(side, cur, pages, offset, list.length),
            ),
          SliverToBoxAdapter(child: SizedBox(height: Sizes.s(16))),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Pagination
  // -------------------------------------------------------------------------

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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: Sizes.s(36),
          height: Sizes.s(36),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? primary : ColorConstants.white,
            borderRadius: BorderRadius.circular(Sizes.s(12)),
            border: Border.all(
              color: active ? primary : ColorConstants.divider,
            ),
            boxShadow:
                active
                    ? [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                    : null,
          ),
          child: child,
        ),
      );
    }

    final from = offset + 1;
    final to = (offset + HistoryController.perPage).clamp(1, count);

    return Padding(
      padding: EdgeInsets.fromLTRB(side, Sizes.s(8), side, Sizes.s(8)),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Sizes.s(6),
            runSpacing: Sizes.s(6),
            children: [
              box(
                onTap: cur > 1 ? () => c.goToPage(cur - 1) : null,
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: Sizes.s(22),
                  color:
                      cur > 1
                          ? ColorConstants.textDark
                          : ColorConstants.divider,
                ),
              ),
              for (final p in c.pageItems)
                p == -1
                    ? SizedBox(
                      width: Sizes.s(20),
                      child: Text(
                        '…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: Sizes.s(14),
                          color: ColorConstants.textMuted,
                        ),
                      ),
                    )
                    : box(
                      active: p == cur,
                      onTap: p == cur ? null : () => c.goToPage(p),
                      child: Text(
                        '$p',
                        style: TextStyle(
                          fontSize: Sizes.s(13),
                          fontWeight: FontWeight.w700,
                          color:
                              p == cur
                                  ? ColorConstants.white
                                  : ColorConstants.textDark,
                        ),
                      ),
                    ),
              box(
                onTap: cur < pages ? () => c.goToPage(cur + 1) : null,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: Sizes.s(22),
                  color:
                      cur < pages
                          ? ColorConstants.textDark
                          : ColorConstants.divider,
                ),
              ),
            ],
          ),
          SizedBox(height: Sizes.s(10)),
          Text(
            'Showing $from–$to of $count',
            style: TextStyle(
              fontSize: Sizes.s(11.5),
              color: ColorConstants.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Header
  // -------------------------------------------------------------------------

  Widget _titleBlock(int total, int visible, bool isFiltered, double side) {
    return Container(
      width: double.infinity,
      color: primary,
      padding: EdgeInsets.fromLTRB(side, Sizes.s(12), side, Sizes.s(8)),
      child: Row(
        children: [
          // Container(
          //   width: Sizes.s(42),
          //   height: Sizes.s(42),
          //   decoration: BoxDecoration(
          //     color: ColorConstants.white.withValues(alpha: 0.16),
          //     borderRadius: BorderRadius.circular(Sizes.s(13)),
          //   ),
          //   child: Icon(
          //     Icons.receipt_long_rounded,
          //     color: ColorConstants.white,
          //     size: Sizes.s(22),
          //   ),
          // ),
          SizedBox(width: Sizes.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice History',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Sizes.s(20),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: ColorConstants.white,
                  ),
                ),
                SizedBox(height: Sizes.s(2)),
                Text(
                  isFiltered
                      ? 'Showing $visible of $total'
                      : 'All your scanned invoices',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Sizes.s(12),
                    color: ColorConstants.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: Sizes.s(8)),
          // Container(
          //   padding: EdgeInsets.symmetric(
          //     horizontal: Sizes.s(12),
          //     vertical: Sizes.s(6),
          //   ),
          //   decoration: BoxDecoration(
          //     color: ColorConstants.white,
          //     borderRadius: BorderRadius.circular(Sizes.s(20)),
          //   ),
          //   child: Text(
          //     '$total',
          //     style: TextStyle(
          //       fontSize: Sizes.s(13),
          //       fontWeight: FontWeight.w800,
          //       color: primaryDark,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Sizes.s(14)),
        boxShadow: [
          BoxShadow(
            color: ColorConstants.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: c.searchController,
        onChanged: c.onSearchChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(
          fontSize: Sizes.s(14),
          color: ColorConstants.textDark,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search supplier, invoice no, text...',
          hintStyle: TextStyle(
            fontSize: Sizes.s(13.5),
            color: ColorConstants.textMuted,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: primary,
            size: Sizes.s(22),
          ),
          suffixIcon:
              c.hasSearchText.value
                  ? IconButton(
                    tooltip: 'Clear',
                    icon: Icon(
                      Icons.close_rounded,
                      size: Sizes.s(20),
                      color: ColorConstants.textMuted,
                    ),
                    onPressed: c.clearSearch,
                  )
                  : null,
          filled: true,
          fillColor: ColorConstants.white,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: Sizes.s(12)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Sizes.s(14)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Sizes.s(14)),
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
      separatorBuilder: (_, _) => SizedBox(width: Sizes.s(8)),
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
              padding: EdgeInsets.symmetric(horizontal: Sizes.s(14)),
              decoration: BoxDecoration(
                color:
                    active
                        ? ColorConstants.white
                        : ColorConstants.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(Sizes.s(18)),
                border: Border.all(
                  color: active ? ColorConstants.white : ColorConstants.white24,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: Sizes.s(15),
                    color: active ? primaryDark : ColorConstants.white,
                  ),
                  SizedBox(width: Sizes.s(6)),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: Sizes.s(12.5),
                      fontWeight: FontWeight.w600,
                      color: active ? primaryDark : ColorConstants.white,
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

  Widget _sectionLabel(String label, int count) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: Sizes.s(13),
            fontWeight: FontWeight.w800,
            color: ColorConstants.textDark,
          ),
        ),
        SizedBox(width: Sizes.s(8)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: Sizes.s(8),
            vertical: Sizes.s(1.5),
          ),
          decoration: BoxDecoration(
            color: ColorConstants.primarySoft,
            borderRadius: BorderRadius.circular(Sizes.s(20)),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: Sizes.s(11),
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
        ),
        SizedBox(width: Sizes.s(10)),
        Expanded(child: Container(height: 1, color: ColorConstants.divider)),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // States
  // -------------------------------------------------------------------------

  Widget _loadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: Sizes.s(36),
            height: Sizes.s(36),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              color: primary,
            ),
          ),
          SizedBox(height: Sizes.s(16)),
          Text(
            'Loading invoices…',
            style: TextStyle(
              fontSize: Sizes.s(13),
              fontWeight: FontWeight.w600,
              color: ColorConstants.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String message) {
    return Padding(
      padding: EdgeInsets.all(Sizes.s(24)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: Sizes.s(52),
                color: ColorConstants.textMuted,
              ),
              SizedBox(height: Sizes.s(16)),
              Text(
                "Couldn't load invoices",
                style: TextStyle(
                  fontSize: Sizes.s(16.5),
                  fontWeight: FontWeight.w800,
                  color: ColorConstants.textDark,
                ),
              ),
              SizedBox(height: Sizes.s(6)),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Sizes.s(13),
                  color: ColorConstants.textMuted,
                  height: 1.4,
                ),
              ),
              SizedBox(height: Sizes.s(18)),
              FilledButton.icon(
                onPressed: c.fetchInvoices,
                icon: Icon(Icons.refresh_rounded, size: Sizes.s(18)),
                label: const Text('Try again'),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Sizes.s(11)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(bool isFiltered, bool stillLoading) {
    return Padding(
      padding: EdgeInsets.all(Sizes.s(24)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: Sizes.s(88),
                height: Sizes.s(88),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [ColorConstants.primarySoft, ColorConstants.white],
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
                  isFiltered
                      ? Icons.search_off_rounded
                      : Icons.receipt_long_outlined,
                  size: Sizes.s(38),
                  color: primary,
                ),
              ),
              SizedBox(height: Sizes.s(20)),
              Text(
                isFiltered ? 'No invoices found' : 'No invoices yet',
                style: TextStyle(
                  fontSize: Sizes.s(16.5),
                  fontWeight: FontWeight.w800,
                  color: ColorConstants.textDark,
                ),
              ),
              SizedBox(height: Sizes.s(6)),
              Text(
                isFiltered
                    ? (stillLoading
                        ? 'Nothing yet — still loading more invoices…'
                        : 'Try a different keyword or filter.')
                    : 'Your saved invoices will appear here once you scan one.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Sizes.s(13),
                  color: ColorConstants.textMuted,
                  height: 1.4,
                ),
              ),
              if (isFiltered) ...[
                SizedBox(height: Sizes.s(18)),
                OutlinedButton.icon(
                  onPressed: c.resetFilters,
                  icon: Icon(Icons.refresh_rounded, size: Sizes.s(16)),
                  label: const Text('Clear search & filters'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: const BorderSide(color: primary, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Sizes.s(11)),
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
          bottomLeft: Radius.circular(Sizes.s(26)),
          bottomRight: Radius.circular(Sizes.s(26)),
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
// Invoice card
// ---------------------------------------------------------------------------

class _InvoiceCard extends StatelessWidget {
  final int serial;
  final InvoiceData invoice;
  final VoidCallback onView;
  final VoidCallback onImages;
  final VoidCallback onDownload;
  final VoidCallback onEdit;
  final bool downloading;

  const _InvoiceCard({
    this.downloading = false,
    required this.serial,
    required this.invoice,
    required this.onView,
    required this.onImages,
    required this.onDownload,
    required this.onEdit,
  });

  String _dash(String? v) => (v == null || v.trim().isEmpty) ? '—' : v;

  // Works whether ocrStatus is an enum or a String
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
    final ocr = _ocr();
    final hasImages = invoice.images.isNotEmpty;
    final radius = BorderRadius.circular(Sizes.s(18));

    return Container(
      decoration: BoxDecoration(
        color: ColorConstants.white,
        borderRadius: radius,
        border: Border.all(
          color: ColorConstants.divider.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: ColorConstants.transparent,
          child: Stack(
            children: [
              InkWell(
                onTap: onView,
                child: Padding(
                  padding: EdgeInsets.only(left: Sizes.s(4)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          Sizes.s(14),
                          Sizes.s(14),
                          Sizes.s(14),
                          0,
                        ),
                        child: _topRow(ocr),
                      ),
                      SizedBox(height: Sizes.s(12)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: Sizes.s(14)),
                        child: _detailsPanel(),
                      ),
                      SizedBox(height: Sizes.s(8)),
                      Divider(
                        height: 1,
                        color: ColorConstants.divider.withValues(alpha: 0.7),
                      ),
                      _actionsRow(hasImages),
                    ],
                  ),
                ),
              ),
              // Status accent stripe
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: Sizes.s(4),
                child: IgnorePointer(child: ColoredBox(color: ocr.color)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topRow(({String label, Color color, IconData icon}) ocr) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: Sizes.s(34),
          height: Sizes.s(34),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ColorConstants.primarySoft,
            borderRadius: BorderRadius.circular(Sizes.s(11)),
          ),
          child: Text(
            '$serial',
            style: TextStyle(
              fontSize: Sizes.s(12.5),
              fontWeight: FontWeight.w800,
              color: primary,
            ),
          ),
        ),
        SizedBox(width: Sizes.s(10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dash(invoice.supplier),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: Sizes.s(14.5),
                  fontWeight: FontWeight.w800,
                  color: ColorConstants.textDark,
                  height: 1.25,
                ),
              ),
              SizedBox(height: Sizes.s(3)),
              // Text(
              //   '# ${_dash(invoice.invoiceNo)}',
              //   maxLines: 1,
              //   overflow: TextOverflow.ellipsis,
              //   style: TextStyle(
              //     fontSize: Sizes.s(11.5),
              //     fontWeight: FontWeight.w600,
              //     color: ColorConstants.textMuted,
              //   ),
              // ),
            ],
          ),
        ),
        SizedBox(width: Sizes.s(8)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text(
            //   '${invoice.gross.toStringAsFixed(2)}',
            //   style: TextStyle(
            //     fontSize: Sizes.s(16),
            //     fontWeight: FontWeight.w800,
            //     color: primaryDark,
            //   ),
            // ),
            SizedBox(height: Sizes.s(5)),
            _statusPill(ocr),
          ],
        ),
      ],
    );
  }

  Widget _detailsPanel() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: Sizes.s(12),
        vertical: Sizes.s(10),
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Sizes.s(12)),
      ),
      child: Row(
        children: [
          _info(
            Icons.receipt_long_outlined,
            'Invoice No',
            _dash(invoice.invoiceNo),
          ),
          Container(
            width: 1,
            height: Sizes.s(28),
            margin: EdgeInsets.symmetric(horizontal: Sizes.s(10)),
            color: ColorConstants.divider,
          ),
          _info(
            Icons.cloud_upload_outlined,
            'Uploaded',
            formatUploaded(invoice.uploadedAt),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(({String label, Color color, IconData icon}) ocr) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Sizes.s(8),
        vertical: Sizes.s(3),
      ),
      decoration: BoxDecoration(
        color: ocr.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Sizes.s(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ocr.icon, size: Sizes.s(12), color: ocr.color),
          SizedBox(width: Sizes.s(4)),
          Text(
            ocr.label,
            style: TextStyle(
              fontSize: Sizes.s(10.5),
              fontWeight: FontWeight.w700,
              color: ocr.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: Sizes.s(16), color: primary),
          SizedBox(width: Sizes.s(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Sizes.s(10.5),
                    color: ColorConstants.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: Sizes.s(1)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: Sizes.s(12.5),
                    color: ColorConstants.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsRow(bool hasImages) {
    return Row(
      children: [
        _action(Icons.visibility_outlined, 'View', onView),
        _action(Icons.image_outlined, 'Images', hasImages ? onImages : null),
        downloading
            ? Expanded(
              child: SizedBox(
                height: Sizes.s(48),
                child: Center(
                  child: SizedBox(
                    width: Sizes.s(18),
                    height: Sizes.s(18),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  ),
                ),
              ),
            )
            : _action(Icons.file_download_outlined, 'Download', onDownload),
        _action(Icons.edit_outlined, 'Edit', onEdit),
      ],
    );
  }

  Widget _action(IconData icon, String label, VoidCallback? onTap) {
    final color = onTap == null ? ColorConstants.divider : primary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: Sizes.s(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: Sizes.s(19), color: color),
              SizedBox(height: Sizes.s(2)),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: Sizes.s(10.5),
                  fontWeight: FontWeight.w600,
                  color:
                      onTap == null
                          ? ColorConstants.divider
                          : ColorConstants.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
