import 'package:quick_scanner/utils/common_color.dart';
import 'package:quick_scanner/utils/common_size.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../services/models/scan_record.dart';
import '../../../services/scan_history_service.dart';


// Same 375x812 baseline scaling used across the app's other screens.

class ExtractedTextController extends GetxController {
  final String extractedText;
  final String imagePath;
  final int? recordIndex;

  ExtractedTextController({
    required this.extractedText,
    required this.imagePath,
    this.recordIndex,
  });

  late final TextEditingController textController;
  final isSaving = false.obs;
  final dirty = false.obs;
  late final RxInt charCount = extractedText.length.obs;

  bool get isEditingExisting => recordIndex != null;

  @override
  void onInit() {
    super.onInit();
    textController = TextEditingController(text: extractedText);
    textController.addListener(() {
      dirty.value = textController.text != extractedText;
      charCount.value = textController.text.length; // live character count
    });
  }

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }

  void copyText() {
    Clipboard.setData(ClipboardData(text: textController.text));
  }

  void _showSnack(String message, {Color? backgroundColor}) {
    final ctx = Get.context;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sizes.w(10)),
        ),
      ),
    );
  }

  Future<void> saveRecord() async {
    final text = textController.text.trim();

    if (text.isEmpty) {
      _showSnack('Cannot save empty text');
      return;
    }

    isSaving.value = true;

    try {
      if (isEditingExisting) {
        final records = ScanHistoryService.recordsNotifier.value;
        final index = recordIndex!;

        if (index >= 0 && index < records.length) {
          final oldRecord = records[index];
          final updatedRecord = ScanRecord(
            text: text,
            imagePath: oldRecord.imagePath,
            createdAt: oldRecord.createdAt,
          );

          await ScanHistoryService.updateRecord(index, updatedRecord);
        }
      } else {
        await ScanHistoryService.addRecord(
          text: text,
          imageFile: File(imagePath),
        );
      }

      _showSnack(
        isEditingExisting
            ? 'Invoice updated successfully'
            : 'Invoice saved successfully',
      );

      Get.back();
    } catch (e) {
      _showSnack(
        'Failed to save: ${e.toString()}',
        backgroundColor: ColorConstants.redAccent,
      );
    } finally {
      isSaving.value = false;
    }
  }
}

class ExtractedTextScreen extends StatelessWidget {
  final String extractedText;
  final String imagePath;
  final int? recordIndex;

  const ExtractedTextScreen({
    super.key,
    required this.extractedText,
    required this.imagePath,
    this.recordIndex,
  });

  bool get _isEditingExisting => recordIndex != null;

