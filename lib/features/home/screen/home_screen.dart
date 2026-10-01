// ignore_for_file: unused_element

import 'package:quick_scanner/features/home/invoice_details.dart';
import 'package:quick_scanner/utils/common_color.dart';
import 'package:quick_scanner/routes_list.dart';
import 'package:quick_scanner/utils/common_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/features/history/logic/history_controller.dart';
import 'package:quick_scanner/features/history/model/history_model.dart';
import 'package:quick_scanner/features/history/screens/view_invoice.dart';
import 'package:quick_scanner/features/profile/logic/profile_controller.dart';
import 'package:quick_scanner/services/models/scan_record.dart';
import 'package:quick_scanner/services/scan_history_service.dart';
import 'package:quick_scanner/utils/helpers.dart';
import '../../../networks/data_service.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final c = Get.find<HistoryController>();
  final p = Get.find<ProfileController>();
  void goToTab(int i) => widget.onNavigateToTab?.call(i);
  final ProfileController _profileController = Get.find<ProfileController>();

  final tokenDataService = Get.find<TokenDataServiceImp>();

  void openScanner() {
    Get.toNamed(RouteList.scanner);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // ---- Invoice actions ---------------------------------------------------

  void _viewInvoice(InvoiceData inv) {
    Get.dialog(InvoiceViewDialog(invoice: inv));
  }

  Future<void> _editInvoice(InvoiceData inv) async {
    await Get.toNamed(
      RouteList.editRawText,
      arguments: {
        'invoice': inv,
        'initialText': c.rawTextOf(inv),
        'onSave': (String text) => c.updateRawText(inv.id, text),
      },
    );
    // Refresh so Home reflects the edit.
    c.refreshList();
  }

  // ---- Build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: ColorConstants.primaryBright,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: ColorConstants.backgroundHome,
          body:
              _profileController.isLoading.value
                  ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: ColorConstants.primaryBright,
                      ),
                    ),
                  )
                  : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_topSection(), _content()],
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _topSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            ColorConstants.primaryBright,
            ColorConstants.accent,
            ColorConstants.primaryDeep,
          ],
          stops: [0.0, 0.45, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: ColorConstants.primaryDeep.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft decorative glow, purely cosmetic.
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColorConstants.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                              color: ColorConstants.white70,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            _greeting(),
                            style: const TextStyle(
                              color: ColorConstants.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _profileController.userName.value,
                        style: const TextStyle(
                          color: ColorConstants.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => goToTab(3),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: ColorConstants.white.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ColorConstants.white.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: ColorConstants.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ValueListenableBuilder<List<ScanRecord>>(
                valueListenable: ScanHistoryService.recordsNotifier,
                builder: (context, records, _) => _statsStrip(records),
              ),
              const SizedBox(height: 18),
              _scanCard(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsStrip(List<ScanRecord> records) {
    final stats = p.dashboard.value?.data.stats;

    return Row(
      children: [
        Expanded(
          child: _statChip(
            Icons.receipt_long_rounded,
            stats == null ? '--' : '${stats.invoicesThisMonth}',
            'Invoices This Month',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statChip(
            Icons.calendar_month_rounded,
            stats == null ? '--' : '${stats.pending}',
            'Uploading Invoices',
          ),
        ),
      ],
    );
  }

  Widget _statChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: ColorConstants.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ColorConstants.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: ColorConstants.white.withValues(alpha: 0.85),
            size: 18,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: ColorConstants.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  color: ColorConstants.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scanCard() {
    return Material(
      color: ColorConstants.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: openScanner,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ColorConstants.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: ColorConstants.shadow13,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      ColorConstants.primaryBright,
                      ColorConstants.accent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: ColorConstants.primaryBright.withValues(
                        alpha: 0.35,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  color: ColorConstants.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan Invoice',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ColorConstants.textDark,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Extract data in seconds',
                      style: TextStyle(
                        color: ColorConstants.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                  color: ColorConstants.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: ColorConstants.primaryBright,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final items = c.recent;
    final loading = c.isRecentLoading.value && items.isEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(Sizes.w(18), Sizes.h(24), Sizes.w(18), 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Invoices',
                style: TextStyle(
                  fontSize: Sizes.sp(17),
                  fontWeight: FontWeight.w800,
                  color: ColorConstants.textDark,
                  letterSpacing: 0.1,
                ),
              ),
              if (c.recentTotal.value > 4)
                GestureDetector(
                  onTap: () => goToTab(1),
                  child: Row(
                    children: [
                      Text(
                        'See all',
                        style: TextStyle(
                          fontSize: Sizes.sp(13),
                          fontWeight: FontWeight.w700,
                          color: ColorConstants.primaryBright,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: ColorConstants.primaryBright,
                        size: Sizes.w(18),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: Sizes.h(14)),
          if (loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: Sizes.h(32)),
              child: const Center(
                child: CircularProgressIndicator(
                  color: ColorConstants.primaryBright,
                ),
              ),
            )
          else if (items.isEmpty)
            _emptyState()
          else
            Column(children: items.map(_recentTile).toList()),
        ],
      ),
    );
  }

  Widget _tileIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Sizes.w(10)),
        child: Container(
          width: Sizes.w(32),
          height: Sizes.w(32),
          decoration: BoxDecoration(
            color: ColorConstants.primarySoft,
            borderRadius: BorderRadius.circular(Sizes.w(10)),
          ),
          child: Icon(
            icon,
            size: Sizes.w(17),
            color: ColorConstants.primaryBright,
          ),
        ),
      ),
    );
  }

  Widget _recentTile(InvoiceData inv) {
    final name =
        inv.supplier.trim().isEmpty ? 'Unknown supplier' : inv.supplier;

    return Material(
      color: ColorConstants.transparent,
      borderRadius: BorderRadius.circular(Sizes.w(16)),
      child: InkWell(
        // Opens the individual invoice screen.
        onTap: () => openInvoiceDetail(inv),
        borderRadius: BorderRadius.circular(Sizes.w(16)),
        child: Container(
          margin: EdgeInsets.only(bottom: Sizes.h(10)),
          padding: EdgeInsets.symmetric(
            horizontal: Sizes.w(14),
            vertical: Sizes.h(13),
          ),
          decoration: BoxDecoration(
            color: ColorConstants.white,
            borderRadius: BorderRadius.circular(Sizes.w(16)),
            boxShadow: const [
              BoxShadow(
                color: ColorConstants.shadow06,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: Sizes.w(40),
                height: Sizes.w(40),
                decoration: BoxDecoration(
                  color: ColorConstants.primarySoft,
                  borderRadius: BorderRadius.circular(Sizes.w(12)),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: ColorConstants.primaryBright,
                  size: Sizes.w(20),
                ),
              ),
              SizedBox(width: Sizes.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Sizes.sp(13.5),
                        fontWeight: FontWeight.w700,
                        color: ColorConstants.textDark,
                      ),
                    ),
                    SizedBox(height: Sizes.h(3)),
                    Text(
                      formatShortDate(inv.uploadedAt),
                      style: TextStyle(
                        color: ColorConstants.textMuted,
                        fontSize: Sizes.sp(11),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: Sizes.w(8)),
              Text(
                inv.gross.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: Sizes.sp(14),
                  fontWeight: FontWeight.w800,
                  color: ColorConstants.textDark,
                ),
              ),
              SizedBox(width: Sizes.w(10)),
              // _tileIcon(
              //   Icons.visibility_outlined,
              //   'View',
              //   () => openInvoiceDetail(inv),
              // ),
              // SizedBox(width: Sizes.w(6)),
              // _tileIcon(Icons.edit_outlined, 'Edit', () => _editInvoice(inv)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ColorConstants.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ColorConstants.border4, width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: ColorConstants.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: ColorConstants.primaryBright,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No invoices yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: ColorConstants.textDark,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Scan your first invoice to see it here',
            style: TextStyle(color: ColorConstants.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
