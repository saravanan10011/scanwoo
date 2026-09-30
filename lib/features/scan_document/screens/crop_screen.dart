import 'dart:io';

import 'package:flutter/foundation.dart'; // compute
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

const Color _primary = Color(0xFF4038D8);
const Color _primarySoft = Color(0xFFEDECFB);
const Color _background = Color(0xFFF5F7FB);
const Color _textDark = Color(0xFF1C1C28);
const Color _textMuted = Color(0xFF7A7A8C);
const Color _border = Color(0xFFE7E7EE);

/// args: [sourcePath, outPath, angle]
/// Runs in a background isolate so large photos don't freeze the UI.
String _rotateInIsolate(List<String> args) {
  final bytes = File(args[0]).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return args[0];

  final upright = img.bakeOrientation(decoded); // respect EXIF first
  final rotated = img.copyRotate(upright, angle: int.parse(args[2]));

  File(args[1]).writeAsBytesSync(img.encodeJpg(rotated, quality: 92));
  return args[1];
}

class CropAdjustController extends GetxController {
  final File original;
  CropAdjustController(this.original);

  late final Rx<File> currentImage = original.obs;
  final selectedTool = ''.obs;
  final isProcessing = false.obs;

  bool get isEdited => currentImage.value.path != original.path;

  void showMessage(String message) {
    final ctx = Get.context;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _textDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> openCropper() async {
    if (isProcessing.value) return;
    isProcessing.value = true;
    selectedTool.value = 'Crop';
    try {
      final result = await ImageCropper().cropImage(
        sourcePath: currentImage.value.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: _primary,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: _primary,
            backgroundColor: Colors.black,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
            aspectRatioLockEnabled: false,
            rotateButtonsHidden: false,
          ),
        ],
      );

      if (result != null) currentImage.value = File(result.path);
    } catch (_) {
      showMessage('Could not crop image');
    } finally {
      isProcessing.value = false;
      selectedTool.value = '';
    }
  }

  /// 90 = clockwise, 270 = counter-clockwise.
  Future<void> rotateImage({int angle = 90}) async {
    if (isProcessing.value) return;
    isProcessing.value = true;
    selectedTool.value = angle == 90 ? 'Rotate Right' : 'Rotate Left';
    try {
      final dir = await getTemporaryDirectory();
      final outPath =
          '${dir.path}/rot_${DateTime.now().microsecondsSinceEpoch}.jpg';

      final resultPath = await compute(_rotateInIsolate, [
        currentImage.value.path,
        outPath,
        angle.toString(),
      ]);

      currentImage.value = File(resultPath);
    } catch (_) {
      showMessage('Could not rotate image');
    } finally {
      isProcessing.value = false;
      selectedTool.value = '';
    }
  }

  void resetImage() {
    if (isProcessing.value || !isEdited) return;
    currentImage.value = original;
    selectedTool.value = '';
    showMessage('Changes reset');
  }

  void next() => Get.back(result: currentImage.value);
}

class CropAdjustScreen extends StatelessWidget {
  final File image;

  const CropAdjustScreen({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(CropAdjustController(image));

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
            _buildHeader(context),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: _buildPreview(c),
              ),
            ),
            _buildBottomPanel(context, c),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _primary,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Text(
              'Crop & Adjust',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(CropAdjustController c) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1F),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Obx(
          () => Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Image.file(
                  c.currentImage.value,
                  key: ValueKey(c.currentImage.value.path),
                  fit: BoxFit.contain,
                ),
              ),
              if (c.isProcessing.value)
                Container(
                  color: Colors.black38,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context, CropAdjustController c) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tools',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _textMuted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          _buildTools(c),
          const SizedBox(height: 16),
          _buildNextButton(c),
        ],
      ),
    );
  }

  Widget _buildTools(CropAdjustController c) {
    return Container(
      padding: const EdgeInsets.all(6),
      width: double.infinity,
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Obx(
        () => Row(
          children: [
            _buildTool(
              c,
              icon: Icons.rotate_left_rounded,
              title: 'Rotate Left',
              onTap: () => c.rotateImage(angle: 270),
            ),
            _buildTool(
              c,
              icon: Icons.rotate_right_rounded,
              title: 'Rotate Right',
              onTap: () => c.rotateImage(angle: 90),
            ),
            _buildTool(
              c,
              icon: Icons.crop_rounded,
              title: 'Crop',
              onTap: c.openCropper,
            ),
            _buildTool(
              c,
              icon: Icons.restart_alt_rounded,
              title: 'Reset',
              onTap: c.resetImage,
              enabled: c.isEdited,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTool(
    CropAdjustController c, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final bool selected = c.selectedTool.value == title;
    final bool active = enabled && !c.isProcessing.value;
    final Color color =
        !active
            ? _textMuted.withValues(alpha: 0.4)
            : (selected ? _primary : _textMuted);

    return Expanded(
      child: InkWell(
        onTap: active ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton(CropAdjustController c) {
    return Center(
      child: SizedBox(
        width: Get.width * 0.5,
        height: 48,
        child: Obx(
          () => ElevatedButton(
            onPressed: c.isProcessing.value ? null : c.next,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _primary.withValues(alpha: 0.4),
              disabledForegroundColor: Colors.white70,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Next',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
