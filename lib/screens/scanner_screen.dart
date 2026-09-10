import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quick_scanner/screens/crop_screen.dart';
import 'package:quick_scanner/screens/processing%20screen.dart';
import '../services/ocr_service.dart';
import 'multi_doc_screen.dart';
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => ScannerScreenState();
}
class ScannerScreenState extends State<ScannerScreen> {
  final picker = ImagePicker();
  final ocrService = OcrService();
  final List<File> images = [];
  int selectedImage = 0;

  Future<void> camera() async {
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;

    final croppedImage = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => CropAdjustScreen(image: File(image.path)),
      ),
    );
    if (croppedImage == null || !mounted) return;

    setState(() {
      images.add(croppedImage);
      selectedImage = images.length - 1;
    });
  }

  Future<void> gallery() async {
    final files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty || !mounted) return;

    for (final file in files) {
      if (!mounted) return;

      final croppedImage = await Navigator.push<File>(
        context,
        MaterialPageRoute(
          builder: (_) => CropAdjustScreen(image: File(file.path)),
        ),
      );

      if (croppedImage != null && mounted) {
        setState(() {
          images.add(croppedImage);
          selectedImage = images.length - 1;
        });
      }
    }
  }

  Future<void> process() async {
    if (images.isEmpty) return;

    final texts = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(
          imagePaths: images.map((f) => f.path).toList(),
          onProcess: (paths) async {
            final results = <String>[];
            for (final path in paths) {
              results.add(await ocrService.extractText(File(path)));
            }
            return results;
          },
        ),
      ),
    );

    if (texts == null || !mounted) return;

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MultiDocumentResultScreen(
          images: List.from(images),
          extractedTexts: texts,
        ),
      ),
    );

    if (mounted) {
      setState(() {
        images.clear();
        selectedImage = 0;
      });
    }
  }

  void remove(int index) {
    setState(() {
      images.removeAt(index);

      if (images.isEmpty) {
        selectedImage = 0;
      } else if (selectedImage >= images.length) {
        selectedImage = images.length - 1;
      }
    });
  }

  @override
  void dispose() {
    ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF4038D8),
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          backgroundColor: const Color(0xFF4038D8),
          foregroundColor: Colors.white,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scan Documents', style: TextStyle(fontSize: 18)),
              Text(
                'Capture or select invoices',
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            if (images.isNotEmpty)
              IconButton(
                onPressed: () {
                  setState(() {
                    images.clear();
                    selectedImage = 0;
                  });
                },
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              preview(),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 20),
                thumbnails(),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  action(
                    Icons.camera_alt_outlined,
                    'Camera',
                    'Take photo',
                    camera,
                  ),
                  const SizedBox(width: 12),
                  action(
                    Icons.photo_library_outlined,
                    'Gallery',
                    'Select multiple',
                    gallery,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: images.isEmpty ? null : process,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text(
                    'Process ${images.length} Document${images.length == 1 ? '' : 's'}',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4038D8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget preview() {
    return Container(
      height: 470,
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: box(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: images.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.document_scanner_outlined,
                      size: 60,
                      color: Color(0xFF4038D8),
                    ),
                    SizedBox(height: 25),
                    Text(
                      'No document selected',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Use camera or gallery below',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              )
            : Image.file(images[selectedImage], fit: BoxFit.contain),
      ),
    );
  }

  Widget thumbnails() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: box(),
      child: SizedBox(
        height: 65,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          itemBuilder: (_, index) {
            return GestureDetector(
              onTap: () => setState(() => selectedImage = index),
              child: Container(
                width: 60,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: index == selectedImage
                        ? const Color(0xFF4038D8)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        images[index],
                        width: 60,
                        height: 65,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 1,
                      top: 1,
                      child: GestureDetector(
                        onTap: () => remove(index),
                        child: const CircleAvatar(
                          radius: 9,
                          backgroundColor: Colors.red,
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget action(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 95,
          padding: const EdgeInsets.all(14),
          decoration: box(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF4038D8)),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x10000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    );
  }
}