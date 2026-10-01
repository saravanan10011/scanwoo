import 'package:quick_scanner/features/scan_document/screens/scanner_screen.dart';
import 'package:quick_scanner/utils/common_color.dart';
import 'package:quick_scanner/routes_list.dart';
import 'package:quick_scanner/utils/common_size.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/features/scan_document/logic/scannercontroller.dart';
import 'package:quick_scanner/features/scan_document/repositiores/historyrepository.dart';
import '../../../services/models/scan_record.dart';
import '../../../networks/data_service.dart';
import '../../../services/scan_history_service.dart';

class MultiDocumentResultController extends GetxController {
  final List<File> initialImages;
  final List<String> extractedTexts;
  final List<Map<String, dynamic>>? initialExtractedDataList;

  MultiDocumentResultController({
    required this.initialImages,
    required this.extractedTexts,
    this.initialExtractedDataList,
  });

  // Mutable local copies so individual documents can be removed (cancelled)
  // before saving, without touching the original widget-level lists.
  late final RxList<File> images;
  late final List<Map<String, dynamic>> extractedDataList;
  late final List<TextEditingController> controllers;

  final currentIndex = 0.obs;
  final saving = false.obs;
  final canFinish = false.obs;
  final currentHasText = false.obs;
  final emptyDocs = <int>[].obs;

  @override
  void onInit() {
    super.onInit();

    images = List<File>.from(initialImages).obs;

    extractedDataList = List<Map<String, dynamic>>.generate(
      initialImages.length,
      (i) =>
          initialExtractedDataList != null &&
                  i < initialExtractedDataList!.length
              ? initialExtractedDataList![i]
              : <String, dynamic>{},
    );

    controllers = List.generate(initialImages.length, (i) {
      final ctrl = TextEditingController(
        text: i < extractedTexts.length ? extractedTexts[i] : '',
      );
      ctrl.addListener(_updateCanFinish);
      return ctrl;
    });
    ever(currentIndex, (_) => _updateCanFinish());

    _updateCanFinish();
  }

  void removeImage(int index) {
    if (saving.value || images.length <= 1) {
      if (images.length <= 1) {
        _snack('At least one document is required');
      }
      return;
    }

    final removedFile = images[index];

    images.removeAt(index);
    extractedDataList.removeAt(index);

    final removedController = controllers.removeAt(index);
    removedController.dispose();

    // Keep the Scan Documents screen in sync
    _removeFromScanner(removedFile);

    if (currentIndex.value >= images.length) {
      currentIndex.value = images.length - 1;
    } else if (currentIndex.value > index) {
      currentIndex.value--;
    }

    _updateCanFinish();
  }

  void _removeFromScanner(File file) {
    if (!Get.isRegistered<ScannerController>()) return;

    final scannerImages = Get.find<ScannerController>().images;
    scannerImages.removeWhere((f) => f.path == file.path);

    // Keep the Scan Documents screen's selected thumbnail in range
    if (Get.isRegistered<ScannerScreenController>()) {
      final sc = Get.find<ScannerScreenController>();
      if (scannerImages.isEmpty) {
        sc.selectedImage.value = 0;
      } else if (sc.selectedImage.value >= scannerImages.length) {
        sc.selectedImage.value = scannerImages.length - 1;
      }
    }
  }

  bool get hasEmptyText => controllers.any((c) => c.text.trim().isEmpty);

  void _updateCanFinish() {
    canFinish.value = !hasEmptyText;

    final i = currentIndex.value;
    currentHasText.value =
        i >= 0 &&
        i < controllers.length &&
        controllers[i].text.trim().isNotEmpty;

    final empty = <int>[
      for (int k = 0; k < controllers.length; k++)
        if (controllers[k].text.trim().isEmpty) k + 1,
    ];
    if (empty.join(',') != emptyDocs.join(',')) {
      emptyDocs.assignAll(empty);
    }
  }

