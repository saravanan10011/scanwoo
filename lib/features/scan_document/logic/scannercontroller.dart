import 'dart:io';

import 'package:get/get.dart';

import 'package:quick_scanner/networks/data_service.dart';

import 'package:quick_scanner/features/scan_document/repositiores/scannerrepository.dart';
import 'package:quick_scanner/services/ocr_service.dart';
import '../../../services/models/scan_record.dart';

class ScannerController extends GetxController {
  final ScannerRepository _repository = ScannerRepository();
  bool isLoading = false;
  String? errorMessage;
  ScanRecord? currentRecord;
  final OcrService ocrService = OcrService();
  final tokenDataService = Get.find<TokenDataServiceImp>();
  final RxList<File> images = <File>[].obs;
  int selectedImage = 0;
  bool isProcessing = false;
  bool isUploading = false;

  final List<ScanRecord> scanRecords = [];

  /// image path -> bill id. Images with the same id are pages of ONE bill.
  /// A path that is not in the map is a single-page bill.
  final RxMap<String, String> pageGroup = <String, String>{}.obs;

  String newGroupId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// "Same bill as previous page" on image [index].
  void linkWithPrevious(int index) {
    if (index <= 0 || index >= images.length) return;
    final prev = images[index - 1].path;
    final id = pageGroup[prev] ?? newGroupId();
    pageGroup[prev] = id;
    pageGroup[images[index].path] = id;
  }

  void unlink(int index) {
    if (index < 0 || index >= images.length) return;
    pageGroup.remove(images[index].path);
  }

  bool isLinkedWithPrevious(int index) {
    if (index <= 0 || index >= images.length) return false;
    final a = pageGroup[images[index - 1].path];
    return a != null && a == pageGroup[images[index].path];
  }

  /// Splits [files] into bills, keeping scan order. Only NEIGHBOURS with the
  /// same id are merged; every other image is its own single-page bill.
  /// Returns lists of indexes into [files].
  List<List<int>> buildGroups(List<File> files) {
    final groups = <List<int>>[];
    String? lastId;
    for (var i = 0; i < files.length; i++) {
      final id = pageGroup[files[i].path];
      if (id != null && id == lastId && groups.isNotEmpty) {
        groups.last.add(i);
      } else {
        groups.add([i]);
      }
      lastId = id;
    }
    return groups;
  }

  /// Group ids that came from ONE PDF file (a file is always one invoice).
  final Set<String> fileGroups = <String>{};

  void resetGroups() {
    pageGroup.clear();
    fileGroups.clear();
  }

  /// "Single invoice" mode: every image is a page of the same invoice.
  void groupAllAsOne() {
    if (images.isEmpty) return;
    final id = newGroupId();
    for (final f in images) {
      pageGroup[f.path] = id;
    }
    fileGroups.clear();
  }

  /// "Multiple invoices" mode: every image is its own invoice.
  /// Pages of one PDF stay together (a PDF is one invoice).
  void separateAll() {
    for (final f in images) {
      final id = pageGroup[f.path];
      if (id != null && !fileGroups.contains(id)) pageGroup.remove(f.path);
    }
  }

  /// Merge the WHOLE bill that starts at [index] into the bill before it.
  void mergeBillWithPrevious(int index) {
    if (index <= 0 || index >= images.length) return;

    final groups = buildGroups(images.toList());
    final prev = images[index - 1].path;
    final id = pageGroup[prev] ?? newGroupId();
    pageGroup[prev] = id;

    for (final g in groups) {
      if (!g.contains(index)) continue;
      for (final i in g) {
        pageGroup[images[i].path] = id;
      }
    }
  }

  /// Start a new bill at page [index]; the pages after it come along.
  void splitBefore(int index) {
    if (!isLinkedWithPrevious(index)) return;

    final groups = buildGroups(images.toList());
    final newId = newGroupId();

    for (final g in groups) {
      if (!g.contains(index)) continue;
      for (final i in g) {
        if (i >= index) pageGroup[images[i].path] = newId;
      }
    }
  }

  Future<void> scanDocument(String imagePath) async {
    isLoading = true;
    errorMessage = null;
    currentRecord = null;
    update();

    try {
      final record = await _repository.processImage(imagePath);
      await _repository.saveScanRecord(record);
      currentRecord = record;

      // track this image + its record together for later batch upload
      images.add(File(imagePath));
      scanRecords.add(record);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      update();
    }
  }

  void clearState() {
    currentRecord = null;
    errorMessage = null;
    isLoading = false;
    update();
  }
}
