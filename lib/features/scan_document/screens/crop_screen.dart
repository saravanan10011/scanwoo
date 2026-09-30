import 'package:quick_scanner/utils/common_color.dart';
import 'package:quick_scanner/utils/common_size.dart';
import 'dart:io';

import 'package:flutter/foundation.dart'; // compute
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';


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
          backgroundColor: ColorConstants.textDark3,
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
            toolbarColor: ColorConstants.primary,
            toolbarWidgetColor: ColorConstants.white,
            activeControlsWidgetColor: ColorConstants.primary,
            backgroundColor: ColorConstants.black,
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
        ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      width: double.infinity,
      decoration: const BoxDecoration(
        color: ColorConstants.primary,
        boxShadow: [
          BoxShadow(
            color: ColorConstants.shadow08,
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
                color: ColorConstants.white,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _circleIconButton(Icons.arrow_back_ios_new, () {
                Get.back();
              }),
              // IconButton(
              //   onPressed: () => Get.back(),
              //   icon: const Icon(
              //     Icons.arrow_back_ios_new,
              //     size: 18,
              //     color: ColorConstants.white,
              //   ),
              // ),
            ),
          ],
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

  Widget _buildPreview(CropAdjustController c) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ColorConstants.textDark4,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: ColorConstants.shadow08,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
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
                  color: ColorConstants.black38,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: ColorConstants.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
            ],
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
        color: ColorConstants.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: ColorConstants.shadow06,
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
              color: ColorConstants.textMuted3,
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
        color: ColorConstants.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorConstants.border3),
      ),
      child: Row(
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
            ? ColorConstants.textMuted3.withValues(alpha: 0.4)
            : (selected ? ColorConstants.primary : ColorConstants.textMuted3);

    return Expanded(
      child: InkWell(
        onTap: active ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? ColorConstants.primaryPale : ColorConstants.transparent,
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
        width: Sizes.wp(0.5),
        height: 48,
        child: ElevatedButton(
            onPressed: c.isProcessing.value ? null : c.next,
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorConstants.primary,
              foregroundColor: ColorConstants.white,
              disabledBackgroundColor: ColorConstants.primary.withValues(alpha: 0.4),
              disabledForegroundColor: ColorConstants.white70,
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
    );
  }
}
