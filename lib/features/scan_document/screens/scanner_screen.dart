import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quick_scanner/features/scan_document/logic/scannercontroller.dart';
import 'package:quick_scanner/features/scan_document/screens/crop_screen.dart';
import 'package:quick_scanner/features/scan_document/screens/processing_screen.dart';
import 'package:quick_scanner/services/invoice_exterst.dart';
import '../../../services/ocr_service.dart';
import 'multi_doc_screen.dart';

const _primary = Color(0xFF4038D8);
const _primaryDark = Color(0xFF2C2AC0);
const _background = Color(0xFFF5F7FB);
const _textDark = Color(0xFF1A1B25);
const _textMuted = Color(0xFF8B8D98);
const _cardIconBg = Color(0xFFEDEDFF);
const _disabled = Color(0xFFB8B6E8);

double _sw(double px) => Get.width * (px / 375);
double _sh(double px) => Get.height * (px / 812);
double _sp(double px) => _sw(px).clamp(px * 0.85, px * 1.25);

class ScannerScreenController extends GetxController {
  final ImagePicker picker = ImagePicker();
  final OcrService ocrService = OcrService();
  final ScannerController scanner = Get.put(ScannerController());

  final selectedImage = 0.obs;
  final isProcessing = false.obs;

  RxList<File> get images => scanner.images;
  void _selectLast() => selectedImage.value = images.length - 1;

  Future<void> camera() async {
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (image == null || isClosed) return;

    final croppedImage = await Get.to<File>(
      () => CropAdjustScreen(image: File(image.path)),
    );

    if (croppedImage == null || isClosed) return;

    images.add(croppedImage);
    _selectLast();
  }

  Future<void> gallery() async {
    final files = await picker.pickMultiImage(imageQuality: 85);

    if (files.isEmpty || isClosed) return;

    for (final file in files) {
      if (isClosed) return;

      final croppedImage = await Get.to<File>(
        () => CropAdjustScreen(image: File(file.path)),
      );

      if (croppedImage == null || isClosed) continue;

      images.add(croppedImage);
      _selectLast();
    }
  }

