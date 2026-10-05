import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/features/forget_password/data/repositories/forget_password_resp_imp.dart';
import 'package:quick_scanner/features/forget_password/data/repositories/forgot_password_resp.dart';
import 'package:quick_scanner/networks/api_status.dart';
import 'package:quick_scanner/utils/common_dialog.dart';

import '../../../networks/data_service.dart';

class ForgetPasswordViewModel extends GetxController {
  Rx<TextEditingController> emailController = TextEditingController().obs;
  Rx<TextEditingController> passwordController = TextEditingController().obs;
  Rx<TextEditingController> newpasswordController = TextEditingController().obs;
  RxBool isLoading = false.obs;
  final tokenDataService = Get.find<TokenDataServiceImp>();
  final ForgotPasswordResp _forgetPasswordRespImp = ForgetPasswordRespImp();

  final RxBool hidePassword = true.obs;
  final RxBool hideConfirmPassword = true.obs;
  RxString email = ''.obs;
  RxString token = ''.obs;

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments;

    email.value = args?["email"] ?? "";
    token.value = args?["token"] ?? "";

    debugPrint("EMAIL => ${email.value}");
    debugPrint("TOKEN => ${token.value}");
  }

  Future<void> clientForgetPassword() async {
    try {
      isLoading.value = true;
      final body = {"email": emailController.value.text};

      final result = await _forgetPasswordRespImp.forgetPassword(body);
      if (result is SuccessStatus) {
        final data = jsonDecode(result.responseStr);
        final message = data['message'];
        await Get.dialog(
          RegisterResultDialog(
            message: message,
            isSuccess: true,
            buttonName: "Ok",
            // redirectRoute: RouteList.login,
          ),
          barrierDismissible: false,
        );
        // await Get.offAllNamed(RouteList.mainscreen);
      } else if (result is FailureStatus) {
        isLoading.value = false;

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

  Future<void> resentPassword() async {
    try {
      isLoading.value = true;

      final body = {
        "email": email.value,
        "password": passwordController.value.text,
        "password_confirmation": newpasswordController.value.text,
        "token": token.value,
      };

      debugPrint("REQUEST BODY => $body");

      final result = await _forgetPasswordRespImp.resetPassword(body);

      debugPrint("REQUEST RESULT => $result");

      if (result is SuccessStatus) {
        final data = jsonDecode(result.responseStr);

        // Stop loading before showing success alert
        isLoading.value = false;

        await Get.dialog(
          RegisterResultDialog(
            message: data["message"] ?? "Password reset successful",
            isSuccess: true,
            buttonName: "OK",
          ),
          barrierDismissible: false,
        );
      } else if (result is FailureStatus) {
        debugPrint("REQUEST FAILURE => ${result.message}");

        final data = jsonDecode(result.message);

        // Stop loading before showing failure alert
        isLoading.value = false;

        await Get.dialog(
          RegisterResultDialog(
            message: data["message"] ?? "Something went wrong",
            isSuccess: false,
            buttonName: "OK",
          ),
          barrierDismissible: false,
        );
      }
    } catch (e) {
      debugPrint("RESET PASSWORD ERROR => $e");

      // Stop loading if unexpected error occurs
      isLoading.value = false;

      await Get.dialog(
        RegisterResultDialog(
          message: "Something went wrong. Please try again.",
          isSuccess: false,
          buttonName: "OK",
        ),
        barrierDismissible: false,
      );
    }
  }
}
