import 'package:quick_scanner/utils/common_color.dart';
import 'package:quick_scanner/utils/common_size.dart';
import 'package:quick_scanner/services/ocr_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ProcessingController extends GetxController {
  final List<String> imagePaths;
  final Future<List<String>> Function(List<String> paths) onProcess;

  ProcessingController({required this.imagePaths, required this.onProcess});

  final progress = 0.0.obs;
  final finished = false.obs;

  int get percent => (progress.value * 100).clamp(0, 100).toInt();

  @override
  void onInit() {
    super.onInit();
    runOcr();
  }

  Future<void> runOcr() async {
    animateProgress();
    try {
      final texts = await onProcess(imagePaths);

      if (isClosed) return;
      finished.value = true;
      progress.value = 1.0;

      Get.back(result: texts);
    } on NoTextFoundException catch (e) {
      if (isClosed) return;
      finished.value = true;
      Get.back(result: null);
      // Show the alert on the screen we return to.
      await Future.delayed(const Duration(milliseconds: 200));
      _showNoTextAlert(title: 'No text found', message: e.message);
    } catch (e) {
      if (isClosed) return;
      finished.value = true;
      Get.snackbar(
        'Processing failed',
        'Processing failed: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.back(result: null);
    }
  }

  // Ease-out: moves quickly at first, then slows down, never passes 95%
  // until the OCR actually finishes.
  void animateProgress() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 60));
      if (isClosed || finished.value) return false;

      progress.value += (0.95 - progress.value) * 0.06;
      return true;
    });
  }
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

class ProcessingScreen extends StatelessWidget {
  final List<String> imagePaths;
  final Future<List<String>> Function(List<String> paths) onProcess;

  const ProcessingScreen({
    super.key,
    required this.imagePaths,
    required this.onProcess,
  });

  @override
  Widget build(BuildContext context) {
    final c = Get.put(
      ProcessingController(imagePaths: imagePaths, onProcess: onProcess),
    );

    return Scaffold(
      backgroundColor: ColorConstants.primary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Sizes.w(30)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.document_scanner_outlined,
                  size: Sizes.w(90),
                  color: ColorConstants.white,
                ),
                SizedBox(height: Sizes.h(40)),
                Text(
                  'Processing Image...',
                  style: TextStyle(
                    color: ColorConstants.white,
                    fontSize: Sizes.sp(22),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: Sizes.h(12)),
                Text(
                  'Reading text and uploading',
                  style: TextStyle(
                    color: ColorConstants.white70,
                    fontSize: Sizes.sp(14),
                  ),
                ),
                SizedBox(height: Sizes.h(40)),
                Obx(
                  () => ClipRRect(
                    borderRadius: BorderRadius.circular(Sizes.w(10)),
                    child: LinearProgressIndicator(
                      value: c.progress.value,
                      minHeight: Sizes.h(8),
                      backgroundColor: ColorConstants.white24,
                      valueColor: const AlwaysStoppedAnimation(
                        ColorConstants.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: Sizes.h(18)),
                Obx(
                  () => Text(
                    '${c.percent}%',
                    style: TextStyle(
                      color: ColorConstants.white,
                      fontSize: Sizes.sp(14),
                      fontWeight: FontWeight.w600,
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
