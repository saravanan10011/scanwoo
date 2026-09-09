import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/image_service.dart';
import '../services/ocr_service.dart';
import 'multi_doc_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => ScannerScreenState();
}

class ScannerScreenState extends State<ScannerScreen> {
  final ImagePicker picker = ImagePicker();
  final ImageService imageService = ImageService();
  final OcrService ocrService = OcrService();

  final List<File> images = [];

  bool loading = false;

  Future<void> openCamera() async {
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (image == null || !mounted) return;

    final cropped = await imageService.cropImage(image);

    if (cropped == null || !mounted) return;

    setState(() {
      images.add(File(cropped.path));
    });

    extractText();
  }

  Future<void> openGallery() async {
    final selected = await picker.pickMultiImage(
      imageQuality: 85,
    );

    if (selected.isEmpty || !mounted) return;

    setState(() {
      images.addAll(
        selected.map((image) => File(image.path)),
      );
    });
  }

  Future<void> extractText() async {
    if (images.isEmpty) return;

    setState(() {
      loading = true;
    });

    try {
      final texts = <String>[];

      for (final image in images) {
        texts.add(
          await ocrService.extractText(image),
        );
      }

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiDocumentResultScreen(
            images: List<File>.from(images),
            extractedTexts: texts,
          ),
        ),
      );

      if (mounted) {
        setState(() {
          images.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OCR failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Invoice Capture'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              height: 500,
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white54,
                  width: 1,
                ),
              ),
              child: images.isEmpty
                  ? const Center(
                      child: Icon(
                        Icons.document_scanner_outlined,
                        color: Colors.white54,
                        size: 80,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        images.last,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
            ),
          ),
          Positioned(
            bottom: 25,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: openGallery,
                  icon: const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                GestureDetector(
                  onTap: loading ? null : openCamera,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blue,
                        width: 5,
                      ),
                    ),
                    child: loading
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.black,
                          ),
                  ),
                ),
                IconButton(
                  onPressed: images.isEmpty || loading
                      ? null
                      : extractText,
                  icon: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}