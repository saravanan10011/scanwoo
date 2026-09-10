import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
class CropAdjustScreen extends StatefulWidget {
  final File image;

  const CropAdjustScreen({
    super.key,
    required this.image,
  });
  @override
  State<CropAdjustScreen> createState() => _CropAdjustScreenState();
}
class _CropAdjustScreenState extends State<CropAdjustScreen> {
  static const Color primary = Color(0xFF4038D8);
  static const Color background = Color(0xFFF5F7FB);
  late File currentImage;
  String selectedTool = 'Crop';
  @override
  void initState() {
    super.initState();
    currentImage = widget.image;
  }

  Future<void> openCropper() async {
    final result = await ImageCropper().cropImage(
      sourcePath: currentImage.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '',
          toolbarColor: primary,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: primary,
          backgroundColor: Colors.black,
          // ignore: deprecated_member_use
          statusBarColor: primary,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: '',
          doneButtonTitle: 'Done',
          cancelButtonTitle: 'Cancel',
        ),
      ],
    );

    if (result != null && mounted) {
      setState(() {
        currentImage = File(result.path);
      });
    }
  }

  Future<void> rotateImage() async {
    await openCropper();
  }

  void enhanceImage() {
    setState(() {
      selectedTool = 'Enhance';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image enhancement will be applied during processing'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> selectTool(String tool) async {
    setState(() {
      selectedTool = tool;
    });

    if (tool == 'Crop') {
      await openCropper();
    } else if (tool == 'Rotate') {
      await rotateImage();
    } else if (tool == 'Enhance') {
      enhanceImage();
    }
  }

  void next() {
    Navigator.pop(context, currentImage);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Column(
            children: [
              buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
                  child: Column(
                    children: [
                      buildPreview(),
                      const SizedBox(height: 16),
                      buildTools(),
                      const SizedBox(height: 14),
                      buildNextButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildHeader() {
    return Container(
      height: 54,
      width: double.infinity,
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Color(0xFF444444),
            ),
          ),
          const Text(
            'Crop & Adjust',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF222222),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPreview() {
    return Container(
      height: 390,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF292929),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              currentImage,
              fit: BoxFit.contain,
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: CropFramePainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTools() {
    return Container(
      height: 82,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE7E7EE),
        ),
      ),
      child: Row(
        children: [
          buildTool(
            icon: Icons.crop,
            title: 'Crop',
            value: 'Crop',
          ),
          buildTool(
            icon: Icons.rotate_90_degrees_ccw,
            title: 'Rotate',
            value: 'Rotate',
          ),
          buildTool(
            icon: Icons.auto_fix_high,
            title: 'Enhance',
            value: 'Enhance',
          ),
        ],
      ),
    );
  }

  Widget buildTool({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final bool selected = selectedTool == value;

    return Expanded(
      child: InkWell(
        onTap: () => selectTool(value),
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 23,
              color: selected
                  ? primary
                  : const Color(0xFF666666),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? primary
                    : const Color(0xFF666666),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNextButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: next,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        child: const Text(
          'Next',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class CropFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final framePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final left = size.width * 0.08;
    final right = size.width * 0.92;
    final top = size.height * 0.07;
    final bottom = size.height * 0.93;

    canvas.drawRect(
      Rect.fromLTRB(left, top, right, bottom),
      framePaint,
    );

    const double length = 13;

    canvas.drawLine(
      Offset(left, top + length),
      Offset(left, top),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(left, top),
      Offset(left + length, top),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(right - length, top),
      Offset(right, top),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(right, top),
      Offset(right, top + length),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(left, bottom - length),
      Offset(left, bottom),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + length, bottom),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(right - length, bottom),
      Offset(right, bottom),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - length),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}