import 'package:quick_scanner/utils/common_color.dart';
import 'package:quick_scanner/utils/common_size.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/features/history/model/history_model.dart'
    hide Image;

const primary = ColorConstants.primary;
const primaryLight = ColorConstants.primaryLight;
const background = ColorConstants.background;

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class InvoiceImagesController extends GetxController {
  final PageController page = PageController();
  final index = 0.obs;

  void onPageChanged(int i) => index.value = i;

  void goTo(int i) {
    page.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void onClose() {
    page.dispose();
    super.onClose();
  }
}

// ---------------------------------------------------------------------------
// Invoice images dialog
// ---------------------------------------------------------------------------

class InvoiceImagesDialog extends StatelessWidget {
  final InvoiceData invoice;

  const InvoiceImagesDialog({super.key, required this.invoice});

  static const _viewerBg = Color(0xFF0F172A);

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final images = invoice.images;

    return GetBuilder<InvoiceImagesController>(
      init: InvoiceImagesController(),
      autoRemove: true,
      builder: (c) {
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
                _header(images.length),
                if (images.isEmpty)
                  _empty()
                else ...[
                  Flexible(child: _viewer(c, images)),
                  _fileInfo(c, images),
                  if (images.length > 1) _thumbs(c, images),
                ],
                _footer(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- Header
  Widget _header(int count) {
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
                  'Uploaded Images',
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
                  '$count ${count == 1 ? 'image' : 'images'} attached',
                  style: TextStyle(
                    fontSize: Sizes.sp(12),
                    color: ColorConstants.textMuted,
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

  // ---- Image viewer (dark, with overlays)
  Widget _viewer(InvoiceImagesController c, List<dynamic> images) {
    return Container(
      color: _viewerBg,
      height: Sizes.hp(0.46),
      child: Stack(
        children: [
          PageView.builder(
            controller: c.page,
            itemCount: images.length,
            onPageChanged: c.onPageChanged,
            itemBuilder: (_, i) {
              final img = images[i];
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    img.url,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      final total = progress.expectedTotalBytes;
                      return Center(
                        child: CircularProgressIndicator(
                          value:
                              total == null
                                  ? null
                                  : progress.cumulativeBytesLoaded / total,
                          color: primaryLight,
                          strokeWidth: 2.5,
                        ),
                      );
                    },
                    errorBuilder:
                        (_, _, _) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: Sizes.w(42),
                              color: Colors.white54,
                            ),
                            SizedBox(height: Sizes.h(8)),
                            Text(
                              'Unable to load image',
                              style: TextStyle(
                                fontSize: Sizes.sp(12.5),
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                  ),
                ),
              );
            },
          ),

          // Counter pill
          Positioned(
            top: Sizes.h(10),
            right: Sizes.w(10),
            child: Obx(
              () => Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Sizes.w(10),
                  vertical: Sizes.h(4),
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(Sizes.w(20)),
                ),
                child: Text(
                  '${c.index.value + 1} / ${images.length}',
                  style: TextStyle(
                    fontSize: Sizes.sp(11.5),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Dots
          if (images.length > 1)
            Positioned(
              bottom: Sizes.h(10),
              left: 0,
              right: 0,
              child: Obx(
                () => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(images.length, (i) {
                    final active = i == c.index.value;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: EdgeInsets.symmetric(horizontal: Sizes.w(3)),
                      width: active ? Sizes.w(18) : Sizes.w(6),
                      height: Sizes.w(6),
                      decoration: BoxDecoration(
                        color: active ? Colors.white : Colors.white38,
                        borderRadius: BorderRadius.circular(Sizes.w(6)),
                      ),
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---- File info
  Widget _fileInfo(InvoiceImagesController c, List<dynamic> images) {
    return Obx(() {
      final img = images[c.index.value];
      return Padding(
        padding: EdgeInsets.fromLTRB(
          Sizes.w(18),
          Sizes.h(14),
          Sizes.w(18),
          Sizes.h(6),
        ),
        child: Row(
          children: [
            Icon(
              Icons.image_outlined,
              size: Sizes.w(18),
              color: ColorConstants.textMuted,
            ),
            SizedBox(width: Sizes.w(8)),
            Expanded(
              child: Text(
                img.originalName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: Sizes.sp(13),
                  fontWeight: FontWeight.w700,
                  color: ColorConstants.textDark,
                ),
              ),
            ),
            SizedBox(width: Sizes.w(8)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: Sizes.w(8),
                vertical: Sizes.h(3),
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(Sizes.w(20)),
              ),
              child: Text(
                _size(img.size),
                style: TextStyle(
                  fontSize: Sizes.sp(11),
                  fontWeight: FontWeight.w600,
                  color: ColorConstants.textMuted,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ---- Thumbnails
  Widget _thumbs(InvoiceImagesController c, List<dynamic> images) {
    return SizedBox(
      height: Sizes.w(68),
      child: Obx(() {
        // FIX: read the observable here, while the Obx builds. ListView calls
        // itemBuilder later (at layout time), so reading c.index.value only
        // there makes GetX throw "improper use of a GetX".
        final current = c.index.value;

        return ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(
            horizontal: Sizes.w(18),
            vertical: Sizes.h(8),
          ),
          itemCount: images.length,
          separatorBuilder: (_, _) => SizedBox(width: Sizes.w(8)),
          itemBuilder: (_, i) {
            final active = i == current; // FIX: use the value read above
            return GestureDetector(
              onTap: () => c.goTo(i),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: active ? 1 : 0.6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: Sizes.w(52),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Sizes.w(10)),
                    border: Border.all(
                      color: active ? primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    images[i].url,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, _, _) => Container(
                          color: background,
                          child: Icon(
                            Icons.image_outlined,
                            size: Sizes.w(18),
                            color: ColorConstants.textMuted,
                          ),
                        ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  // ---- Empty state
  Widget _empty() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Sizes.h(40)),
      child: Column(
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: Sizes.w(44),
            color: ColorConstants.textMuted,
          ),
          SizedBox(height: Sizes.h(10)),
          Text(
            'No images available',
            style: TextStyle(
              fontSize: Sizes.sp(13),
              color: ColorConstants.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Footer
  Widget _footer() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Sizes.w(18),
        Sizes.h(8),
        Sizes.w(18),
        Sizes.h(16),
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
