import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../services/models/scan_record.dart';
import '../../../services/scan_history_service.dart';

const _primary = Color(0xFF4038D8);
const _primaryDark = Color(0xFF2C2AC0);
const _background = Color(0xFFF5F7FB);
const _textDark = Color(0xFF1A1B25);
const _textMuted = Color(0xFF8B8D98);
const _border = Color(0xFFE2E2EA);
const _cardIconBg = Color(0xFFEDEDFF);

// Same 375x812 baseline scaling used across the app's other screens.
double _sw(double px) => Get.width * (px / 375);
double _sh(double px) => Get.height * (px / 812);
double _sp(double px) => _sw(px).clamp(px * 0.85, px * 1.25);

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
          borderRadius: BorderRadius.circular(_sw(10)),
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
        backgroundColor: Colors.redAccent,
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
                padding: EdgeInsets.fromLTRB(_sw(16), _sh(16), _sw(16), 0),
                child: Column(
                  children: [
                    _sourceRow(),
                    SizedBox(height: _sh(14)),
                    _infoBanner(),
                    SizedBox(height: _sh(16)),
                    _textEditor(c),
                    SizedBox(height: _sh(16)),
                    _saveButton(c),
                    SizedBox(height: _sh(16)),
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

  Widget _header(ExtractedTextController c) {
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
          child: Row(
            children: [
              _circleIconButton(Icons.arrow_back, () => Get.back()),
              SizedBox(width: _sw(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extracted Text',
                      style: TextStyle(
                        fontSize: _sp(18),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: _sh(2)),
                    Text(
                      _isEditingExisting ? 'Editing saved invoice' : 'New scan',
                      style: TextStyle(
                        fontSize: _sp(12),
                        color: Colors.white70,
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

  Widget _sourceRow() {
    final file = File(imagePath);

    return Container(
      padding: EdgeInsets.all(_sw(10)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_sw(14)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_sw(10)),
            child: Image.file(
              file,
              width: _sw(48),
              height: _sw(48),
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) => Container(
                    width: _sw(48),
                    height: _sw(48),
                    color: _cardIconBg,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: _primary,
                      size: 20,
                    ),
                  ),
            ),
          ),
          SizedBox(width: _sw(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Source scan',
                  style: TextStyle(
                    fontSize: _sp(13),
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                SizedBox(height: _sh(2)),
                Text(
                  'The original image this text was extracted from',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: _sp(11.5), color: _textMuted),
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
      padding: EdgeInsets.all(_sw(14)),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(_sw(12)),
        border: Border.all(color: _primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: _primary, size: _sw(20)),
          SizedBox(width: _sw(10)),
          Expanded(
            child: Text(
              'Text detected successfully. Review and edit it below before saving.',
              style: TextStyle(
                fontSize: _sp(13),
                color: const Color(0xFF444444),
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
          height: _sh(280),
          child: TextField(
            controller: c.textController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            style: TextStyle(
              fontSize: _sp(15),
              height: 1.5,
              color: const Color(0xFF222222),
            ),
            decoration: InputDecoration(
              hintText: 'Extracted text will appear here...',
              hintStyle: const TextStyle(color: _textMuted),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_sw(12)),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_sw(12)),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_sw(12)),
                borderSide: const BorderSide(color: _primary, width: 1.2),
              ),
              contentPadding: EdgeInsets.all(_sw(16)),
            ),
          ),
        ),
        SizedBox(height: _sh(6)),
        Align(
          alignment: Alignment.centerRight,
          child: Obx(
            () => Text(
              '${c.charCount.value} characters',
              style: TextStyle(fontSize: _sp(11), color: _textMuted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _saveButton(ExtractedTextController c) {
    return SizedBox(
      width: double.infinity,
      height: _sh(52),
      child: Obx(
        () => ElevatedButton.icon(
          onPressed: c.isSaving.value ? null : c.saveRecord,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            disabledBackgroundColor: _primary.withValues(alpha: 0.5),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_sw(12)),
            ),
          ),
          icon:
              c.isSaving.value
                  ? SizedBox(
                    width: _sw(20),
                    height: _sw(20),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Icon(
                    _isEditingExisting ? Icons.save_outlined : Icons.check,
                  ),
          label: Text(
            c.isSaving.value
                ? 'Saving...'
                : (_isEditingExisting ? 'Save Changes' : 'Save Invoice'),
            style: TextStyle(fontSize: _sp(15), fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
