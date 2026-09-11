import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quick_scanner/screens/edit_screen.dart';
import 'package:quick_scanner/screens/exportscreen.dart';
import 'package:quick_scanner/screens/history_screen.dart';
import 'package:quick_scanner/screens/home_screen.dart';
import 'package:quick_scanner/screens/profile.dart';
import 'package:quick_scanner/widgets/bottomnav.dart';
import 'package:quick_scanner/widgets/exportsheet.dart';
import '../models/scan_record.dart';
import '../services/scan_history_service.dart';

const primary = Color(0xFF4038D8);
const background = Color(0xFFF5F7FB);

class ScanPreviewScreen extends StatefulWidget {
  final ScanRecord record;

  const ScanPreviewScreen({
    super.key,
    required this.record,
  });

  @override
  State<ScanPreviewScreen> createState() => ScanPreviewScreenState();
}

class ScanPreviewScreenState extends State<ScanPreviewScreen> {
  late ScanRecord record;

  @override
  void initState() {
    super.initState();
    record = widget.record;
  }

  Future<void> openEdit() async {
    final updatedText = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EditRecordScreen(
          extractedText: record.text,
        ),
      ),
    );

    if (!mounted || updatedText == null || updatedText == record.text) {
      return;
    }

    final records = ScanHistoryService.recordsNotifier.value;
    final index = records.indexOf(widget.record);

    if (index == -1) return;

    final updatedRecord = ScanRecord(
      text: updatedText,
      imagePath: record.imagePath,
      createdAt: record.createdAt,
    );

    await ScanHistoryService.updateRecord(
      index,
      updatedRecord,
    );

    if (!mounted) return;

    setState(() {
      record = updatedRecord;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Record updated'),
      ),
    );
  }

  void navigateToTab(int index) {
    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ScanHistoryScreen(),
        ),
      );
      return;
    }

    if (index == 0) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
        (route) => false,
      );
      return;
    }

    if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ExportScreen(),
        ),
      );
      return;
    }

    if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageFile = File(record.imagePath);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Scan Preview',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: background,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: openEdit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageFile.existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  imageFile,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              )
            else
              _missingImage(),
            const SizedBox(height: 20),
            Text(
              'Scanned Date',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(_formatDateTime(record.createdAt)),
            const SizedBox(height: 20),
            Text(
              'Extracted Text',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE7E7EE),
                ),
              ),
              child: SelectableText(
                record.text.isEmpty
                    ? 'No text extracted from this scan.'
                    : record.text,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: const BorderSide(
                        color: primary,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                    onPressed: openEdit,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                    ),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Export'),
                    onPressed: () {
                      showExportSheet(
                        context,
                        [record],
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: CommonBottomNav(
        selectedIndex: 1,
        onItemSelected: navigateToTab,
      ),
    );
  }

  Widget _missingImage() {
    return Container(
      height: 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 50,
          ),
          SizedBox(height: 10),
          Text('Image not available'),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');

    return '$d/$m/${date.year} $h:$min';
  }
}