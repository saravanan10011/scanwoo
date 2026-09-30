import 'package:quick_scanner/utils/common_color.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/features/profile/data/profile_rep_imp.dart';
import 'package:quick_scanner/features/profile/data/profile_resp.dart';
import 'package:quick_scanner/features/profile/model/dashboard_model.dart';
import 'package:quick_scanner/networks/api_status.dart';
import 'package:quick_scanner/networks/data_service.dart';
import 'package:quick_scanner/utils/common_dialog.dart';

class ProfileController extends GetxController {
  final currentController = TextEditingController();
  final nameController = TextEditingController();
  final newController = TextEditingController();
  final confirmController = TextEditingController();
  final ProfileResp _profilerep = ProfileRepImp();

  final hideCurrent = true.obs;
  final hideNew = true.obs;
  final hideConfirm = true.obs;
  final isLoading = false.obs;

  /// Errors returned by the server, shown under the matching field.
  final currentPasswordError = RxnString();
  final newPasswordError = RxnString();
  final tokenDataService = Get.find<TokenDataServiceImp>();

  final userName = ''.obs;
  final userEmail = ''.obs;

  @override
  void onInit() {
    super.onInit();

    fetchdashboard();
  }

  /// Returns true when the name was updated on the server.
  Future<bool> updateName() async {
    final newName = nameController.text.trim();
    if (newName.isEmpty || newName == userName.value) return false;

    try {
      isLoading.value = true;
      final result = await _profilerep.upadteProfile({"name": newName});

      if (result is SuccessStatus) {
        userName.value = newName;
        tokenDataService.userName =
            newName; // header and details card refresh via Obx
        await fetchdashboard();
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            backgroundColor: ColorConstants.green,

            content: const Text("Profile updated successfully."),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return true;
      } else if (result is FailureStatus) {
        final data = jsonDecode(result.message);
        Get.snackbar('Error', data['message'] ?? 'Could not update name');
      }
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> changePassword() async {
    try {
      isLoading.value = true;

      final body = {
        'current_password': currentController.text,
        'password': newController.text,
        'password_confirmation': confirmController.text,
      };
      debugPrint("REQUEST BODY => $body");

      final result = await _profilerep.changePassword(body);
      debugPrint("REQUEST result => $result");

      if (result is SuccessStatus) {
        // final data = jsonDecode(result.responseStr);

        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            backgroundColor: ColorConstants.green,

            content: const Text("Password updated successfully."),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Get.back();
      } else if (result is FailureStatus) {
        debugPrint("REQUEST result => ${result.message}");

        final data = jsonDecode(result.message);
        final message = data['message'];
        await Get.dialog(
          RegisterResultDialog(
            message: message,
            isSuccess: false,
            buttonName: "Ok",
            // redirectRoute: RouteList.login,
          ),
          barrierDismissible: false,
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  final dashboard = Rxn<Dashboard>();

  Future<void> fetchdashboard() async {
    isLoading.value = true;
    try {
      final result = await _profilerep.dashborad();

      if (result is SuccessStatus) {
        dashboard.value = dashboardFromJson(result.responseStr);
        userName.value = dashboard.value!.data.client.name;
        userEmail.value = dashboard.value!.data.client.email;
      } else if (result is FailureStatus) {
        String message = 'Unable to load dashboard';
        try {
          message = jsonDecode(result.message)['message'] ?? message;
        } catch (_) {}
        Get.snackbar('Error', message);
      }
    } catch (e, s) {
      debugPrint('Dashboard parse error: $e\n$s');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> upadteprofile() async {
    try {
      isLoading.value = true;

      final body = {"name": nameController.value.text};
      debugPrint("REQUEST BODY => $body");

      final result = await _profilerep.upadteProfile(body);
      debugPrint("REQUEST result => $result");
      if (result is SuccessStatus) {
        Get.back();
      } else if (result is FailureStatus) {
        debugPrint("REQUEST result => ${result.message}");

        final data = jsonDecode(result.message);
        final message = data['message'];
        await Get.dialog(
          RegisterResultDialog(
            message: message,
            isSuccess: false,
            buttonName: "Ok",
            // redirectRoute: RouteList.login,
          ),
          barrierDismissible: false,
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    currentController.dispose();
    nameController.dispose(); // add this
    newController.dispose();
    confirmController.dispose();
    super.onClose();
  }
}
