import '../models/scan_record.dart';
class ScannerRepository {
  Future<ScanRecord> processImage(String imagePath) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      final String extractedText = "This is the simulated extracted text from the document.";
      return ScanRecord(
        text: extractedText,
        imagePath: imagePath,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to extract text: $e');
    }
  }
  Future<void> saveScanRecord(ScanRecord record) async {
    try {
      print('Repository: Record saved successfully for image ${record.imagePath}');
    } catch (e) {
      throw Exception('Failed to save record: $e');
    }
  }
}