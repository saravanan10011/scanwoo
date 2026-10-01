import 'package:quick_scanner/utils/common_color.dart';
import 'package:quick_scanner/routes_list.dart';
import 'package:quick_scanner/utils/common_size.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/widgets/exportsheet.dart';

import '../../../services/models/scan_record.dart';
import '../../../services/scan_history_service.dart';

// Same 375x812 baseline scaling used across the app's other screens.

class _Palette {
  static const primary = ColorConstants.indigo;
  static const primarySoft = ColorConstants.primaryMist;
  static const accent = ColorConstants.success;
  static const background = ColorConstants.backgroundSoft;
  static const surface = ColorConstants.white;
  static const ink = ColorConstants.inkDeep;
  static const muted = ColorConstants.inkMuted;
  static const mutedSoft = ColorConstants.inkMutedSoft;
  static const line = ColorConstants.border5;
}

class _Space {
  static double get sm => Sizes.w(10);
  static double get md => Sizes.w(16);
  static double get lg => Sizes.w(20);
  static double get xl => Sizes.w(28);
  static double get xxl => Sizes.w(36);
}

class _Radius {
  static double get sm => Sizes.w(10);
  static double get md => Sizes.w(14);
  static double get lg => Sizes.w(18);
  static double get xl => Sizes.w(24);
  static const pill = 999.0;
}

