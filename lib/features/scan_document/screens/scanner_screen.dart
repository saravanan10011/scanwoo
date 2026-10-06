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

  /// false = "Multiple invoices" (each image is its own invoice)
  /// true  = "Single invoice"    (all images are pages of ONE invoice)
  final oneInvoice = false.obs;

  /// A single invoice can have at most this many pages.
  // static const maxPages = 20;

  // bool get _atLimit => oneInvoice.value && images.length >= maxPages;
  //
  // /// Shows a message and returns true when no more pages can be added.
  // bool _checkLimit() {
  //   if (!_atLimit) return false;
  //   Get.snackbar(
  //     'Page limit reached',
  //     'A single invoice can have up to $maxPages pages.',
  //     backgroundColor: Colors.redAccent,
  //     colorText: Colors.white,
  //     snackPosition: SnackPosition.BOTTOM,
  //     margin: EdgeInsets.all(Sizes.w(10)),
  //     borderRadius: Sizes.w(10),
  //   );
  //   return true;
  // }

  void setMode(bool one) {
    oneInvoice.value = one;
    if (one) {
      scanner.groupAllAsOne();
    } else {
      scanner.separateAll();
    }
  }

  /// Mode switch from the selector. Asks first when it would change existing pages.
  Future<void> requestMode(bool one) async {
    if (isProcessing.value || one == oneInvoice.value) return;

    final count = images.length;

    if (one && count > 1) {
      // if (count > maxPages) {
      //   await _showNoTextAlert(
      //     title: 'Too many pages',
      //     message:
      //         'A single invoice can have up to $maxPages pages. '
      //         'Remove some images first.',
      //   );
      //   return;
      // }
      final bills = scanner.buildGroups(images.toList()).length;
      if (bills > 1) {
        final ok = await _confirm(
          title: 'Combine into one invoice?',
          message: 'All $count images will be uploaded as ONE invoice.',
          action: 'Combine',
        );
        if (!ok) return;
      }
    } else if (!one && count > 1) {
      final ok = await _confirm(
        title: 'Upload as separate invoices?',
        message: 'Each of the $count images will become its own invoice.',
        action: 'Separate',
      );
      if (!ok) return;
    }

    setMode(one);
  }

  /// Drag a page to a new position (single-invoice mode).
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    final f = images.removeAt(oldIndex);
    images.insert(newIndex, f);
    selectedImage.value = newIndex;
  }

  RxList<File> get images => scanner.images;
  void _selectLast() => selectedImage.value = images.length - 1;

  /// Adds one scanned / picked image. In "single invoice" mode it joins the invoice.
  void _addPage(File file) {
    images.add(file);
    if (oneInvoice.value) scanner.groupAllAsOne();
  }

  /// All pages of one PDF are one bill.
  void _groupPages(List<File> pages) {
    if (pages.length >= 2) {
      final id = scanner.newGroupId();
      for (final f in pages) {
        scanner.pageGroup[f.path] = id;
      }
      scanner.fileGroups.add(id); // a PDF file is always one invoice
    }
    if (oneInvoice.value) scanner.groupAllAsOne();
  }

  Future<void> camera() async {
    // if (_checkLimit()) return;

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

    _addPage(croppedImage);
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

    // if (_checkLimit()) return;

    for (final path in paths) {
      if (isClosed) return;

      // PDF: every page becomes an image (no crop step), same as the PDF card.
      if (PdfImportService.isPdf(path)) {
        isProcessing.value = true;
        try {
          final pages = await PdfImportService.renderPages(path);
          if (oneInvoice.value) {
            continue;
          }
          images.addAll(pages);
          _groupPages(pages); // all pages of one PDF = one bill
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

      // if (_atLimit) {
      //   limitHit = true;
      //   continue;
      // }

      final File? croppedImage = await Get.toNamed<dynamic>(
        RouteList.cropAdjust,
        arguments: {'image': File(path)},
      );
      if (Get.isRegistered<CropAdjustController>(tag: path)) {
        Get.delete<CropAdjustController>(tag: path, force: true);
      }
      if (croppedImage == null || isClosed) continue;

      _addPage(croppedImage);
    }

    if (isClosed) return;

    if (pdfError != null) {
      await _showNoTextAlert(title: 'PDF not supported', message: pdfError);
      // } else if (limitHit) {
      //   // await _showNoTextAlert(
      //   title: 'Page limit reached',
      //   message: 'A single invoice can have up to $maxPages pages.',
      // );
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
        // if (oneInvoice.value && images.length + pages.length > maxPages) {
        //   throw PdfImportException(
        //     'A single invoice can have up to $maxPages pages.',
        //   );
        // }
        images.addAll(pages);
        _groupPages(pages); // all pages of one PDF = one bill
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

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    IconData icon = Icons.help_outline_rounded,
  }) async {
    final result = await Get.dialog<bool>(
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
                  color: ColorConstants.primary.withValues(alpha: 0.08),
                ),
                child: Container(
                  width: _sw(56),
                  height: _sw(56),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ColorConstants.primary.withValues(alpha: 0.14),
                  ),
                  child: Icon(
                    icon,
                    color: ColorConstants.primary,
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
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: _sh(46),
                      child: OutlinedButton(
                        onPressed: () => Get.back(result: false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ColorConstants.textDark2,
                          side: BorderSide(
                            color: ColorConstants.textMuted2.withValues(
                              alpha: 0.35,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_sw(14)),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: _sp(15),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: _sw(12)),
                  Expanded(
                    child: SizedBox(
                      height: _sh(46),
                      child: ElevatedButton(
                        onPressed: () => Get.back(result: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorConstants.primary,
                          foregroundColor: ColorConstants.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_sw(14)),
                          ),
                        ),
                        child: Text(
                          action,
                          style: TextStyle(
                            fontSize: _sp(15),
                            fontWeight: FontWeight.w700,
                          ),
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
      barrierDismissible: true,
    );
    return result ?? false; // tapping outside = cancel
  }

  /// OCR every page, send it straight to the backend, then show the saved
  /// result. There is no separate "extracted text" review screen.
  Future<void> process() async {
    if (images.isEmpty || isProcessing.value) return;

    // if (oneInvoice.value && images.length > maxPages) {
    //   await _showNoTextAlert(
    //     title: 'Too many pages',
    //     message: 'A single invoice can have up to $maxPages pages.',
    //   );
    //   return;
    // }

    isProcessing.value = true;

    try {
      final imagesCopy = List<File>.from(images);
      // "Single invoice" must upload exactly ONE invoice, whatever happened
      // before (merge / split, removed pages ...).
      if (oneInvoice.value) scanner.groupAllAsOne();
      final groups = scanner.buildGroups(
        imagesCopy,
      ); // e.g. [[0], [1, 2, 3], [4]]
      assert(!oneInvoice.value || groups.length == 1);

      final groupFiles = <List<File>>[];
      final textsOut = <String>[]; // one per bill
      final dataOut = <Map<String, dynamic>>[]; // one per bill

      final dynamic done = await Get.toNamed<dynamic>(
        RouteList.processing,
        arguments: {
          'imagePaths': imagesCopy.map((file) => file.path).toList(),
          'onProcess': (List<String> paths) async {
            final results = List<String>.filled(paths.length, '');

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
                  }(),
              ]);
            }

            if (emptyPage != null) throw NoTextFoundException(emptyPage!);

            // Join the pages of each bill (page 1 first), extract ONCE per bill.
            final groupTexts = <String>[];
            final groupData = <Map<String, dynamic>>[];
            for (final g in groups) {
              groupFiles.add([for (final i in g) imagesCopy[i]]);
              final joined = g.map((i) => results[i]).join('\n');
              groupTexts.add(joined);
              groupData.add(InvoiceExtractionService.extract(joined));
            }

            // One request per bill; a multi-page bill sends all its pages.
            await HistoryRepository().uploadInvoiceGroups(
              token: Get.find<TokenDataServiceImp>().accessToken,
              groups: groupFiles,
              extractedDataList: groupTexts,
              fieldsList: groupData,
            );

            textsOut.addAll(groupTexts);
            dataOut.addAll(groupData);
            return results;
          },
        },
      );

      if (isClosed) return;
      isProcessing.value = false;

      // null = OCR failed / no text (the user was already told why).
      if (done == null || textsOut.isEmpty) return;

      // Keep a local history copy: one record per BILL (first page = thumbnail).
      final saved = <ScanRecord>[];
      for (var i = 0; i < groupFiles.length; i++) {
        await ScanHistoryService.addRecord(
          text: textsOut[i],
          imageFile: groupFiles[i].first,
          extractedData: dataOut[i],
        );
      }
      final all = ScanHistoryService.recordsNotifier.value;
      // addRecord inserts at index 0, so the newest batch is at the front.
      saved.addAll(all.take(groupFiles.length).toList().reversed);

      images.clear();
      scanner.resetGroups();
      oneInvoice.value = false;
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

    scanner.pageGroup.remove(images[index].path);
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
    scanner.resetGroups();
    oneInvoice.value = false;
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
                    _modeSelector(c),
                    SizedBox(height: Sizes.h(14)),
                    _preview(c),
                    _bills(c),
                    SizedBox(height: Sizes.h(18)),
                    Obx(
                      () => Row(
                        children: [
                          _actionCard(
                            Icons.camera_alt_outlined,
                            'Camera',
                            c.oneInvoice.value ? 'Add a page' : 'Take photo',
                            c.isProcessing.value ? null : c.camera,
                          ),
                          SizedBox(width: Sizes.w(12)),
                          _actionCard(
                            Icons.photo_library_outlined,
                            'Gallery',
                            c.oneInvoice.value ? 'Add pages' : 'Images or PDF',
                            c.isProcessing.value ? null : c.gallery,
                          ),
                          SizedBox(width: Sizes.w(12)),
                          _actionCard(
                            Icons.picture_as_pdf_outlined,
                            'PDF',
                            c.oneInvoice.value ? 'Add PDF pages' : 'Pick file',
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
            final bills = c.scanner.buildGroups(c.images.toList()).length;

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
                            : bills == count
                            ? '$bills invoice${bills == 1 ? '' : 's'} ready'
                            : '$bills invoice${bills == 1 ? '' : 's'} · $count pages',
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

        // "Invoice 2 · Page 1/3" for the page being previewed.
        var pill = '${selected + 1} / ${images.length}';
        if (c.oneInvoice.value) {
          pill = 'Page ${selected + 1} / ${images.length}';
        } else if (images.length > 1 && selected < images.length) {
          final groups = c.scanner.buildGroups(images.toList());
          for (var b = 0; b < groups.length; b++) {
            final g = groups[b];
            if (g.contains(selected)) {
              pill =
                  g.length > 1
                      ? 'Invoice ${b + 1} · Page ${g.indexOf(selected) + 1}/${g.length}'
                      : 'Invoice ${b + 1}';
              break;
            }
          }
        }

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
                    pill,
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

  // ---------------------------------------------------------------------
  // Bills: one card per bill, its pages in order
  // ---------------------------------------------------------------------

  Widget _bills(ScannerScreenController c) {
    return Obx(() {
      final files = c.images.toList();
      if (files.isEmpty) return const SizedBox.shrink();

      final sel = c.selectedImage.value;
      final busy = c.isProcessing.value;

      if (c.oneInvoice.value) {
        return Padding(
          padding: EdgeInsets.only(top: Sizes.h(14)),
          child: _singleInvoiceCard(c, files.length, sel, busy),
        );
      }

      // Reads pageGroup, so this rebuilds whenever pages are merged / split.
      final groups = c.scanner.buildGroups(files);

      return Padding(
        padding: EdgeInsets.only(top: Sizes.h(14)),
        child: Column(
          children: [
            for (var b = 0; b < groups.length; b++)
              _billCard(c, groups, b, sel, busy),
          ],
        ),
      );
    });
  }

  Widget _singleInvoiceCard(
    ScannerScreenController c,
    int count,
    int sel,
    bool busy,
  ) {
    // final full = count >= ScannerScreenController.maxPages;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Sizes.w(12)),
      decoration: _box().copyWith(
        border: Border.all(color: _primary.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(Sizes.w(6)),
                decoration: const BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.layers,
                  color: Colors.white,
                  size: Sizes.w(14),
                ),
              ),
              SizedBox(width: Sizes.w(8)),
              Expanded(
                child: Text(
                  'Your invoice',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: Sizes.sp(13.5),
                    color: _textDark,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Sizes.w(8),
                  vertical: Sizes.h(2),
                ),
                decoration: BoxDecoration(
                  color: _cardIconBg,
                  borderRadius: BorderRadius.circular(Sizes.w(20)),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: _primary,
                    fontSize: Sizes.sp(10.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Sizes.h(10)),
          SizedBox(
            height: Sizes.h(78),
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: !busy,
              itemCount: c.images.length,
              onReorder: busy ? (_, _) {} : c.reorder,
              proxyDecorator:
                  (child, _, _) => Material(
                    color: Colors.transparent,
                    elevation: 6,
                    borderRadius: BorderRadius.circular(Sizes.w(10)),
                    child: child,
                  ),
              itemBuilder: (_, i) {
                final path = c.images[i].path;
                return KeyedSubtree(
                  key: ValueKey(path),
                  child: _pageTile(c, i, i + 1, i == sel, busy),
                );
              },
            ),
          ),
          if (count > 1) ...[
            SizedBox(height: Sizes.h(8)),
            Row(
              children: [
                Icon(Icons.swap_horiz, size: Sizes.w(14), color: _textMuted),
                SizedBox(width: Sizes.w(6)),
                Text(
                  'Hold and drag a page to change the order',
                  style: TextStyle(color: _textMuted, fontSize: Sizes.sp(11)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeSelector(ScannerScreenController c) {
    return Obx(() {
      final one = c.oneInvoice.value;
      final busy = c.isProcessing.value;

      Widget tile(bool value, IconData icon, String title, String sub) {
        final selected = one == value;
        return Expanded(
          child: GestureDetector(
            onTap: busy ? null : () => c.requestMode(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                horizontal: Sizes.w(10),
                vertical: Sizes.h(10),
              ),
              decoration: BoxDecoration(
                color: selected ? _primary : Colors.transparent,
                borderRadius: BorderRadius.circular(Sizes.w(12)),
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    size: Sizes.w(22),
                    color: selected ? Colors.white : _primary,
                  ),
                  SizedBox(height: Sizes.h(4)),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: Sizes.sp(12.5),
                      color: selected ? Colors.white : _textDark,
                    ),
                  ),
                  SizedBox(height: Sizes.h(2)),
                  Text(
                    sub,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: Sizes.sp(10.5),
                      color: selected ? Colors.white70 : _textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Container(
        padding: EdgeInsets.all(Sizes.w(6)),
        decoration: _box(),
        child: Column(
          children: [
            Row(
              children: [
                tile(
                  false,
                  Icons.receipt_long_outlined,
                  'Invoice Upload',
                  'Upload multiple invoices together',
                ),
                SizedBox(width: Sizes.w(6)),
                tile(
                  true,
                  Icons.layers_outlined,
                  'Multi-Page Invoice',
                  'Upload one invoice multiple pages',
                ),
              ],
            ),
            // Padding(
            //   padding: EdgeInsets.fromLTRB(
            //     Sizes.w(8),
            //     Sizes.h(8),
            //     Sizes.w(8),
            //     Sizes.h(4),
            //   ),
            //   child: Row(
            //     children: [
            //       Icon(
            //         Icons.info_outline,
            //         size: Sizes.w(14),
            //         color: _textMuted,
            //       ),
            //       SizedBox(width: Sizes.w(6)),
            //       // Expanded(
            //       //   child: Text(
            //       //     one
            //       //         ? 'All images upload as ONE invoice.'
            //       //         : 'Each photo uploads as its own invoice. A PDF is always one invoice.',
            //       //     style: TextStyle(
            //       //       fontSize: Sizes.sp(11),
            //       //       color: _textMuted,
            //       //       height: 1.3,
            //       //     ),
            //       //   ),
            //       // ),
            //     ],
            //   ),
            // ),
          ],
        ),
      );
    });
  }

  Widget _billCard(
    ScannerScreenController c,
    List<List<int>> groups,
    int b,
    int sel,
    bool busy,
  ) {
    final g = groups[b];
    final hasSelected = g.contains(sel);
    final posInBill = g.indexOf(sel); // -1 when the selected page is elsewhere

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: Sizes.h(10)),
      padding: EdgeInsets.all(Sizes.w(12)),
      decoration: _box().copyWith(
        border: Border.all(
          color:
              hasSelected
                  ? _primary.withValues(alpha: 0.35)
                  : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: Sizes.w(24),
                height: Sizes.w(24),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${b + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Sizes.sp(11.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: Sizes.w(8)),
              Text(
                'Invoice ${b + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: Sizes.sp(13.5),
                  color: _textDark,
                ),
              ),
              SizedBox(width: Sizes.w(8)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Sizes.w(8),
                  vertical: Sizes.h(2),
                ),
                decoration: BoxDecoration(
                  color: _cardIconBg,
                  borderRadius: BorderRadius.circular(Sizes.w(20)),
                ),
                child: Text(
                  g.length == 1 ? '1 page' : '${g.length} pages',
                  style: TextStyle(
                    color: _primary,
                    fontSize: Sizes.sp(10.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Sizes.h(10)),
          SizedBox(
            height: Sizes.h(78),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: g.length,
              itemBuilder:
                  (_, p) => _pageTile(c, g[p], p + 1, g[p] == sel, busy),
            ),
          ),
          // Contextual action for the selected page of this bill.
          if (hasSelected && !busy && !c.oneInvoice.value) ...[
            // if (posInBill == 0 && b > 0)
            //   _billAction(
            //     Icons.call_merge,
            //     'Merge into Invoice $b',
            //     () => c.scanner.mergeBillWithPrevious(sel),
            //   ),
            if (posInBill > 0)
              _billAction(
                Icons.call_split,
                'Start a new invoice from page ${posInBill + 1}',
                () => c.scanner.splitBefore(sel),
              ),
          ],
        ],
      ),
    );
  }

  Widget _billAction(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.only(top: Sizes.h(8)),
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          backgroundColor: _cardIconBg,
          padding: EdgeInsets.symmetric(
            horizontal: Sizes.w(12),
            vertical: Sizes.h(6),
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sizes.w(10)),
          ),
        ),
        icon: Icon(icon, size: Sizes.w(16)),
        label: Text(
          label,
          style: TextStyle(fontSize: Sizes.sp(12), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _pageTile(
    ScannerScreenController c,
    int index,
    int pageNo,
    bool selected,
    bool busy,
  ) {
    return GestureDetector(
      onTap: () => c.selectedImage.value = index,
      child: Container(
        width: Sizes.w(58),
        margin: EdgeInsets.only(right: Sizes.w(8)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Sizes.w(10)),
          border: Border.all(
            color: selected ? _primary : const Color(0xFFE3E5EE),
            width: selected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Sizes.w(8)),
              child: Image.file(
                c.images[index],
                width: Sizes.w(58),
                height: Sizes.h(78),
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Sizes.w(6),
                  vertical: Sizes.h(1.5),
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(Sizes.w(10)),
                ),
                child: Text(
                  'P$pageNo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Sizes.sp(10),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 2,
              top: 2,
              child: GestureDetector(
                onTap: busy ? null : () => c.remove(index),
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
        final bills = c.scanner.buildGroups(c.images.toList()).length;

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
                : bills == count
                ? 'Upload $bills Invoice${bills == 1 ? '' : 's'}'
                : 'Upload $bills Invoice${bills == 1 ? '' : 's'} ($count pages)',
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
