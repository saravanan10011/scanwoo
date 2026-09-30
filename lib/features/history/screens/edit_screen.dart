import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/utils/common_color.dart';

// Responsive helpers (375x812 baseline)
double _sw(double v) => Get.width / 375 * v;
double _sh(double v) => Get.height / 812 * v;
double _sp(double v) => (Get.width / 375).clamp(0.85, 1.25) * v;

class EditRecordController extends GetxController {
  EditRecordController(this.initialText);

  final String initialText;
  late final TextEditingController textController;
  final FocusNode focusNode = FocusNode();

  final RxInt charCount = 0.obs;
  final RxInt lineCount = 0.obs;
  final RxBool hasChanges = false.obs;
  final RxBool isFocused = false.obs;
  final RxnString errorText = RxnString();

  @override
  void onInit() {
    super.onInit();
    textController = TextEditingController(text: initialText);
    _refresh();
    textController.addListener(_refresh);
    focusNode.addListener(() => isFocused.value = focusNode.hasFocus);
  }

  void _refresh() {
    final text = textController.text;
    charCount.value = text.length;
    lineCount.value = text.isEmpty ? 0 : text.split('\n').length;
    hasChanges.value = text != initialText;
    if (errorText.value != null && text.trim().isNotEmpty) {
      errorText.value = null;
    }
  }

  void reset() {
    textController.text = initialText;
    errorText.value = null;
  }

  void clear() {
    textController.clear();
    focusNode.requestFocus();
  }

  Future<void> copy() async {
    await Clipboard.setData(ClipboardData(text: textController.text));
    Get.snackbar(
      'Copied',
      'Text copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
      margin: EdgeInsets.all(_sw(16)),
      duration: const Duration(seconds: 1),
    );
  }

  void save() {
    final text = textController.text.trim();
    if (text.isEmpty) {
      errorText.value = 'Text cannot be empty';
      focusNode.requestFocus();
      return;
    }
    Get.back(result: text);
  }

  Future<void> confirmDiscard() async {
    final discard = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_sw(16)),
        ),
        title: const Text('Discard changes?'),
        content: const Text('Your edits will be lost if you leave now.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text(
              'Discard',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (discard == true) Get.back();
  }

  @override
  void onClose() {
    textController.dispose();
    focusNode.dispose();
    super.onClose();
  }
}

class EditRecordScreen extends StatelessWidget {
  final String extractedText;

  const EditRecordScreen({super.key, required this.extractedText});

  static const primary = ColorConstants.primary;
  static const background = ColorConstants.background;

  @override
  Widget build(BuildContext context) {
    final c = Get.put(EditRecordController(extractedText));

    return Obx(
      () => PopScope(
        canPop: !c.hasChanges.value,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) c.confirmDiscard();
        },
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: background,
            appBar: _buildAppBar(c),
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(_sw(16), _sh(16), _sw(16), 0),
                child: Column(
                  children: [
                    _buildInfoBanner(),
                    SizedBox(height: _sh(14)),
                    Expanded(child: _buildEditor(c)),
                    SizedBox(height: _sh(14)),
                    _buildBottomBar(c),
                    SizedBox(height: _sh(12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(EditRecordController c) {
    return AppBar(
      backgroundColor: primary,
      foregroundColor: ColorConstants.white,
      elevation: 0,
      centerTitle: false,
      title: Text(
        'Edit Invoice',
        style: TextStyle(fontSize: _sp(18), fontWeight: FontWeight.w700),
      ),
      actions: [
        IconButton(
          tooltip: 'Copy text',
          onPressed: c.copy,
          icon: Icon(Icons.copy_rounded, size: _sp(20)),
        ),
        SizedBox(width: _sw(4)),
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_sw(12)),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(_sw(14)),
        border: Border.all(color: primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(_sw(8)),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.edit_note_rounded, color: primary, size: _sp(20)),
          ),
          SizedBox(width: _sw(12)),
          Expanded(
            child: Text(
              'Review and correct the text extracted from your invoice.',
              style: TextStyle(
                fontSize: _sp(13),
                height: 1.35,
                color: ColorConstants.grey44,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(EditRecordController c) {
    return Obx(() {
      final focused = c.isFocused.value;
      final error = c.errorText.value;
      final borderColor =
          error != null
              ? Colors.redAccent
              : focused
              ? primary
              : ColorConstants.border;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: ColorConstants.white,
          borderRadius: BorderRadius.circular(_sw(16)),
          border: Border.all(color: borderColor, width: focused ? 1.4 : 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(_sw(14), _sh(10), _sw(6), _sh(6)),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: _sp(16),
                    color: ColorConstants.grey44,
                  ),
                  SizedBox(width: _sw(6)),
                  Text(
                    'Extracted text',
                    style: TextStyle(
                      fontSize: _sp(12.5),
                      fontWeight: FontWeight.w600,
                      color: ColorConstants.grey44,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: c.charCount.value == 0 ? null : c.clear,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.redAccent,
                    ),
                    icon: Icon(Icons.backspace_outlined, size: _sp(15)),
                    label: Text('Clear', style: TextStyle(fontSize: _sp(12.5))),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: ColorConstants.border),
            // Text field
            Expanded(
              child: TextField(
                controller: c.textController,
                focusNode: c.focusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                  fontSize: _sp(15),
                  height: 1.5,
                  color: ColorConstants.grey22,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter invoice text...',
                  hintStyle: TextStyle(fontSize: _sp(15)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(_sw(14)),
                ),
              ),
            ),
            Divider(height: 1, color: ColorConstants.border),
            // Footer
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _sw(14),
                vertical: _sh(8),
              ),
              child: Row(
                children: [
                  if (error != null) ...[
                    Icon(
                      Icons.error_outline,
                      size: _sp(15),
                      color: Colors.redAccent,
                    ),
                    SizedBox(width: _sw(4)),
                    Expanded(
                      child: Text(
                        error,
                        style: TextStyle(
                          fontSize: _sp(12),
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Text(
                    '${c.lineCount.value} lines • ${c.charCount.value} chars',
                    style: TextStyle(
                      fontSize: _sp(11.5),
                      color: ColorConstants.grey44,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildBottomBar(EditRecordController c) {
    return Obx(() {
      final changed = c.hasChanges.value;
      return Row(
        children: [
          if (changed) ...[
            SizedBox(
              height: _sh(52),
              child: OutlinedButton.icon(
                onPressed: c.reset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary.withValues(alpha: 0.5)),
                  padding: EdgeInsets.symmetric(horizontal: _sw(16)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_sw(14)),
                  ),
                ),
                icon: Icon(Icons.restart_alt_rounded, size: _sp(18)),
                label: Text(
                  'Reset',
                  style: TextStyle(
                    fontSize: _sp(14),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(width: _sw(12)),
          ],
          Expanded(
            child: SizedBox(
              height: _sh(52),
              child: ElevatedButton.icon(
                onPressed: changed ? c.save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: ColorConstants.white,
                  disabledBackgroundColor: primary.withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.white70,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_sw(14)),
                  ),
                ),
                icon: Icon(Icons.check_rounded, size: _sp(20)),
                label: Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: _sp(15),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
