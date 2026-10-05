import 'package:quick_scanner/features/scan_document/screens/crop_screen.dart';
import 'package:quick_scanner/routes_list.dart';
import 'package:quick_scanner/utils/common_color.dart';
import 'package:quick_scanner/utils/common_size.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quick_scanner/features/scan_document/logic/scannercontroller.dart';
import 'package:quick_scanner/services/invoice_exterst.dart';
import '../../../services/ocr_service.dart';
import '../../../services/pdf_import_service.dart';
import '../../../services/scan_history_service.dart';
import '../../../services/models/scan_record.dart';
import '../../../networks/data_service.dart';
import '../repositiores/historyrepository.dart';
import 'package:mime/mime.dart';

const _primary = Color(0xFF4038D8);
const _primaryDark = Color(0xFF2C2AC0);
const _background = Color(0xFFF5F7FB);
const _textDark = Color(0xFF1A1B25);
const _textMuted = Color(0xFF8B8D98);
const _cardIconBg = Color(0xFFEDEDFF);
const _disabled = Color(0xFFB8B6E8);

class ScannerScreenController extends GetxController {
  final ImagePicker picker = ImagePicker();
  final OcrService ocrService = OcrService();
  final ScannerController scanner = Get.find<ScannerController>();

  final selectedImage = 0.obs;
  final isProcessing = false.obs;

  RxList<File> get images => scanner.images;
  void _selectLast() => selectedImage.value = images.length - 1;

  Future<void> camera() async {
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2400,
      maxHeight: 2400,
    );

    if (image == null || isClosed) return;

    final File? croppedImage = await Get.toNamed<dynamic>(
      RouteList.cropAdjust,
      arguments: {'image': File(image.path)},
    );

    if (croppedImage == null || isClosed) return;

