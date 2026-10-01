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
  Future<dynamic> uploadInvoiceWithImage({
    required String? token,
    required File imageFile,
    required String extractedData,
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

      final stream = http.ByteStream(imageFile.openRead());
      final length = await imageFile.length();
      final fileName = imageFile.path.split(Platform.pathSeparator).last;

      request.files.add(
        http.MultipartFile('images[]', stream, length, filename: fileName),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
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

  /// Uploads many images, then shows ONE message and refreshes ONCE.
  Future<List<dynamic>> uploadInvoicesIndividually({
    required String? token,
    required List<File> images,
    required List<String> extractedDataList, // one per image, same order
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
