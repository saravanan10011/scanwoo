import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExtractedTextScreen extends StatefulWidget {
  final String extractedText;

  const ExtractedTextScreen({
    super.key,
    required this.extractedText,
  });

  @override
  State<ExtractedTextScreen> createState() =>
      ExtractedTextScreenState();
}

class ExtractedTextScreenState extends State<ExtractedTextScreen> {
  late final TextEditingController textController;

  @override
  void initState() {
    super.initState();

    textController = TextEditingController(
      text: widget.extractedText,
    );
  }

  void copyText() {
    Clipboard.setData(
      ClipboardData(
        text: textController.text,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied successfully'),
      ),
    );
  }

  void saveText() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Record ready to save'),
      ),
    );
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extracted Text'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: copyText,
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy Text',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Text detected successfully. You can edit it below.',
                    ),
                  ),
                ],
              ),
            ), 

            const SizedBox(height: 16),
 
            Expanded(
              child: TextField(
                controller: textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Extracted text will appear here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: saveText,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Record'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}