  Future<void> process() async {
    if (images.isEmpty || isProcessing.value) return;

    isProcessing.value = true;

    try {
      final extractedDataList = <Map<String, dynamic>>[];

      final texts = await Get.to<List<String>>(
        () => ProcessingScreen(
          imagePaths: images.map((file) => file.path).toList(),
          onProcess: (paths) async {
            final results = <String>[];

            for (final path in paths) {
              final text = await ocrService.extractText(File(path));
              final data = InvoiceExtractionService.extract(text);

              results.add(text);
              extractedDataList.add(data);
            }

            return results;
          },
        ),
      );

      if (isClosed) return;

      isProcessing.value = false;

      if (texts == null) return;

      final imagesCopy = List<File>.from(images);
      final textsCopy = List<String>.from(texts);
      final dataCopy = List<Map<String, dynamic>>.from(extractedDataList);

      Get.to(
        () => MultiDocumentResultScreen(
          images: imagesCopy,
          extractedTexts: textsCopy,
          extractedDataList: dataCopy,
        ),
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
        margin: EdgeInsets.all(_sw(10)),
        borderRadius: _sw(10),
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
    final c = Get.put(ScannerScreenController());

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
                padding: EdgeInsets.fromLTRB(_sw(16), _sh(18), _sw(16), 0),
                child: Column(
                  children: [
                    _preview(c),
                    Obx(
                      () =>
                          c.images.isEmpty
                              ? const SizedBox.shrink()
                              : Padding(
                                padding: EdgeInsets.only(top: _sh(14)),
                                child: _thumbnails(c),
                              ),
                    ),
                    SizedBox(height: _sh(18)),
                    Obx(
                      () => Row(
                        children: [
                          _actionCard(
                            Icons.camera_alt_outlined,
                            'Camera',
                            'Take photo',
                            c.isProcessing.value ? null : c.camera,
                          ),
                          SizedBox(width: _sw(12)),
                          _actionCard(
                            Icons.photo_library_outlined,
                            'Gallery',
                            'Select multiple',
                            c.isProcessing.value ? null : c.gallery,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: _sh(18)),
                    _processButton(c),
                    SizedBox(height: _sh(18)),
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
          padding: EdgeInsets.fromLTRB(_sw(12), _sh(8), _sw(16), _sh(18)),
          child: Obx(() {
            final count = c.images.length;

            return Row(
              children: [
                _circleIconButton(Icons.arrow_back, () => Get.back()),
                SizedBox(width: _sw(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan Documents',
                        style: TextStyle(
                          fontSize: _sp(18),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: _sh(2)),
                      Text(
                        count == 0
                            ? 'Capture or select invoices'
                            : '$count document${count == 1 ? '' : 's'} ready',
                        style: TextStyle(
                          fontSize: _sp(12),
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
    final size = _sw(40);

    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      shape: const CircleBorder(),
      child: InkWell(
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
          child: Icon(icon, size: _sw(19), color: Colors.white),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------

  Widget _preview(ScannerScreenController c) {
    return Container(
      height: _sh(300),
      width: double.infinity,
      padding: EdgeInsets.all(_sw(8)),
      decoration: _box(),
      child: Obx(() {
        final images = c.images;
        final selected = c.selectedImage.value;

        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(_sw(14)),
              child: SizedBox.expand(
                child:
                    images.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.all(_sw(16)),
                                decoration: const BoxDecoration(
                                  color: _cardIconBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.document_scanner_outlined,
                                  size: _sw(40),
                                  color: _primary,
                                ),
                              ),
                              SizedBox(height: _sh(20)),
                              Text(
                                'No document selected',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: _sp(14),
                                  color: _textDark,
                                ),
                              ),
                              SizedBox(height: _sh(6)),
                              Text(
                                'Use camera or gallery below',
                                style: TextStyle(
                                  color: _textMuted,
                                  fontSize: _sp(12),
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
                top: _sh(10),
                right: _sw(10),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: _sw(10),
                    vertical: _sh(5),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(_sw(20)),
                  ),
                  child: Text(
                    '${selected + 1} / ${images.length}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _sp(11.5),
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
      padding: EdgeInsets.all(_sw(12)),
      decoration: _box(),
      child: SizedBox(
        height: _sh(65),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: c.images.length,
          itemBuilder: (context, index) {
            return Obx(() {
              final selected = index == c.selectedImage.value;

              return GestureDetector(
                onTap: () => c.selectedImage.value = index,
                child: Container(
                  width: _sw(60),
                  margin: EdgeInsets.only(right: _sw(8)),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_sw(8)),
                    border: Border.all(
                      color: selected ? _primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(_sw(6)),
                        child: Image.file(
                          c.images[index],
                          width: _sw(60),
                          height: _sh(65),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 1,
                        top: 1,
                        child: GestureDetector(
                          onTap: () => c.remove(index),
                          child: CircleAvatar(
                            radius: _sw(9),
                            backgroundColor: Colors.redAccent,
                            child: Icon(
                              Icons.close,
                              size: _sw(12),
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
        borderRadius: BorderRadius.circular(_sw(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_sw(16)),
          child: Opacity(
            opacity: onTap == null ? 0.5 : 1,
            child: Container(
              height: _sh(100),
              padding: EdgeInsets.all(_sw(14)),
              decoration: _box(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(_sw(8)),
                    decoration: BoxDecoration(
                      color: _cardIconBg,
                      borderRadius: BorderRadius.circular(_sw(10)),
                    ),
                    child: Icon(icon, color: _primary, size: _sw(20)),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: _sp(13),
                      color: _textDark,
                    ),
                  ),
                  SizedBox(height: _sh(2)),
                  Text(
                    subtitle,
                    style: TextStyle(color: _textMuted, fontSize: _sp(10.5)),
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
      height: _sh(52),
      child: Obx(() {
        final count = c.images.length;
        final processing = c.isProcessing.value;

        return ElevatedButton.icon(
          onPressed: count == 0 || processing ? null : c.process,
          icon:
              processing
                  ? SizedBox(
                    width: _sw(20),
                    height: _sw(20),
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
            style: TextStyle(fontSize: _sp(15), fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _disabled,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_sw(14)),
            ),
          ),
        );
      }),
    );
  }

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_sw(16)),
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
