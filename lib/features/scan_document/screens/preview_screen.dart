import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/utils/common_color.dart';
import 'package:quick_scanner/utils/common_size.dart';

import '../../../services/models/scan_record.dart';

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
}

class _Radius {
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

List<BoxShadow> get _softShadow => [
  BoxShadow(
    color: _Palette.ink.withValues(alpha: 0.06),
    blurRadius: 20,
    offset: const Offset(0, 8),
  ),
];

// -----------------------------------------------------------------------
// Controller
// -----------------------------------------------------------------------
class ScanPreviewController extends GetxController {
  final ScanRecord initialRecord;
  ScanPreviewController(this.initialRecord);

  late final Rx<ScanRecord> record = initialRecord.obs;
  final RxBool textExpanded = false.obs;

  void toggleExpanded() => textExpanded.toggle();

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
      appBar: const _ScanAppBar(),
      bottomNavigationBar: _SaveBar(onSave: Get.back),
      body: Obx(() {
        final rec = c.record.value;
        final imageFile = File(rec.imagePath);
        final hasImage = imageFile.existsSync();
        final empty = rec.text.trim().isEmpty;

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            _Space.lg,
            _Space.md,
            _Space.lg,
            _Space.xl,
          ),
          children: [
            _ImageCard(
              file: imageFile,
              hasImage: hasImage,
              empty: empty,
              onTap: () => c.openFullImage(imageFile),
            ),
            SizedBox(height: _Space.md),
            _MetaStrip(record: rec),
            SizedBox(height: _Space.md),
            _TextCard(
              text: rec.text,
              expanded: c.textExpanded.value,
              onToggle: c.toggleExpanded,
            ),
          ],
        );
      }),
    );
  }
}

// -----------------------------------------------------------------------
// App bar
// -----------------------------------------------------------------------
class _ScanAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ScanAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: _Palette.primary,
      surfaceTintColor: ColorConstants.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        onPressed: Get.back,
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: Sizes.w(18),
          color: ColorConstants.white,
        ),
      ),
      title: Text(
        'Scan preview',
        style: _type(
          size: 17,
          weight: FontWeight.w700,
          color: ColorConstants.white,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// -----------------------------------------------------------------------
// Status chip
// -----------------------------------------------------------------------
class _StatusChip extends StatelessWidget {
  final bool empty;

  const _StatusChip({required this.empty});

  @override
  Widget build(BuildContext context) {
    final dotColor = empty ? _Palette.mutedSoft : _Palette.accent;
    final bg = empty ? _Palette.background : ColorConstants.successSoft;
    final fg = empty ? _Palette.muted : ColorConstants.success2;
    final label = empty ? 'No text' : 'Text detected';

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
            style: _type(size: 12, weight: FontWeight.w700, color: fg),
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
  final bool empty;
  final VoidCallback onTap;

  const _ImageCard({
    required this.file,
    required this.hasImage,
    required this.empty,
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
              height: Sizes.h(260),
              fit: BoxFit.cover,
            ),
          ),
          // Top fade so the status chip stays readable on any photo.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: Sizes.h(64),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ColorConstants.black.withValues(alpha: 0.35),
                    ColorConstants.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: Sizes.w(12),
            top: Sizes.w(12),
            child: _StatusChip(empty: empty),
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
                color: ColorConstants.black.withValues(alpha: 0.55),
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
    final trimmed = record.text.trim();
    final words = trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;

    return Row(
      children: [
        Expanded(
          child: _MetaPill(
            icon: Icons.calendar_today_rounded,
            value: _formatDate(record.createdAt),
            caption: 'Date',
          ),
        ),
        SizedBox(width: _Space.sm),
        Expanded(
          child: _MetaPill(
            icon: Icons.schedule_rounded,
            value: _formatTime(record.createdAt),
            caption: 'Time',
          ),
        ),
        SizedBox(width: _Space.sm),
        Expanded(
          child: _MetaPill(
            icon: Icons.notes_rounded,
            value: '$words',
            caption: words == 1 ? 'Word' : 'Words',
          ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String caption;

  const _MetaPill({
    required this.icon,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: Sizes.w(12),
        horizontal: Sizes.w(6),
      ),
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(_Radius.md),
        border: Border.all(color: _Palette.line),
        boxShadow: _softShadow,
      ),
      child: Column(
        children: [
          Container(
            height: Sizes.w(30),
            width: Sizes.w(30),
            decoration: const BoxDecoration(
              color: _Palette.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: Sizes.w(15), color: _Palette.primary),
          ),
          SizedBox(height: Sizes.w(8)),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _type(size: 13, weight: FontWeight.w700),
          ),
          SizedBox(height: Sizes.w(2)),
          Text(
            caption,
            style: _type(
              size: 11,
              weight: FontWeight.w500,
              color: _Palette.mutedSoft,
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
  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  const _TextCard({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  static const _collapsedLines = 7;

  @override
  Widget build(BuildContext context) {
    final empty = text.trim().isEmpty;
    final chars = text.trim().length;
    final isLong = chars > 220;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Sizes.w(16)),
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(_Radius.xl),
        border: Border.all(color: _Palette.line),
        boxShadow: _softShadow,
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
                      style: _type(size: 15.5, weight: FontWeight.w700),
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
            ],
          ),
          SizedBox(height: _Space.md),
          if (empty)
            const _EmptyTextState()
          else ...[
            _FilledText(
              text: text,
              maxLines: expanded || !isLong ? null : _collapsedLines,
            ),
            if (isLong)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onToggle,
                  style: TextButton.styleFrom(
                    foregroundColor: _Palette.primary,
                    padding: EdgeInsets.only(top: Sizes.w(6)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: Sizes.w(20),
                  ),
                  iconAlignment: IconAlignment.end,
                  label: Text(
                    expanded ? 'Show less' : 'Show more',
                    style: _type(
                      size: 13,
                      weight: FontWeight.w700,
                      color: _Palette.primary,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _EmptyTextState extends StatelessWidget {
  const _EmptyTextState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _Space.md),
      child: Center(
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
          ],
        ),
      ),
    );
  }
}

class _FilledText extends StatelessWidget {
  final String text;
  final int? maxLines;

  const _FilledText({required this.text, this.maxLines});

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
        maxLines: maxLines,
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
// Bottom action bar
// -----------------------------------------------------------------------
class _SaveBar extends StatelessWidget {
  final VoidCallback onSave;

  const _SaveBar({required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Palette.surface,
        border: const Border(top: BorderSide(color: _Palette.line)),
        boxShadow: [
          BoxShadow(
            color: _Palette.ink.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _Space.lg,
            _Space.md,
            _Space.lg,
            _Space.md,
          ),
          child: SizedBox(
            width: double.infinity,
            height: Sizes.h(52),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _Palette.primary,
                foregroundColor: ColorConstants.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_Radius.md),
                ),
              ),
              // icon: Icon(Icons.check_rounded, size: Sizes.w(20)),
              label: Text(
                'Save',
                style: TextStyle(
                  fontSize: Sizes.sp(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: onSave,
            ),
          ),
        ),
      ),
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
  final ukTime = date.toUtc().add(const Duration(hours: 1));

  final hour = ukTime.hour % 12 == 0 ? 12 : ukTime.hour % 12;
  final min = ukTime.minute.toString().padLeft(2, '0');

  return '$hour:$min ${ukTime.hour >= 12 ? 'PM' : 'AM'}';
}
