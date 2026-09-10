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
      MultiDocumentResultScreenState();
}

class MultiDocumentResultScreenState extends State<MultiDocumentResultScreen> {
  late final List<TextEditingController> controllers;
  int currentIndex = 0;
  bool saving = false;
  static const primary = Color(0xFF4038D8);
  static const background = Color(0xFFF5F7FB);
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
      ClipboardData(text: controllers[currentIndex].text),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied'),
        backgroundColor: primary,
      ),
    );
  }

  Future<void> saveDocuments() async {
    if (saving) return;

    setState(() => saving = true);

    try {
      for (var i = 0; i < widget.images.length; i++) {
        final text = controllers[i].text.trim();

        if (text.isNotEmpty) {
          await ScanHistoryService.addRecord(
            text: text,
            imageFile: widget.images[i],
          );
        }
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const ScanHistoryScreen(),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
@override
Widget build(BuildContext context) {
  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: primary,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${widget.images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
        title: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const Text(
              'Extracted Documents',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Document ${currentIndex + 1} of ${widget.images.length}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            image(),
            const SizedBox(height: 14),
            documents(),
            const SizedBox(height: 14),
            navigation(),
            const SizedBox(height: 14),
            textBox(),
            const SizedBox(height: 12),
            copyButton(),
            const SizedBox(height: 10),
            saveButton(),
          ],
        ),
      ),
    ),
  );
}
  Widget header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3038D8), Color(0xFF5146E5)],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(26),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Extracted Documents',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Document ${currentIndex + 1} of ${widget.images.length}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              '${widget.images.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget image() {
    return Container(
      height: 280,
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: _card(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: const Color(0xFFF1F2F6),
          child: InteractiveViewer(
            child: Image.file(
              widget.images[currentIndex],
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget documents() {
    return Container(
      height: 89,
      padding: const EdgeInsets.all(12),
      decoration: _card(),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final selected = index == currentIndex;

          return GestureDetector(
            onTap: () => setState(() => currentIndex = index),
            child: Container(
              width: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: selected ? primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.file(
                  widget.images[index],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget navigation() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: currentIndex == 0
                ? null
                : () => setState(() => currentIndex--),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Previous'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: currentIndex == widget.images.length - 1
                ? null
                : () => setState(() => currentIndex++),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next'),
          ),
        ),
      ],
    );
  }

  Widget textBox() {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(14),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.text_snippet_outlined,
                color: primary,
              ),
              SizedBox(width: 10),
              Text(
                'Extracted Text',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: controllers[currentIndex],
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: 'Extracted text',
                filled: true,
                fillColor: const Color(0xFFF8F9FC),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget copyButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: copyText,
        icon: const Icon(Icons.copy_outlined),
        label: const Text('Copy Text'),
      ),
    );
  }

  Widget saveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: saving ? null : saveDocuments,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save_outlined),
        label: Text(
          saving ? 'Saving...' : 'Save All Documents',
        ),
      ),
    );
  }

  BoxDecoration _card() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}