import 'dart:async';
import 'package:quick_scanner/utils/common_color.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:quick_scanner/features/history/logic/history_controller.dart';
import 'package:quick_scanner/features/profile/logic/profile_controller.dart';
import 'package:quick_scanner/networks/api_status.dart';
import 'package:quick_scanner/utils/const.dart';

class HistoryRepository {
  final HistoryController _controller = Get.find<HistoryController>();
  final ProfileController _profileController = Get.find<ProfileController>();

  /// Single page (kept so existing callers still work).
  Future<dynamic> uploadInvoiceWithImage({
    required String? token,
    required File imageFile,
    required String extractedData,
    Map<String, dynamic>? fields,
  }) {
    return uploadInvoiceWithImages(
      token: token,
      imageFiles: [imageFile],
      extractedData: extractedData,
      fields: fields,
    );
  }

  /// ONE invoice made of one or more pages (images[] = every page, in order).
  Future<dynamic> uploadInvoiceWithImages({
    required String? token,
    required List<File> imageFiles,
    required String extractedData, // OCR text of all pages joined, in order
    Map<String, dynamic>? fields,
  }) async {
    try {
      final uri = Uri.parse("${APICalls.baseUrl}/invoices");
      final request =
          http.MultipartRequest('POST', uri)
            ..fields['extracted_data'] = extractedData
            ..headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Values extracted on the phone (InvoiceExtractionService).
      if (fields != null) {
        const keys = [
          'supplier',
          'vat_number',
          'invoice_no',
          'branch',
          'date',
          'net',
          'vat',
          'gross',
          'payment',
        ];
        for (final k in keys) {
          final v = fields[k];
          if (v == null || '$v'.trim().isEmpty) continue;
          var value = '$v';
          if (k == 'payment') {
            final p = value.toLowerCase();
            value =
                p.contains('cash')
                    ? 'Cash'
                    : (p.contains('card') ? 'Card' : value);
          }
          request.fields[k] = value;
        }
      }

      for (final file in imageFiles) {
        final stream = http.ByteStream(file.openRead());
        final length = await file.length();
        final fileName = file.path.split(Platform.pathSeparator).last;
        request.files.add(
          http.MultipartFile('images[]', stream, length, filename: fileName),
        );
      }

      // More pages = more bytes to send.
      final timeout = Duration(
        seconds: 30 + 15 * (imageFiles.isEmpty ? 0 : imageFiles.length - 1),
      );
      final streamedResponse = await request.send().timeout(timeout);
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 201) {
        return SuccessStatus(statusCode: 201, responseStr: responseBody);
      } else {
        return FailureStatus(
          statusCode: streamedResponse.statusCode,
          message: 'Upload failed: $responseBody',
        );
      }
    } catch (e) {
      return FailureStatus(
        statusCode: 100,
        message: 'Network error or timeout: ${e.toString()}',
      );
    }
  }

  /// One upload per BILL. [groups] holds the page files of each bill.
  /// A single-page bill is a list with one file (same request as before).
  Future<List<dynamic>> uploadInvoiceGroups({
    required String? token,
    required List<List<File>> groups,
    required List<String> extractedDataList, // one per bill
    List<Map<String, dynamic>>? fieldsList, // one per bill
  }) async {
    assert(groups.length == extractedDataList.length);

    final results = <dynamic>[];
    int success = 0;
    int failed = 0;

    for (int i = 0; i < groups.length; i++) {
      final result = await uploadInvoiceWithImages(
        token: token,
        imageFiles: groups[i],
        extractedData: extractedDataList[i],
        fields:
            (fieldsList != null && i < fieldsList.length)
                ? fieldsList[i]
                : null,
      );
      results.add(result);

      if (result is SuccessStatus) {
        success++;
      } else {
        failed++;
      }
    }

    _showResultSnackBar(success: success, failed: failed);

    if (success > 0) {
      unawaited(_controller.fetchInvoices());
      unawaited(_profileController.fetchdashboard());
    }

    return results;
  }

  /// Uploads many images, then shows ONE message and refreshes ONCE.
  Future<List<dynamic>> uploadInvoicesIndividually({
    required String? token,
    required List<File> images,
    required List<String> extractedDataList, // one per image, same order
    List<Map<String, dynamic>>? fieldsList, // optional, same order
  }) async {
    assert(images.length == extractedDataList.length);

    final results = <dynamic>[];
    int success = 0;
    int failed = 0;

    for (int i = 0; i < images.length; i++) {
      final result = await uploadInvoiceWithImage(
        token: token,
        imageFile: images[i],
        extractedData: extractedDataList[i],
        fields:
            (fieldsList != null && i < fieldsList.length)
                ? fieldsList[i]
                : null,
      );
      results.add(result);

      if (result is SuccessStatus) {
        success++;
      } else {
        failed++;
      }
    }

    _showResultSnackBar(success: success, failed: failed);

    if (success > 0) {
      // Refresh once for the whole batch.
      unawaited(_controller.fetchInvoices());
      unawaited(_profileController.fetchdashboard());
    }

    return results;
  }

  void _showResultSnackBar({required int success, required int failed}) {
    final context = Get.context;
    if (context == null) return;

    final allOk = failed == 0;
    final String message;
    if (allOk) {
      message =
          success == 1
              ? "Invoice uploaded successfully."
              : "$success invoices uploaded successfully.";
    } else if (success == 0) {
      message =
          failed == 1
              ? "Invoice upload failed."
              : "All $failed uploads failed.";
    } else {
      message = "$success uploaded, $failed failed.";
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: allOk ? ColorConstants.green : Colors.red,
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  // Future<dynamic> uploadInvoiceWithImage({
  //   required String? token,
  //   required File imageFile,
  //   required String extractedData,
  // }) async {
  //   try {
  //     final uri = Uri.parse(
  //       "${APICalls.baseUrl}/invoices",
  //     ); // now https, no redirect expected
  //     final request =
  //         http.MultipartRequest('POST', uri)
  //           ..fields['extracted_data'] = extractedData
  //           ..headers['Accept'] = 'application/json';
  //     if (token != null) {
  //       request.headers['Authorization'] = 'Bearer $token';
  //     }

  //     final stream = http.ByteStream(imageFile.openRead());
  //     final length = await imageFile.length();
  //     final fileName = imageFile.path.split(Platform.pathSeparator).last;

  //     request.files.add(
  //       http.MultipartFile('images[]', stream, length, filename: fileName),
  //     );

  //     final streamedResponse = await request.send().timeout(
  //       const Duration(seconds: 30),
  //     );
  //     final responseBody = await streamedResponse.stream.bytesToString();

  //     // Clipboard.setData(ClipboardData(text: responseBody.toString()));

  //     if (streamedResponse.statusCode == 201) {
  //       ScaffoldMessenger.of(Get.context!).showSnackBar(
  //         SnackBar(
  //           backgroundColor: ColorConstants.green,
  //           content: const Text("Invoice Uploading successfully."),
  //           behavior: SnackBarBehavior.floating,
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(10),
  //           ),
  //         ),
  //       );

  //       // Refresh in the background; the upload itself is already done.
  //       unawaited(_controller.fetchInvoices());
  //       unawaited(_profileController.fetchdashboard());
  //       return SuccessStatus(statusCode: 201, responseStr: responseBody);
  //     } else {
  //       return FailureStatus(
  //         statusCode: streamedResponse.statusCode,
  //         message: 'Upload failed: $responseBody',
  //       );
  //     }
  //   } catch (e) {
  //     return FailureStatus(
  //       statusCode: 100,
  //       message: 'Network error or timeout: ${e.toString()}',
  //     );
  //   }
  // }

  // Future<List<dynamic>> uploadInvoicesIndividually({
  //   required String? token,
  //   required List<File> images,
  //   required List<String> extractedDataList, // one per image, same order
  // }) async {
  //   assert(images.length == extractedDataList.length);

  //   final results = <dynamic>[];

  //   for (int i = 0; i < images.length; i++) {
  //     final result = await uploadInvoiceWithImage(
  //       token: token,
  //       imageFile: images[i],
  //       extractedData: extractedDataList[i],
  //     );
  //     results.add(result);
  //   }

  //   return results;
  // }
}
