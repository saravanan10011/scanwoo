import 'package:quick_scanner/utils/common_color.dart';
import 'package:quick_scanner/utils/common_size.dart';
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

      await Future.delayed(const Duration(milliseconds: 80));
      if (isClosed) return;
      Get.back(result: texts);
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
      await Future.delayed(const Duration(milliseconds: 100));
      if (isClosed || finished.value) return false;

      progress.value += (0.95 - progress.value) * 0.1;
      return true;
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
                  'Extracting text using OCR',
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