  @override
  Widget build(BuildContext context) {
    final c = Get.put(
      ExtractedTextController(
        extractedText: extractedText,
        imagePath: imagePath,
        recordIndex: recordIndex,
      ),
    );

    return Obx(
      () => AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: ColorConstants.primary,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: ColorConstants.background,
        body: Column(
          children: [
            _header(c),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(Sizes.w(16), Sizes.h(16), Sizes.w(16), 0),
                child: Column(
                  children: [
                    _sourceRow(),
                    SizedBox(height: Sizes.h(14)),
                    _infoBanner(),
                    SizedBox(height: Sizes.h(16)),
                    _textEditor(c),
                    SizedBox(height: Sizes.h(16)),
                    _saveButton(c),
                    SizedBox(height: Sizes.h(16)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------

  Widget _header(ExtractedTextController c) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [ColorConstants.primary, ColorConstants.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: ColorConstants.primaryAlpha20,
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(Sizes.w(12), Sizes.h(8), Sizes.w(16), Sizes.h(18)),
          child: Row(
            children: [
              _circleIconButton(Icons.arrow_back, () => Get.back()),
              SizedBox(width: Sizes.w(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extracted Text',
                      style: TextStyle(
                        fontSize: Sizes.sp(18),
                        fontWeight: FontWeight.w700,
                        color: ColorConstants.white,
                      ),
                    ),
                    SizedBox(height: Sizes.h(2)),
                    Text(
                      _isEditingExisting ? 'Editing saved invoice' : 'New scan',
                      style: TextStyle(
                        fontSize: Sizes.sp(12),
                        color: ColorConstants.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _circleIconButton(Icons.copy_outlined, c.copyText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleIconButton(IconData icon, VoidCallback onTap) {
    final size = Sizes.w(40);

    return Material(
      color: ColorConstants.white.withValues(alpha: 0.15),
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
            border: Border.all(color: ColorConstants.white24, width: 1),
          ),
          child: Icon(icon, size: Sizes.w(19), color: ColorConstants.white),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------

  Widget _sourceRow() {
    final file = File(imagePath);

    return Container(
      padding: EdgeInsets.all(Sizes.w(10)),
      decoration: BoxDecoration(
        color: ColorConstants.white,
        borderRadius: BorderRadius.circular(Sizes.w(14)),
        boxShadow: const [
          BoxShadow(
            color: ColorConstants.shadow05,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Sizes.w(10)),
            child: Image.file(
              file,
              width: Sizes.w(48),
              height: Sizes.w(48),
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) => Container(
                    width: Sizes.w(48),
                    height: Sizes.w(48),
                    color: ColorConstants.primarySoft,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: ColorConstants.primary,
                      size: 20,
                    ),
                  ),
            ),
          ),
          SizedBox(width: Sizes.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Source scan',
                  style: TextStyle(
                    fontSize: Sizes.sp(13),
                    fontWeight: FontWeight.w700,
                    color: ColorConstants.textDark,
                  ),
                ),
                SizedBox(height: Sizes.h(2)),
                Text(
                  'The original image this text was extracted from',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: Sizes.sp(11.5), color: ColorConstants.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Sizes.w(14)),
      decoration: BoxDecoration(
        color: ColorConstants.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Sizes.w(12)),
        border: Border.all(color: ColorConstants.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: ColorConstants.primary, size: Sizes.w(20)),
          SizedBox(width: Sizes.w(10)),
          Expanded(
            child: Text(
              'Text detected successfully. Review and edit it below before saving.',
              style: TextStyle(
                fontSize: Sizes.sp(13),
                color: ColorConstants.grey44,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textEditor(ExtractedTextController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: Sizes.h(280),
          child: TextField(
            controller: c.textController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            style: TextStyle(
              fontSize: Sizes.sp(15),
              height: 1.5,
              color: ColorConstants.grey22,
            ),
            decoration: InputDecoration(
              hintText: 'Extracted text will appear here...',
              hintStyle: const TextStyle(color: ColorConstants.textMuted),
              filled: true,
              fillColor: ColorConstants.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Sizes.w(12)),
                borderSide: const BorderSide(color: ColorConstants.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Sizes.w(12)),
                borderSide: const BorderSide(color: ColorConstants.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Sizes.w(12)),
                borderSide: const BorderSide(color: ColorConstants.primary, width: 1.2),
              ),
              contentPadding: EdgeInsets.all(Sizes.w(16)),
            ),
          ),
        ),
        SizedBox(height: Sizes.h(6)),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
              '${c.charCount.value} characters',
              style: TextStyle(fontSize: Sizes.sp(11), color: ColorConstants.textMuted),
            ),
        ),
      ],
    );
  }

  Widget _saveButton(ExtractedTextController c) {
    return SizedBox(
      width: double.infinity,
      height: Sizes.h(52),
      child: ElevatedButton.icon(
          onPressed: c.isSaving.value ? null : c.saveRecord,
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorConstants.primary,
            disabledBackgroundColor: ColorConstants.primary.withValues(alpha: 0.5),
            foregroundColor: ColorConstants.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Sizes.w(12)),
            ),
          ),
          icon:
              c.isSaving.value
                  ? SizedBox(
                    width: Sizes.w(20),
                    height: Sizes.w(20),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ColorConstants.white,
                    ),
                  )
                  : Icon(
                    _isEditingExisting ? Icons.save_outlined : Icons.check,
                  ),
          label: Text(
            c.isSaving.value
                ? 'Saving...'
                : (_isEditingExisting ? 'Save Changes' : 'Save Invoice'),
            style: TextStyle(fontSize: Sizes.sp(15), fontWeight: FontWeight.w600),
          ),
        ),
    );
  }
}