  @override
  void onClose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.onClose();
  }

  void _snack(String message, {Color? backgroundColor}) {
    final ctx = Get.context;
    if (ctx == null) return;
    final messenger = ScaffoldMessenger.of(ctx);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    );
  }

  Future<void> copyText() async {
    await Clipboard.setData(
      ClipboardData(text: controllers[currentIndex.value].text),
    );
    _snack('Text copied', backgroundColor: ColorConstants.primary);
  }

  /// Returns the extracted-fields map for document [i], or an empty map
  /// if extraction wasn't run / wasn't passed in for this document.
  Map<String, dynamic> _dataFor(int i) {
    if (i < 0 || i >= extractedDataList.length) {
      return const {};
    }
    return extractedDataList[i];
  }

  void goTo(int index) {
    if (saving.value) return;
    currentIndex.value = index;
  }

  void previous() {
    if (saving.value || currentIndex.value == 0) return;
    currentIndex.value--;
  }

  /// Called when Next / Finish is tapped.
  /// Shows an alert if the required document(s) have no extracted text.
  void onActionTap() {
    if (saving.value) return;

    final isLast = currentIndex.value == images.length - 1;

    // Current document has no text
    if (!currentHasText.value) {
      _showNoTextAlert(
        title: 'No extracted text',
        message:
            'Document ${currentIndex.value + 1} has no text. Please add text or remove it.',
      );
      return;
    }

    // Finish: some other document has no text
    if (isLast && !canFinish.value) {
      _showNoTextAlert(
        title: 'Missing extracted text',
        message:
            'Document ${emptyDocs.join(', ')} has no extracted text.\n\n'
            'Please enter the text or remove the document before finishing.',
        jumpTo: emptyDocs.first - 1,
      );
      return;
    }

    nextOrFinish();
  }

  double _sw(double v) => Get.width / 375 * v;
  double _sh(double v) => Get.height / 812 * v;
  double _sp(double v) => (Get.width / 375).clamp(0.85, 1.25) * v;
  Future<void> _showNoTextAlert({
    required String title,
    required String message,
    int? jumpTo,
  }) async {
    await Get.dialog(
      Dialog(
        backgroundColor: ColorConstants.white,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(horizontal: _sw(28)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_sw(24)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(_sw(22), _sh(26), _sw(22), _sh(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon badge with soft halo
              Container(
                padding: EdgeInsets.all(_sw(10)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ColorConstants.danger.withValues(alpha: 0.08),
                ),
                child: Container(
                  width: _sw(56),
                  height: _sw(56),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ColorConstants.danger.withValues(alpha: 0.14),
                  ),
                  child: Icon(
                    Icons.text_snippet_outlined,
                    color: ColorConstants.danger,
                    size: _sp(28),
                  ),
                ),
              ),
              SizedBox(height: _sh(18)),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: ColorConstants.textDark2,
                  fontSize: _sp(18),
                  height: 1.25,
                ),
              ),
              SizedBox(height: _sh(8)),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ColorConstants.textMuted2,
                  fontSize: _sp(13.5),
                  height: 1.45,
                ),
              ),
              SizedBox(height: _sh(22)),
              SizedBox(
                width: double.infinity,
                height: _sh(46),
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorConstants.primary,
                    foregroundColor: ColorConstants.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_sw(14)),
                    ),
                  ),
                  child: Text(
                    'Got it',
                    style: TextStyle(
                      fontSize: _sp(15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );

    // After closing, jump to the first empty document
    if (jumpTo != null) goTo(jumpTo);
  }

  void nextOrFinish() {
    if (saving.value) return;
    if (!currentHasText.value) return;

    if (currentIndex.value == images.length - 1) {
      if (!canFinish.value) return;
      saveDocuments();
    } else {
      currentIndex.value++;
    }
  }

  // void removeImage(int index) {
  //   if (saving.value || images.length <= 1) {
  //     if (images.length <= 1) {
  //       _snack('At least one document is required');
  //     }
  //     return;
  //   }

  //   images.removeAt(index);
  //   extractedDataList.removeAt(index);

  //   final removedController = controllers.removeAt(index);
  //   removedController.dispose();

  //   if (currentIndex.value >= images.length) {
  //     currentIndex.value = images.length - 1;
  //   } else if (currentIndex.value > index) {
  //     currentIndex.value--;
  //   }

  //   _updateCanFinish();
  // }

  Future<void> confirmRemoveImage(int index) async {
    if (saving.value) return;

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: ColorConstants.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove document?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: ColorConstants.textDark2,
          ),
        ),
        content: const Text(
          'This document will be removed from the batch and won\'t be saved.',
          style: TextStyle(color: ColorConstants.textMuted2, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: ColorConstants.textMuted2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text(
              'Remove',
              style: TextStyle(
                color: ColorConstants.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      removeImage(index);
    }
  }

  Future<void> saveDocuments() async {
    if (saving.value) return;

    saving.value = true;

    try {
      final historyRepository = HistoryRepository();
      final tokenDataService = Get.find<TokenDataServiceImp>();

      final batchImages = <File>[];
      final batchTexts = <String>[];

      for (int i = 0; i < images.length; i++) {
        final text = controllers[i].text.trim();
        if (text.isEmpty) continue;

        batchImages.add(images[i]);
        batchTexts.add(text);
      }

      debugPrint('Uploading with token: ${tokenDataService.accessToken}');
      if (batchImages.isNotEmpty) {
        try {
          await historyRepository.uploadInvoicesIndividually(
            token: tokenDataService.accessToken,
            images: batchImages,
            extractedDataList: batchTexts,
          );
        } catch (e) {
          debugPrint('Individual uploads failed: $e');
        }
      }

      final savedRecords = <ScanRecord>[];

      for (int i = 0; i < images.length; i++) {
        final text = controllers[i].text.trim();

        if (text.isEmpty) continue;

        final data = _dataFor(i);

        final record = ScanRecord(
          text: text,
          imagePath: images[i].path,
          createdAt: DateTime.now(),
          supplier: data['supplier'],
          vatNumber: data['vat_number'],
          invoiceNo: data['invoice_no'],
          branch: data['branch'],
          date: data['date'],
          net: data['net'],
          vat: data['vat'],
          gross: data['gross'],
          payment: data['payment'],
        );

        await ScanHistoryService.addRecord(
          text: text,
          imageFile: images[i],
          extractedData: data,
        );

        savedRecords.add(record);
      }

      if (savedRecords.isEmpty) {
        saving.value = false;
        _snack(
          'No documents available to save',
          backgroundColor: ColorConstants.red,
        );
        return;
      }

      final records = ScanHistoryService.recordsNotifier.value;

      final actualRecords = <ScanRecord>[];

      for (int i = 0; i < images.length; i++) {
        final imagePath = images[i].path;

        final matches = records.where(
          (record) => record.imagePath == imagePath,
        );

        if (matches.isNotEmpty) {
          actualRecords.add(matches.last);
        }
      }

      final firstRecord =
          actualRecords.isNotEmpty ? actualRecords.first : savedRecords.first;

      saving.value = false;

      // Everything is saved, so clear the scanner's pending images
      if (Get.isRegistered<ScannerController>()) {
        Get.find<ScannerController>().images.clear();
      }

      // Remove Scanner and Result from the stack, keeping Home at the bottom
      Get.offNamedUntil(
        RouteList.scanPreview,
        (route) => route.isFirst,
        arguments: {'record': firstRecord},
      );
    } catch (e) {
      saving.value = false;
      _snack('Failed to save: $e', backgroundColor: ColorConstants.red);
    }
  }
}

class MultiDocumentResultScreen extends StatelessWidget {
  final List<File> images;
  final List<String> extractedTexts;
  final List<Map<String, dynamic>>? extractedDataList;

  const MultiDocumentResultScreen({
    super.key,
    required this.images,
    required this.extractedTexts,
    this.extractedDataList,
  });

  @override
  Widget build(BuildContext context) {
    final c = Get.put(
      MultiDocumentResultController(
        initialImages: images,
        extractedTexts: extractedTexts,
        initialExtractedDataList: extractedDataList,
      ),
    );

    return Obx(
      () => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: ColorConstants.primaryDark,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: ColorConstants.backgroundAlt,
          appBar: AppBar(
            backgroundColor: ColorConstants.primaryDark,
            foregroundColor: ColorConstants.white,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Extracted Documents',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Document ${c.currentIndex.value + 1} of ${c.images.length}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: ColorConstants.white70,
                  ),
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: Sizes.wp(0.04),
              vertical: Sizes.hp(0.018),
            ),
            child: Column(
              children: [
                _image(c),
                SizedBox(height: Sizes.hp(0.016)),
                _documents(c),
                SizedBox(height: Sizes.hp(0.016)),
                _textBox(c),
                SizedBox(height: Sizes.hp(0.016)),
                _navigation(c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _image(MultiDocumentResultController c) {
    return Container(
      height: Sizes.hp(0.23),
      width: Sizes.screenWidth,
      padding: const EdgeInsets.all(10),
      decoration: _card(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: ColorConstants.surfaceGray,
          child: InteractiveViewer(
            child: Image.file(
              c.images[c.currentIndex.value],
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _documents(MultiDocumentResultController c) {
    // Read observables here (inside the screen's single Obx), not in itemBuilder.
    final currentIndex = c.currentIndex.value;
    final saving = c.saving.value;

    return Container(
      height: Sizes.hp(0.115),
      padding: const EdgeInsets.all(12),
      decoration: _card(),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: c.images.length,
        separatorBuilder: (_, _) => SizedBox(width: Sizes.wp(0.02)),
        itemBuilder: (_, index) {
          final selected = index == currentIndex;
          final thumbSize = Sizes.wp(0.15);

          return GestureDetector(
            onTap: saving ? null : () => c.goTo(index),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          selected
                              ? ColorConstants.primary
                              : ColorConstants.surfaceMuted,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow:
                        selected
                            ? [
                              BoxShadow(
                                color: ColorConstants.primary.withValues(
                                  alpha: 0.25,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                            : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(c.images[index], fit: BoxFit.cover),
                  ),
                ),
                if (!saving)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: () => c.confirmRemoveImage(index),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: ColorConstants.danger,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ColorConstants.white,
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: ColorConstants.shadow20,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: ColorConstants.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _navigation(MultiDocumentResultController c) {
    final saving = c.saving.value;
    final isFirst = c.currentIndex.value == 0;
    final isLast = c.currentIndex.value == c.images.length - 1;
    final canFinish = c.canFinish.value;
    final currentHasText = c.currentHasText.value;

    // Looks "ready" only when the action is allowed; still tappable to show the alert.
    final ready = currentHasText && (!isLast || canFinish);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Step indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(c.images.length, (i) {
            final active = i == c.currentIndex.value;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? ColorConstants.primary : ColorConstants.border2,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: (saving || isFirst) ? 0.4 : 1,
                  child: OutlinedButton.icon(
                    onPressed: (saving || isFirst) ? null : c.previous,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorConstants.textDark2,
                      disabledForegroundColor: ColorConstants.textDark2,
                      side: const BorderSide(color: ColorConstants.border2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text(
                      'Previous',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: saving ? null : c.onActionTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        ready
                            ? ColorConstants.primary
                            : ColorConstants.gray500.withValues(alpha: 0.5),
                    foregroundColor:
                        ready
                            ? ColorConstants.white
                            : ColorConstants.white.withValues(alpha: 0.8),
                    disabledBackgroundColor: ColorConstants.gray500.withValues(
                      alpha: 0.5,
                    ),
                    disabledForegroundColor: ColorConstants.white.withValues(
                      alpha: 0.8,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  icon:
                      saving
                          ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                ColorConstants.white,
                              ),
                            ),
                          )
                          : Icon(
                            isLast
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            size: 19,
                          ),
                  label: Text(
                    saving
                        ? 'Saving...'
                        : isLast
                        ? 'Finish'
                        : 'Next',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _textBox(MultiDocumentResultController c) {
    final controller = c.controllers[c.currentIndex.value];

    return Container(
      height: Sizes.hp(0.28),
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ColorConstants.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.text_snippet_rounded,
                  color: ColorConstants.primary,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Extracted Text',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: ColorConstants.textDark2,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              key: ObjectKey(controller),
              controller: controller,
              enabled: !c.saving.value,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontSize: 13.5,
                color: ColorConstants.textDark2,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText: 'Extracted text',
                hintStyle: const TextStyle(color: ColorConstants.textMuted2),
                filled: true,
                fillColor: ColorConstants.surfaceAlt,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: ColorConstants.primary,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _card() {
    return BoxDecoration(
      color: ColorConstants.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: ColorConstants.surfaceMuted),
      boxShadow: [
        BoxShadow(
          color: ColorConstants.black.withValues(alpha: .04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
