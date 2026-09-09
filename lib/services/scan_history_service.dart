import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan_record.dart';

class ScanHistoryService {
  static const String _storageKey = 'scan_history';

  static final ValueNotifier<List<ScanRecord>> recordsNotifier =
      ValueNotifier([]);

  static Future<void> initialize() async {
    await loadRecords();
  }

  // SAVE IMAGE PERMANENTLY
  static Future<String> saveImagePermanently(
    File originalImage,
  ) async {
    final directory =
        await getApplicationDocumentsDirectory();

    final imagesDirectory = Directory(
      '${directory.path}/scanned_images',
    );

    if (!await imagesDirectory.exists()) {
      await imagesDirectory.create(
        recursive: true,
      );
    }

    final fileName =
        'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final newPath =
        '${imagesDirectory.path}/$fileName';

    final savedImage =
        await originalImage.copy(newPath);

    return savedImage.path;
  }

  static Future<void> addRecord({
    required String text,
    required File imageFile,
  }) async {
    final savedImagePath =
        await saveImagePermanently(imageFile);

    final updatedRecords =
        List<ScanRecord>.from(recordsNotifier.value);

    updatedRecords.insert(
      0,
      ScanRecord(
        text: text,
        imagePath: savedImagePath,
        createdAt: DateTime.now(),
      ),
    );

    recordsNotifier.value = updatedRecords;

    await _saveRecords();
  }

  static Future<void> deleteRecord(
    int index,
  ) async {
    final updatedRecords =
        List<ScanRecord>.from(recordsNotifier.value);

    if (index < 0 || index >= updatedRecords.length) {
      return;
    }

    final record = updatedRecords[index];

    // Delete saved image
    try {
      final imageFile = File(record.imagePath);

      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    } catch (_) {}

    updatedRecords.removeAt(index);

    recordsNotifier.value = updatedRecords;

    await _saveRecords();
  }

  static Future<void> clearHistory() async {
    for (final record in recordsNotifier.value) {
      try {
        final imageFile = File(record.imagePath);

        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      } catch (_) {}
    }

    recordsNotifier.value = [];

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(_storageKey);
  }

  static Future<void> loadRecords() async {
    final prefs =
        await SharedPreferences.getInstance();

    final String? data =
        prefs.getString(_storageKey);

    if (data == null || data.isEmpty) {
      recordsNotifier.value = [];
      return;
    }

    try {
      final List<dynamic> jsonList =
          jsonDecode(data);

      recordsNotifier.value =
          jsonList
              .map(
                (item) => ScanRecord.fromJson(item),
              )
              .toList();
    } catch (_) {
      recordsNotifier.value = [];
    }
  }

  static Future<void> _saveRecords() async {
    final prefs =
        await SharedPreferences.getInstance();

    final data =
        recordsNotifier.value
            .map(
              (record) => record.toJson(),
            )
            .toList();

    await prefs.setString(
      _storageKey,
      jsonEncode(data),
    );
  }
}