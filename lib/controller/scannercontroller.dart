import 'package:flutter/material.dart';
import 'package:quick_scanner/repository/scannerrepository.dart';
import '../models/scan_record.dart';

class ScannerController extends ChangeNotifier {
  final ScannerRepository _repository = ScannerRepository();
  bool isLoading = false;
  String? errorMessage;
  ScanRecord? currentRecord;
  Future<void> scanDocument(String imagePath) async {
    isLoading = true;
    errorMessage = null;
    currentRecord = null;
    notifyListeners(); // Tell UI to show loading spinner

    try {
      final record = await _repository.processImage(imagePath);
            await _repository.saveScanRecord(record);
      currentRecord = record;
      
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners(); // Tell UI to stop loading and show data/error
    }
  }
  void clearState() {
    currentRecord = null;
    errorMessage = null;
    isLoading = false;
    notifyListeners();
  }
}