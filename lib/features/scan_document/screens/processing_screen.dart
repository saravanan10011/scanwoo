import 'package:quick_scanner/utils/common_color.dart';
import 'package:quick_scanner/utils/common_size.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Same 375x812 baseline scaling used across the app's other screens.

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
      progress.value = 1.0;
      finished.value = true;

      await Future.delayed(const Duration(milliseconds: 600));
      if (isClosed) return;
      Get.back(result: texts);
    } catch (e) {
      if (isClosed) return;
      Get.snackbar(
        'Processing failed',
        'Processing failed: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.back(result: null);
    }
  }

  void animateProgress() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (isClosed || finished.value) return false;

      if (progress.value < 0.9) {
        progress.value += 0.002;
      } else if (progress.value < 0.98) {
        progress.value += 0.001;
      }
      return progress.value < 0.98 && !finished.value;
    });
  }
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

    return Obx(
      () => Scaffold(
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
                  'Extracting text using OCR',
                  style: TextStyle(color: ColorConstants.white70, fontSize: Sizes.sp(14)),
                ),
                SizedBox(height: Sizes.h(40)),
                ClipRRect(
                    borderRadius: BorderRadius.circular(Sizes.w(10)),
                    child: LinearProgressIndicator(
                      value: c.progress.value,
                      minHeight: Sizes.h(8),
                      backgroundColor: ColorConstants.white24,
                      valueColor: const AlwaysStoppedAnimation(ColorConstants.white),
                    ),
                  ),
                SizedBox(height: Sizes.h(18)),
                Text(
                    '${c.percent}%',
                    style: TextStyle(
                      color: ColorConstants.white,
                      fontSize: Sizes.sp(14),
                      fontWeight: FontWeight.w600,
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
}
