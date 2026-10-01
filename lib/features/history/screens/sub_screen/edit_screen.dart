import 'package:quick_scanner/utils/common_color.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/features/history/model/history_model.dart';

const primary = ColorConstants.primary;
const background = ColorConstants.background;

// Remove these if you already have shared _sw/_sh/_sp helpers.
double _sw(double v) => v * Get.width / 375;
double _sh(double v) => v * Get.height / 812;
double _sp(double v) => v * Get.width / 375;

class EditRawTextController extends GetxController {
  final String initialText;
  final Future<void> Function(String text) onSave;

  EditRawTextController({required this.initialText, required this.onSave});

  late final TextEditingController textCtrl = TextEditingController(
    text: initialText,
  );
  final saving = false.obs;
  final errorText = RxnString();

  @override
  void onInit() {
    super.onInit();
    textCtrl.addListener(() {
      if (errorText.value != null && textCtrl.text.trim().isNotEmpty) {
        errorText.value = null;
      }
    });
  }

  bool _validate() {
    if (textCtrl.text.trim().isEmpty) {
      errorText.value = 'Raw text cannot be empty';
      return false;
    }
    errorText.value = null;
    return true;
  }

  Future<void> save() async {
    if (saving.value) return;
    if (!_validate()) return;

    final text = textCtrl.text.trim();

    // Nothing changed -> no update needed
    if (text == initialText.trim()) {
      Get.back();
      return;
    }

    saving.value = true;
    try {
      await onSave(text);
      Get.back();
    } catch (e) {
      saving.value = false;
      final msg = e.toString().replaceFirst('Exception: ', '');
      Get.snackbar(
        'Error',
        msg,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
    }
  }

  @override
  void onClose() {
    textCtrl.dispose();
    super.onClose();
  }
}

class EditRawTextScreen extends StatelessWidget {
  final InvoiceData invoice;
  final String initialText;
  final Future<void> Function(String text) onSave;

  const EditRawTextScreen({
    super.key,
    required this.invoice,
    required this.initialText,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final c = Get.put(
      EditRawTextController(initialText: initialText, onSave: onSave),
    );

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        leading: InkWell(
          // customBorder: const CircleBorder(),
          onTap: () {
            Get.back();
          },
          child: SizedBox(
            // width: _sw(40),
            // height: _sw(40),
            child: Icon(
              Icons.arrow_back_ios,
              size: _sp(17),
              color: ColorConstants.white,
            ),
          ),
        ),

        title: Text('Edit Raw Data', style: TextStyle(fontSize: _sp(18))),
        backgroundColor: primary,
        foregroundColor: ColorConstants.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(_sw(16)),
          child: Obx(
            () => TextField(
              controller: c.textCtrl,
              expands: true,
              minLines: null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              style: TextStyle(fontSize: _sp(14)),
              decoration: InputDecoration(
                filled: true,
                fillColor: ColorConstants.white,
                hintText: 'Raw text',
                errorText: c.errorText.value,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_sw(12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_sw(12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_sw(12)),
                  borderSide: const BorderSide(color: primary, width: 1.6),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_sw(12)),
                  borderSide: BorderSide(color: Colors.red.shade600),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_sw(12)),
                  borderSide: BorderSide(
                    color: Colors.red.shade600,
                    width: 1.6,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(_sw(16), _sh(12), _sw(16), _sh(16)),
          decoration: BoxDecoration(
            color: ColorConstants.white,
            boxShadow: [
              BoxShadow(
                color: ColorConstants.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Obx(
            () => Row(
              children: [
                // Cancel
                Expanded(
                  child: SizedBox(
                    height: _sh(50),
                    child: OutlinedButton(
                      onPressed: c.saving.value ? null : Get.back,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColorConstants.grey800,
                        backgroundColor: ColorConstants.white,
                        side: BorderSide(
                          color: ColorConstants.grey300,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_sw(14)),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: _sp(14),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(width: _sw(12)),

                // Save
                Expanded(
                  child: SizedBox(
                    height: _sh(50),
                    child: ElevatedButton(
                      onPressed: c.saving.value ? null : c.save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: ColorConstants.white,
                        disabledBackgroundColor: primary.withValues(alpha: 0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_sw(14)),
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child:
                            c.saving.value
                                ? SizedBox(
                                  key: const ValueKey('loading'),
                                  width: _sw(20),
                                  height: _sw(20),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: ColorConstants.white,
                                  ),
                                )
                                : Row(
                                  key: const ValueKey('save'),
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_rounded, size: _sp(19)),
                                    SizedBox(width: _sw(7)),
                                    Text(
                                      'Save',
                                      style: TextStyle(
                                        fontSize: _sp(14),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
