import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Same 375x812 baseline scaling used across the app's other screens.
double _sw(double px) => Get.width * (px / 375);
double _sh(double px) => Get.height * (px / 812);
double _sp(double px) => _sw(px).clamp(px * 0.85, px * 1.25);

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

    return Scaffold(
      backgroundColor: const Color(0xFF4038D8),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: _sw(30)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.document_scanner_outlined,
                  size: _sw(90),
                  color: Colors.white,
                ),
                SizedBox(height: _sh(40)),
                Text(
                  'Processing Image...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _sp(22),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: _sh(12)),
                Text(
                  'Extracting text using OCR',
                  style: TextStyle(color: Colors.white70, fontSize: _sp(14)),
                ),
                SizedBox(height: _sh(40)),
                Obx(
                  () => ClipRRect(
                    borderRadius: BorderRadius.circular(_sw(10)),
                    child: LinearProgressIndicator(
                      value: c.progress.value,
                      minHeight: _sh(8),
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ),
                SizedBox(height: _sh(18)),
                Obx(
                  () => Text(
                    '${c.percent}%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _sp(14),
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
