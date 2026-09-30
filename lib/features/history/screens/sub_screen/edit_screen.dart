import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/features/history/model/history_model.dart';

const primary = Color(0xFF4038D8);
const background = Color(0xFFF5F7FB);

class EditRawTextController extends GetxController {
  final String initialText;
  final Future<void> Function(String text) onSave;

  EditRawTextController({required this.initialText, required this.onSave});

  late final TextEditingController textCtrl = TextEditingController(
    text: initialText,
  );
  final saving = false.obs;

  Future<void> save() async {
    saving.value = true;
    try {
      await onSave(textCtrl.text);
      Get.back();
    } catch (e) {
      saving.value = false;
      Get.snackbar('Error', 'Could not save changes');
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
        title: const Text('Edit Raw Data'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: c.textCtrl,
            expands: true,
            minLines: null,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Raw text',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primary, width: 1.6),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
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
                    height: 50,
                    child: OutlinedButton(
                      onPressed: c.saving.value ? null : Get.back,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade800,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Save
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: c.saving.value ? null : c.save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: primary.withValues(alpha: 0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child:
                            c.saving.value
                                ? const SizedBox(
                                  key: ValueKey('loading'),
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Row(
                                  key: ValueKey('save'),
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_rounded, size: 19),
                                    SizedBox(width: 7),
                                    Text(
                                      'Save',
                                      style: TextStyle(
                                        fontSize: 14,
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