TextStyle _type({
  required double size,
  required FontWeight weight,
  Color color = _Palette.ink,
  double? height,
  double letterSpacing = -0.1,
}) {
  return TextStyle(
    fontSize: Sizes.sp(size),
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

// -----------------------------------------------------------------------
// Controller
// -----------------------------------------------------------------------
class ScanPreviewController extends GetxController {
  final ScanRecord initialRecord;
  ScanPreviewController(this.initialRecord);

  late final Rx<ScanRecord> record = initialRecord.obs;

  Future<void> openEdit() async {
    final String? updatedText = await Get.toNamed<dynamic>(
      RouteList.editRecord,
      arguments: {'extractedText': record.value.text},
    );

    if (updatedText == null || updatedText == record.value.text) {
      return;
    }

    final records = ScanHistoryService.recordsNotifier.value;
    final index = records.indexOf(record.value);
    if (index == -1) return;

    final updatedRecord = ScanRecord(
      text: updatedText,
      imagePath: record.value.imagePath,
      createdAt: record.value.createdAt,
    );

    await ScanHistoryService.updateRecord(index, updatedRecord);

    record.value = updatedRecord;
    toast('Record updated', success: true);
  }

  void copyText() {
    if (record.value.text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: record.value.text));
    HapticFeedback.lightImpact();
  }

  void toast(String message, {bool success = false}) {
    Get.snackbar(
      '',
      '',
      titleText: const SizedBox.shrink(),
      messageText: Row(
        children: [
          Icon(
            success ? Icons.check_circle_rounded : Icons.info_rounded,
            color: ColorConstants.white,
            size: Sizes.w(18),
          ),
          SizedBox(width: _Space.sm),
          Expanded(
            child: Text(
              message,
              style: _type(
                size: 14,
                weight: FontWeight.w600,
                color: ColorConstants.white,
              ),
            ),
          ),
        ],
      ),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: _Palette.ink,
      borderRadius: _Radius.md,
      margin: EdgeInsets.all(_Space.md),
      padding: EdgeInsets.symmetric(horizontal: _Space.lg, vertical: _Space.md),
      duration: const Duration(seconds: 2),
    );
  }

  void openFullImage(File file) {
    Get.dialog(
      Dialog(
        insetPadding: EdgeInsets.all(Sizes.w(16)),
        backgroundColor: ColorConstants.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(_Radius.lg),
              child: Hero(
                tag: 'scan-image-${file.path}',
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.file(file, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: Sizes.w(8),
              right: Sizes.w(8),
              child: Material(
                color: ColorConstants.black.withValues(alpha: 0.55),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: Get.back,
                  child: Padding(
                    padding: EdgeInsets.all(Sizes.w(9)),
                    child: Icon(
                      Icons.close_rounded,
                      color: ColorConstants.white,
                      size: Sizes.w(18),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Screen
// -----------------------------------------------------------------------
class ScanPreviewScreen extends StatelessWidget {
  final ScanRecord record;

  const ScanPreviewScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ScanPreviewController(record));

    return Scaffold(
      backgroundColor: _Palette.background,
      appBar: _ScanAppBar(onEdit: c.openEdit),
      body: Obx(() {
        final rec = c.record.value;
        final imageFile = File(rec.imagePath);
        final hasImage = imageFile.existsSync();

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            _Space.lg,
            _Space.md,
            _Space.lg,
            _Space.xxl,
          ),
          children: [
            _ImageCard(
              file: imageFile,
              hasImage: hasImage,
              onTap: () => c.openFullImage(imageFile),
            ),
            SizedBox(height: _Space.md),
            _MetaStrip(record: rec),
            _TextCard(record: rec, onCopy: c.copyText),
            SizedBox(height: _Space.xl),
            _ActionBar(
              onEdit: c.openEdit,
              onExport: () => showExportSheet(context, [rec]),
            ),
          ],
        );
      }),
    );
  }
}

class _ScanAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onEdit;

  const _ScanAppBar({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    // ───────────────── Responsive helpers (375 x 812 baseline) ─────────────────
    double sw(double v) => Get.width / 375 * v;

    /// Font / icon scaling: follows width but is clamped so tablets don't get giant text.
    double sp(double v) => v * (Get.width / 375).clamp(0.85, 1.3);
    return AppBar(
      backgroundColor: _Palette.primary,
      surfaceTintColor: ColorConstants.transparent,
      scrolledUnderElevation: 1,
      shadowColor: _Palette.ink.withValues(alpha: 0.08),
      elevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      leading: Material(
        color: ColorConstants.white.withValues(alpha: 0.18),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            Get.back();
          },
          child: SizedBox(
            width: sw(40),
            height: sw(40),
            child: Icon(
              Icons.arrow_back_ios,
              size: sp(17),
              color: ColorConstants.white,
            ),
          ),
        ),
      ),
      title: Text(
        'Scan preview',
        style: _type(
          size: 17,
          color: _Palette.background,
          weight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _StatusChip extends StatelessWidget {
  final bool empty;

  const _StatusChip({required this.empty});

  @override
  Widget build(BuildContext context) {
    final dotColor = empty ? _Palette.mutedSoft : _Palette.accent;
    final bg = empty ? _Palette.background : ColorConstants.successSoft;
    final fg = empty ? _Palette.muted : ColorConstants.success2;
    final label = empty ? 'Empty' : 'Text detected';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Sizes.w(10),
        vertical: Sizes.w(5),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_Radius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: Sizes.w(6),
            height: Sizes.w(6),
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          SizedBox(width: Sizes.w(6)),
          Text(
            label,
            style: _type(size: 12, weight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Image card
// -----------------------------------------------------------------------
class _ImageCard extends StatelessWidget {
  final File file;
  final bool hasImage;
  final VoidCallback onTap;

  const _ImageCard({
    required this.file,
    required this.hasImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(_Radius.xl),
        boxShadow: [
          BoxShadow(
            color: _Palette.primary.withValues(alpha: 0.14),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: EdgeInsets.all(Sizes.w(8)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_Radius.lg),
        child: hasImage ? _photo() : const _MissingImage(),
      ),
    );
  }

  Widget _photo() {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Hero(
            tag: 'scan-image-${file.path}',
            child: Image.file(
              file,
              width: double.infinity,
              height: Sizes.h(240),
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: Sizes.h(72),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ColorConstants.transparent,
                    ColorConstants.black.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: Sizes.w(12),
            bottom: Sizes.w(12),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: Sizes.w(11),
                vertical: Sizes.w(7),
              ),
              decoration: BoxDecoration(
                color: ColorConstants.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(_Radius.pill),
                border: Border.all(
                  color: ColorConstants.white.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.zoom_out_map_rounded,
                    color: ColorConstants.white,
                    size: Sizes.w(14),
                  ),
                  SizedBox(width: Sizes.w(6)),
                  Text(
                    'Tap to zoom',
                    style: TextStyle(
                      color: ColorConstants.white,
                      fontSize: Sizes.sp(12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingImage extends StatelessWidget {
  const _MissingImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Sizes.h(180),
      alignment: Alignment.center,
      color: _Palette.background,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: Sizes.w(56),
            width: Sizes.w(56),
            decoration: const BoxDecoration(
              color: _Palette.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.image_not_supported_outlined,
              size: Sizes.w(26),
              color: _Palette.primary,
            ),
          ),
          SizedBox(height: _Space.sm),
          Text(
            'Image not available',
            style: _type(
              size: 13,
              weight: FontWeight.w500,
              color: _Palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Meta strip
// -----------------------------------------------------------------------
class _MetaStrip extends StatelessWidget {
  final ScanRecord record;

  const _MetaStrip({required this.record});

  @override
  Widget build(BuildContext context) {
    final words =
        record.text.trim().isEmpty
            ? 0
            : record.text.trim().split(RegExp(r'\s+')).length;
    final empty = record.text.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _StatusChip(empty: empty),
        ),
        SizedBox(height: _Space.sm),
        Row(
          children: [
            Expanded(
              child: _MetaPill(
                icon: Icons.calendar_today_rounded,
                label: _formatDate(record.createdAt),
              ),
            ),
            SizedBox(width: _Space.sm),
            Expanded(
              child: _MetaPill(
                icon: Icons.schedule_rounded,
                label: _formatTime(record.createdAt),
              ),
            ),
            SizedBox(width: _Space.sm),
            Expanded(
              child: _MetaPill(
                icon: Icons.notes_rounded,
                label: '$words words',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: Sizes.w(12)),
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(_Radius.md),
        border: Border.all(color: _Palette.line),
      ),
      child: Column(
        children: [
          Icon(icon, size: Sizes.w(17), color: _Palette.primary),
          SizedBox(height: Sizes.w(5)),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _type(
              size: 11.5,
              weight: FontWeight.w600,
              color: _Palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Extracted text card
// -----------------------------------------------------------------------
class _TextCard extends StatelessWidget {
  final ScanRecord record;
  final VoidCallback onCopy;

  const _TextCard({required this.record, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final empty = record.text.trim().isEmpty;
    final chars = record.text.trim().length;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: _Space.lg),
      padding: EdgeInsets.all(Sizes.w(18)),
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(_Radius.xl),
        border: Border.all(color: _Palette.line),
        boxShadow: const [
          BoxShadow(
            color: ColorConstants.shadowInk04,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: Sizes.w(36),
                width: Sizes.w(36),
                decoration: BoxDecoration(
                  color: _Palette.primarySoft,
                  borderRadius: BorderRadius.circular(Sizes.w(11)),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: _Palette.primary,
                  size: Sizes.w(18),
                ),
              ),
              SizedBox(width: _Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extracted text',
                      style: _type(size: 16, weight: FontWeight.w700),
                    ),
                    if (!empty)
                      Text(
                        '$chars characters',
                        style: _type(
                          size: 11.5,
                          weight: FontWeight.w500,
                          color: _Palette.mutedSoft,
                        ),
                      ),
                  ],
                ),
              ),
              if (!empty) _CopyButton(onTap: onCopy),
            ],
          ),
          SizedBox(height: _Space.md),
          if (empty)
            const _EmptyTextState()
          else
            _FilledText(text: record.text),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CopyButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _Palette.primarySoft,
      borderRadius: BorderRadius.circular(_Radius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_Radius.sm),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Sizes.w(12),
            vertical: Sizes.w(9),
          ),
          child: Row(
            children: [
              Icon(
                Icons.copy_rounded,
                size: Sizes.w(15),
                color: _Palette.primary,
              ),
              SizedBox(width: Sizes.w(6)),
              Text(
                'Copy',
                style: TextStyle(
                  fontSize: Sizes.sp(13),
                  color: _Palette.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTextState extends StatelessWidget {
  const _EmptyTextState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _Space.lg),
      child: Column(
        children: [
          Container(
            height: Sizes.w(60),
            width: Sizes.w(60),
            decoration: const BoxDecoration(
              color: _Palette.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.text_fields_rounded,
              size: Sizes.w(28),
              color: _Palette.mutedSoft,
            ),
          ),
          SizedBox(height: _Space.md),
          Text(
            'No text was found in this scan',
            textAlign: TextAlign.center,
            style: _type(size: 14.5, weight: FontWeight.w600),
          ),
          SizedBox(height: Sizes.w(4)),
          Text(
            'Edit the record to add text yourself.',
            textAlign: TextAlign.center,
            style: _type(
              size: 13,
              weight: FontWeight.w400,
              color: _Palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilledText extends StatelessWidget {
  final String text;

  const _FilledText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Sizes.w(14)),
      decoration: BoxDecoration(
        color: _Palette.background,
        borderRadius: BorderRadius.circular(_Radius.md),
      ),
      child: SelectableText(
        text,
        style: _type(
          size: 14.5,
          weight: FontWeight.w400,
          color: _Palette.ink.withValues(alpha: 0.88),
          height: 1.6,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Actions
// -----------------------------------------------------------------------
class _ActionBar extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onExport;

  const _ActionBar({required this.onEdit, required this.onExport});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: Sizes.h(52),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _Palette.primary,
                side: const BorderSide(color: _Palette.primary, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_Radius.md),
                ),
              ),
              label: Text(
                'Save',
                style: TextStyle(
                  fontSize: Sizes.sp(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => Get.back(),
            ),
          ),
        ),
        SizedBox(width: _Space.md),
        Expanded(
          child: SizedBox(
            height: Sizes.h(52),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _Palette.primary,
                foregroundColor: ColorConstants.white,
                elevation: 0,
                shadowColor: _Palette.primary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_Radius.md),
                ),
              ),
              icon: Icon(Icons.ios_share_rounded, size: Sizes.w(18)),
              label: Text(
                'Export',
                style: TextStyle(
                  fontSize: Sizes.sp(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: onExport,
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------
// Formatting helpers
// -----------------------------------------------------------------------
const _months = [
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

String _formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

String _formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final min = date.minute.toString().padLeft(2, '0');
  return '$hour:$min ${date.hour >= 12 ? 'PM' : 'AM'}';
}
