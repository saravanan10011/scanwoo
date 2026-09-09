import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/scan_history_service.dart';
import 'history_screen.dart';

class MultiDocumentResultScreen extends StatefulWidget {
  final List<File> images;
  final List<String> extractedTexts;

  const MultiDocumentResultScreen({
    super.key,
    required this.images,
    required this.extractedTexts,
  });

  @override
  State<MultiDocumentResultScreen> createState() =>
      _MultiDocumentResultScreenState();
}

class _MultiDocumentResultScreenState
    extends State<MultiDocumentResultScreen> {
  late List<TextEditingController> controllers;

  int currentIndex = 0;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    controllers = widget.extractedTexts
        .map((text) => TextEditingController(text: text))
        .toList();
  }

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> copyText() async {
    await Clipboard.setData(
      ClipboardData(
        text: controllers[currentIndex].text,
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied'),
      ),
    );
  }

  Future<void> saveDocuments() async {
    if (isSaving) return;

    setState(() {
      isSaving = true;
    });

    try {
      for (int i = 0; i < widget.images.length; i++) {
        final text = controllers[i].text.trim();

        if (text.isEmpty) continue;

        await ScanHistoryService.addRecord(
          text: text,
          imageFile: widget.images[i],
        );
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const ScanHistoryScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.images[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Document ${currentIndex + 1}',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(
                      child: Image.file(
                        image,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: currentIndex == 0
                          ? null
                          : () {
                              setState(() {
                                currentIndex--;
                              });
                            },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          currentIndex == widget.images.length - 1
                              ? null
                              : () {
                                  setState(() {
                                    currentIndex++;
                                  });
                                },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Expanded(
                flex: 4,
                child: TextField(
                  controller: controllers[currentIndex],
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: 'Extracted text',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: copyText,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy Text'),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : saveDocuments,
                  icon: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    isSaving ? 'Saving...' : 'Save Documents',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}