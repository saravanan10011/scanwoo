import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

/// Lets the user pick PDF files and turns every page into a JPG image, so a
/// PDF goes through exactly the same OCR + upload flow as a photo.
class PdfImportService {
  /// Max pages rendered from a single PDF (protects memory / upload size).
  static const int maxPagesPerPdf = 20;

  /// Page width in pixels. ~2000px keeps small invoice text readable for OCR.
  static const double _renderWidth = 2000;

  /// Opens the system file picker (PDF only). Returns the chosen file paths.
  static Future<List<String>> pickPdfPaths() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
    );
    if (result == null) return const [];
    return result.paths.whereType<String>().toList();
  }

  static Future<List<String>> pickImageOrPdfPaths() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      allowMultiple: true,
    );
    if (result == null) return const [];
    return result.paths.whereType<String>().toList();
  }

  /// True when [path] points to a PDF file.
  static bool isPdf(String path) => path.toLowerCase().endsWith('.pdf');

  /// Renders every page of [pdfPath] to a JPG file and returns those files.
  /// Throws [PdfImportException] if the PDF cannot be opened / is empty.
  static Future<List<File>> renderPages(String pdfPath) async {
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(pdfPath);
      final pageCount =
          doc.pagesCount > maxPagesPerPdf ? maxPagesPerPdf : doc.pagesCount;
      if (pageCount == 0) throw const PdfImportException('PDF has no pages.');

      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final files = <File>[];

      for (var i = 1; i <= pageCount; i++) {
        final page = await doc.getPage(i);
        try {
          final scale = _renderWidth / page.width;
          final image = await page.render(
            width: page.width * scale,
            height: page.height * scale,
            format: PdfPageImageFormat.jpeg,
            quality: 90,
            backgroundColor: '#FFFFFF', // PDFs are transparent by default
          );
          if (image == null) continue;

          final file = File('${dir.path}/pdf_${stamp}_p$i.jpg');
          await file.writeAsBytes(image.bytes, flush: true);
          files.add(file);
        } finally {
          await page.close();
        }
      }

      if (files.isEmpty) {
        throw const PdfImportException('Could not read this PDF.');
      }
      return files;
    } on PdfImportException {
      rethrow;
    } catch (e) {
      debugPrint('PDF render failed: $e');
      throw const PdfImportException(
        'Could not open this PDF. It may be damaged or password protected.',
      );
    } finally {
      await doc?.close();
    }
  }
}

class PdfImportException implements Exception {
  final String message;
  const PdfImportException(this.message);

  @override
  String toString() => message;
}