    images.add(croppedImage);
    _selectLast();
  }

  // Future<void> gallery() async {
  //   final files = await picker.pickMultiImage(
  //     source: ImageSource.gallery,
  //     imageQuality: 85,
  //     maxWidth: 2400,
  //     maxHeight: 2400,
  //   );
  //
  //   if (files.isEmpty || isClosed) return;
  //
  //   for (final file in files) {
  //     if (isClosed) return;
  //
  //     final File? croppedImage = await Get.toNamed<dynamic>(
  //       RouteList.cropAdjust,
  //       arguments: {'image': File(file.path)},
  //     );
  //
  //     if (croppedImage == null || isClosed) continue;
  //
  //     images.add(croppedImage);
  //     _selectLast();
  //   }
  // }

  bool isSupportedImage(String path) {
    final mimeType = lookupMimeType(path);

    // print('File path: $path');
    // print('File name: ${path.split('/').last}');
    // print('MIME type: $mimeType');

    return mimeType == 'image/jpeg' ||
        mimeType == 'image/png' ||
        mimeType == 'image/webp';
  }

  Future<void> gallery() async {
    if (isProcessing.value) return;

    // Images and PDFs can be mixed in one selection.
    final paths = await PdfImportService.pickImageOrPdfPaths();

    if (paths.isEmpty || isClosed) return;

    bool hasUnsupportedFile = false;
    String? pdfError;

    for (final path in paths) {
      if (isClosed) return;

      // PDF: every page becomes an image (no crop step), same as the PDF card.
      if (PdfImportService.isPdf(path)) {
        isProcessing.value = true;
        try {
          images.addAll(await PdfImportService.renderPages(path));
        } on PdfImportException catch (e) {
          pdfError = e.message;
        } catch (_) {
          pdfError = 'Could not read this PDF.';
        } finally {
          if (!isClosed) isProcessing.value = false;
        }
        continue;
      }

      if (!isSupportedImage(path)) {
        hasUnsupportedFile = true;
        continue;
      }

      final File? croppedImage = await Get.toNamed<dynamic>(
        RouteList.cropAdjust,
        arguments: {'image': File(path)},
      );
      if (Get.isRegistered<CropAdjustController>(tag: path)) {
        Get.delete<CropAdjustController>(tag: path, force: true);
      }
      if (croppedImage == null || isClosed) continue;

      images.add(croppedImage);
    }

    if (isClosed) return;

    if (pdfError != null) {
      await _showNoTextAlert(title: 'PDF not supported', message: pdfError);
    } else if (hasUnsupportedFile) {
      await _showNoTextAlert(
        title: 'Unsupported file',
        message: 'Only JPG, PNG, WEBP images and PDF files are supported.',
      );
    }

    if (images.isNotEmpty && !isClosed) {
      _selectLast();
    }
  }

  Future<void> pickPdf() async {
    if (isProcessing.value) return;

    final paths = await PdfImportService.pickPdfPaths();
    if (paths.isEmpty || isClosed) return;

    isProcessing.value = true;
    try {
      for (final path in paths) {
        if (isClosed) return;
        final pages = await PdfImportService.renderPages(path);
        images.addAll(pages);
      }
      if (images.isNotEmpty) _selectLast();
    } on PdfImportException catch (e) {
      if (!isClosed) {
        _showNoTextAlert(title: 'PDF not supported', message: e.message);
      }
    } catch (e) {
      if (!isClosed) {
        _showNoTextAlert(
          title: 'PDF not supported',
          message: 'Could not read this PDF.',
        );
      }
    } finally {
      if (!isClosed) isProcessing.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    ever(images, (_) {
      if (images.isEmpty) {
        selectedImage.value = 0;
      } else if (selectedImage.value >= images.length) {
        selectedImage.value = images.length - 1;
      }
    });
  }

  double _sw(double v) => Get.width / 375 * v;
  double _sh(double v) => Get.height / 812 * v;
  double _sp(double v) => (Get.width / 375).clamp(0.85, 1.25) * v;
  Future<void> _showNoTextAlert({
    required String title,
    required String message,
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
  }

  /// OCR every page, send it straight to the backend, then show the saved
  /// result. There is no separate "extracted text" review screen.
  Future<void> process() async {
    if (images.isEmpty || isProcessing.value) return;

    isProcessing.value = true;

    try {
      final imagesCopy = List<File>.from(images);
      final textsOut = <String>[];
      final dataOut = <Map<String, dynamic>>[];

      final dynamic done = await Get.toNamed<dynamic>(
        RouteList.processing,
        arguments: {
          'imagePaths': imagesCopy.map((file) => file.path).toList(),
          'onProcess': (List<String> paths) async {
            final results = List<String>.filled(paths.length, '');
            final dataList = List<Map<String, dynamic>>.filled(
              paths.length,
              <String, dynamic>{},
            );

            // OCR up to 3 pages at once (order is preserved by index).
            // If any page has no readable text we stop right away: pages that
            // have not started yet are skipped and the user gets an alert.
            const batch = 3;
            int? emptyPage;
            for (var i = 0; i < paths.length && emptyPage == null; i += batch) {
              final end = i + batch > paths.length ? paths.length : i + batch;
              await Future.wait([
                for (var j = i; j < end; j++)
                  () async {
                    if (emptyPage != null) return;
                    final text = await ocrService.extractText(File(paths[j]));
                    if (!hasReadableText(text)) {
                      emptyPage ??= j + 1;
                      return;
                    }
                    results[j] = text;
                    dataList[j] = InvoiceExtractionService.extract(text);
                  }(),
              ]);
            }

            if (emptyPage != null) throw NoTextFoundException(emptyPage!);

            // Submit to the backend while the processing screen is still up.
            await HistoryRepository().uploadInvoicesIndividually(
              token: Get.find<TokenDataServiceImp>().accessToken,
              images: imagesCopy,
              extractedDataList: results,
              fieldsList: dataList,
            );

            textsOut.addAll(results);
            dataOut.addAll(dataList);
            return results;
          },
        },
      );

      if (isClosed) return;
      isProcessing.value = false;

      // null = OCR failed / no text (the user was already told why).
      if (done == null || textsOut.isEmpty) return;

      // Keep a local history copy, same as the old review screen did.
      final saved = <ScanRecord>[];
      for (var i = 0; i < imagesCopy.length; i++) {
        await ScanHistoryService.addRecord(
          text: textsOut[i],
          imageFile: imagesCopy[i],
          extractedData: dataOut[i],
        );
      }
      final all = ScanHistoryService.recordsNotifier.value;
      // addRecord inserts at index 0, so the newest batch is at the front.
      saved.addAll(all.take(imagesCopy.length).toList().reversed);

      images.clear();
      selectedImage.value = 0;

      if (saved.isEmpty) return;
      Get.offNamedUntil(
        RouteList.scanPreview,
        (route) => route.isFirst,
        arguments: {'record': saved.first},
      );
    } catch (e) {
      if (isClosed) return;

      isProcessing.value = false;

      Get.snackbar(
        'Error',
        'Failed to process document: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(Sizes.w(10)),
        borderRadius: Sizes.w(10),
      );
    }
  }

  void remove(int index) {
    if (index < 0 || index >= images.length) return;

    images.removeAt(index);

    if (images.isEmpty) {
      selectedImage.value = 0;
    } else if (selectedImage.value >= images.length) {
      selectedImage.value = images.length - 1;
    }
  }

  void clearImages() {
    if (images.isEmpty) return;

    images.clear();
    selectedImage.value = 0;
  }

  @override
  void onClose() {
    ocrService.dispose();
    super.onClose();
  }
}

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ScannerScreenController>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _primary,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: Column(
          children: [
            _header(c),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  Sizes.w(16),
                  Sizes.h(18),
                  Sizes.w(16),
                  0,
                ),
                child: Column(
                  children: [
                    _preview(c),
                    Obx(
                      () =>
                          c.images.isEmpty
                              ? const SizedBox.shrink()
                              : Padding(
                                padding: EdgeInsets.only(top: Sizes.h(14)),
                                child: _thumbnails(c),
                              ),
                    ),
                    SizedBox(height: Sizes.h(18)),
                    Obx(
                      () => Row(
                        children: [
                          _actionCard(
                            Icons.camera_alt_outlined,
                            'Camera',
                            'Take photo',
                            c.isProcessing.value ? null : c.camera,
                          ),
                          SizedBox(width: Sizes.w(12)),
                          _actionCard(
                            Icons.photo_library_outlined,
                            'Gallery',
                            'Images or PDF',
                            c.isProcessing.value ? null : c.gallery,
                          ),
                          SizedBox(width: Sizes.w(12)),
                          _actionCard(
                            Icons.picture_as_pdf_outlined,
                            'PDF',
                            'Pick file',
                            c.isProcessing.value ? null : c.pickPdf,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: Sizes.h(18)),
                    _processButton(c),
                    SizedBox(height: Sizes.h(18)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------

  Widget _header(ScannerScreenController c) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x333038D8),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Sizes.w(12),
            Sizes.h(8),
            Sizes.w(16),
            Sizes.h(18),
          ),
          child: Obx(() {
            final count = c.images.length;

            return Row(
              children: [
                _circleIconButton(Icons.arrow_back_ios, () => Get.back()),
                SizedBox(width: Sizes.w(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan Documents',
                        style: TextStyle(
                          fontSize: Sizes.sp(18),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: Sizes.h(2)),
                      Text(
                        count == 0
                            ? 'Capture or upload invoices'
                            : '$count document${count == 1 ? '' : 's'} ready',
                        style: TextStyle(
                          fontSize: Sizes.sp(12),
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (count > 0)
                  _circleIconButton(
                    Icons.delete_outline,
                    c.isProcessing.value ? () {} : c.clearImages,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _circleIconButton(IconData icon, VoidCallback onTap) {
    final size = Sizes.w(40);

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Icon(icon, size: Sizes.w(19), color: Colors.white),
      ),
    );
  }

  Widget _preview(ScannerScreenController c) {
    return Container(
      height: Sizes.h(300),
      width: double.infinity,
      padding: EdgeInsets.all(Sizes.w(8)),
      decoration: _box(),
      child: Obx(() {
        final images = c.images;
        final selected = c.selectedImage.value;

        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Sizes.w(14)),
              child: SizedBox.expand(
                child:
                    images.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.all(Sizes.w(16)),
                                decoration: const BoxDecoration(
                                  color: _cardIconBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.document_scanner_outlined,
                                  size: Sizes.w(40),
                                  color: _primary,
                                ),
                              ),
                              SizedBox(height: Sizes.h(20)),
                              Text(
                                'No document selected',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: Sizes.sp(14),
                                  color: _textDark,
                                ),
                              ),
                              SizedBox(height: Sizes.h(6)),
                              Text(
                                'Use your camera, gallery or a PDF to upload',
                                style: TextStyle(
                                  color: _textMuted,
                                  fontSize: Sizes.sp(12),
                                ),
                              ),
                            ],
                          ),
                        )
                        : Image.file(images[selected], fit: BoxFit.contain),
              ),
            ),
            if (images.length > 1)
              Positioned(
                top: Sizes.h(10),
                right: Sizes.w(10),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Sizes.w(10),
                    vertical: Sizes.h(5),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(Sizes.w(20)),
                  ),
                  child: Text(
                    '${selected + 1} / ${images.length}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: Sizes.sp(11.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _thumbnails(ScannerScreenController c) {
    return Container(
      padding: EdgeInsets.all(Sizes.w(12)),
      decoration: _box(),
      child: SizedBox(
        height: Sizes.h(65),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: c.images.length,
          itemBuilder: (context, index) {
            return Obx(() {
              final selected = index == c.selectedImage.value;

              return GestureDetector(
                onTap: () => c.selectedImage.value = index,
                child: Container(
                  width: Sizes.w(60),
                  margin: EdgeInsets.only(right: Sizes.w(8)),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Sizes.w(8)),
                    border: Border.all(
                      color: selected ? _primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Sizes.w(6)),
                        child: Image.file(
                          c.images[index],
                          width: Sizes.w(60),
                          height: Sizes.h(65),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 1,
                        top: 1,
                        child: GestureDetector(
                          onTap: () => c.remove(index),
                          child: CircleAvatar(
                            radius: Sizes.w(9),
                            backgroundColor: Colors.redAccent,
                            child: Icon(
                              Icons.close,
                              size: Sizes.w(12),
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            });
          },
        ),
      ),
    );
  }

  Widget _actionCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? onTap,
  ) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Sizes.w(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Sizes.w(16)),
          child: Opacity(
            opacity: onTap == null ? 0.5 : 1,
            child: Container(
              height: Sizes.h(100),
              padding: EdgeInsets.all(Sizes.w(14)),
              decoration: _box(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(Sizes.w(8)),
                    decoration: BoxDecoration(
                      color: _cardIconBg,
                      borderRadius: BorderRadius.circular(Sizes.w(10)),
                    ),
                    child: Icon(icon, color: _primary, size: Sizes.w(20)),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: Sizes.sp(13),
                      color: _textDark,
                    ),
                  ),
                  SizedBox(height: Sizes.h(2)),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: Sizes.sp(10.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _processButton(ScannerScreenController c) {
    return SizedBox(
      width: double.infinity,
      height: Sizes.h(52),
      child: Obx(() {
        final count = c.images.length;
        final processing = c.isProcessing.value;

        return ElevatedButton.icon(
          onPressed: count == 0 || processing ? null : c.process,
          icon:
              processing
                  ? SizedBox(
                    width: Sizes.w(20),
                    height: Sizes.w(20),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Icon(Icons.document_scanner_outlined),
          label: Text(
            processing
                ? 'Processing...'
                : 'Process $count Document${count == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: Sizes.sp(15),
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _disabled,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Sizes.w(14)),
            ),
          ),
        );
      }),
    );
  }

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(Sizes.w(16)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x10000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    );
  }
}
