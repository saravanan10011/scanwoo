import 'package:flutter/material.dart';
import '../widgets/customtextfield.dart';

class EditRecordScreen extends StatefulWidget {
  final String extractedText;

  const EditRecordScreen({
    super.key,
    required this.extractedText,
  });

  @override
  State<EditRecordScreen> createState() => EditRecordScreenState();
}

class EditRecordScreenState extends State<EditRecordScreen> {
  late final TextEditingController textController;

  @override
  void initState() {
    super.initState();
    textController = TextEditingController(text: widget.extractedText);
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  void saveText() {
    final text = textController.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text cannot be empty')),
      );
      return;
    }

    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Text'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.text_snippet_outlined,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Review and edit extracted text',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: CustomTextField(
                controller: textController,
                hintText: 'Extracted text will appear here...',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: saveText,
                icon: const Icon(Icons.check),
                label: const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}