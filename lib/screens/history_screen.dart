import 'dart:io';
import 'package:flutter/material.dart';
import '../models/scan_record.dart';
import '../services/excel_service.dart';
import '../services/pdf_services.dart';
import '../services/scan_history_service.dart';

class ScanHistoryScreen extends StatelessWidget {
  const ScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
      ),
      body: ValueListenableBuilder<List<ScanRecord>>(
        valueListenable: ScanHistoryService.recordsNotifier,
        builder: (context, records, child) {
          return Column(
            children: [
              // EXPORT ALL BUTTON
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Export All Records'),
                    onPressed: records.isEmpty
                        ? null
                        : () {
                            _showExportOptions(
                              context,
                              records,
                              isSingleRecord: false,
                            );
                          },
                  ),
                ),
              ),

              Expanded(
                child: records.isEmpty
                    ? const Center(
                        child: Text(
                          'No scan history available',
                        ),
                      )
                    : ListView.builder(
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.all(10),

                              // OPEN PREVIEW
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ScanPreviewScreen(
                                      record: record,
                                    ),
                                  ),
                                );
                              },

                              leading: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: File(record.imagePath)
                                          .existsSync()
                                      ? Image.file(
                                          File(record.imagePath),
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(
                                          Icons.description,
                                          size: 35,
                                        ),
                                ),
                              ),

                              title: Text(
                                record.text.isEmpty
                                    ? 'No extracted text'
                                    : record.text.length > 50
                                        ? '${record.text.substring(0, 50)}...'
                                        : record.text,
                                maxLines: 2,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),

                              subtitle: Text(
                                _formatDate(record.createdAt),
                              ),

                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'preview') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ScanPreviewScreen(
                                          record: record,
                                        ),
                                      ),
                                    );
                                  }

                                  if (value == 'export') {
                                    _showExportOptions(
                                      context,
                                      [record],
                                      isSingleRecord: true,
                                    );
                                  }

                                  if (value == 'delete') {
                                    await ScanHistoryService
                                        .deleteRecord(index);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'preview',
                                    child: Row(
                                      children: [
                                        Icon(Icons.visibility),
                                        SizedBox(width: 10),
                                        Text('Preview'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'export',
                                    child: Row(
                                      children: [
                                        Icon(Icons.ios_share),
                                        SizedBox(width: 10),
                                        Text('Export'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete),
                                        SizedBox(width: 10),
                                        Text('Delete'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // EXPORT OPTIONS
  // ============================================================

  void _showExportOptions(
    BuildContext context,
    List<ScanRecord> records, {
    required bool isSingleRecord,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  isSingleRecord
                      ? 'Export This Scan'
                      : 'Export All Scans',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // PDF EXPORT
              ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf,
                  color: Colors.red,
                ),
                title: const Text('Export as PDF'),
                subtitle: Text(
                  isSingleRecord
                      ? 'Export this scanned document'
                      : 'Export all scanned documents',
                ),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);

                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Creating PDF...'),
                      ),
                    );

                    await PdfService.exportAndShareRecords(
                      records,
                    );
                  } catch (e) {
                    debugPrint('PDF ERROR: $e');

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'PDF export failed: $e',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),

              // EXCEL EXPORT
              ListTile(
                leading: const Icon(
                  Icons.table_chart,
                  color: Colors.green,
                ),
                title: const Text('Export as Excel'),
                subtitle: Text(
                  isSingleRecord
                      ? 'Export this scan data'
                      : 'Export all scan data',
                ),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);

                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Creating Excel...'),
                      ),
                    );

                    await ExcelService.exportAndShareRecords(
                      records,
                    );
                  } catch (e) {
                    debugPrint('EXCEL ERROR: $e');

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Excel export failed: $e',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// ============================================================
// SCAN PREVIEW SCREEN
// ============================================================

class ScanPreviewScreen extends StatelessWidget {
  final ScanRecord record;

  const ScanPreviewScreen({
    super.key,
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final imageFile = File(record.imagePath);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Preview'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // SCANNED IMAGE
            if (imageFile.existsSync())
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(12),
                child: Image.file(
                  imageFile,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 200,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: const Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      size: 50,
                    ),
                    SizedBox(height: 10),
                    Text('Image not available'),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // SCAN DATE
            Text(
              'Scanned Date',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),

            const SizedBox(height: 5),

            Text(
              _formatDateTime(record.createdAt),
            ),

            const SizedBox(height: 20),

            // EXTRACTED TEXT
            Text(
              'Extracted Text',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius:
                    BorderRadius.circular(12),
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

            // EXPORT THIS FILE
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.ios_share),
                label: const Text('Export This Scan'),
                onPressed: () {
                  _showSingleExportOptions(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSingleExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (bottomContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf,
                ),
                title: const Text('Export as PDF'),
                onTap: () async {
                  Navigator.pop(bottomContext);

                  await PdfService.exportAndShareRecords(
                    [record],
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.table_chart,
                ),
                title: const Text('Export as Excel'),
                onTap: () async {
                  Navigator.pop(bottomContext);

                  await ExcelService.exportAndShareRecords(
                    [record],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}