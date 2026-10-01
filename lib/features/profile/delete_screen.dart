import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/features/profile/data/profile_rep_imp.dart';
import 'package:quick_scanner/features/profile/data/profile_resp.dart';
import 'package:quick_scanner/networks/api_status.dart';
import 'package:quick_scanner/networks/data_service.dart';
import 'package:quick_scanner/utils/common_color.dart';

class DeleteAccountController extends GetxController {
  final tokenDataService = Get.find<TokenDataServiceImp>();
  final ProfileResp _profileRepo = ProfileRepImp();

  final formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final obscure = true.obs;
  final loading = false.obs;
  final error = RxnString();

  Future<void> submit() async {
    if (loading.value) return; // prevent double taps / double submit
    if (!formKey.currentState!.validate()) return;

    FocusManager.instance.primaryFocus?.unfocus();
    loading.value = true;
    error.value = null;

    try {
      final result = await _profileRepo.deleteAccount({
        "password": passwordController.value.text,
      });
      if (isClosed) return;

      if (result is SuccessStatus) {
        loading.value = false;

        // Close the dialog first, then notify and log out.
        Get.back(result: true);
        Get.snackbar(
          '',
          '',
          titleText: const SizedBox.shrink(),
          messageText: const Center(
            child: Text(
              'Your account has been deleted',
              style: TextStyle(fontSize: 12, color: ColorConstants.white),
            ),
          ),
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.only(bottom: 10, left: 60, right: 60),
          duration: const Duration(seconds: 2),
          backgroundColor: ColorConstants.black,
          borderRadius: 10,
        );
        await tokenDataService.logout();
      } else {
        // Wrong password / server error: keep the dialog open and show it.
        error.value = 'Incorrect password  ';
        // 'Please try again.';
      }
    } catch (_) {
      if (!isClosed) {
        error.value = 'Something went wrong. Please try again.';
      }
    } finally {
      if (!isClosed) loading.value = false;
    }
  }

  @override
  void onClose() {
    passwordController.dispose();
    super.onClose();
  }
}

class DeleteAccountPasswordDialog extends StatelessWidget {
  const DeleteAccountPasswordDialog({super.key});

  /// Usage: `final deleted = await DeleteAccountPasswordDialog.show();`
  static Future<bool?> show() => Get.dialog<bool>(
    const DeleteAccountPasswordDialog(),
    barrierDismissible: false,
  );
  static const primary = ColorConstants.primary;

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: color),
  );

  @override
  Widget build(BuildContext context) {
    return GetX<DeleteAccountController>(
      init: DeleteAccountController(),
      builder: (c) {
        final loading = c.loading.value;
        final obscure = c.obscure.value;
        final error = c.error.value;

        return PopScope(
          canPop: !loading,
          child: Dialog(
            backgroundColor: ColorConstants.white,
            surfaceTintColor: ColorConstants.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: c.formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Delete Account',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: ColorConstants.gray900,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Enter your password to delete your account. All saved data will be permanently removed.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: ColorConstants.gray500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: ColorConstants.gray900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: c.passwordController,
                        obscureText: obscure,
                        enabled: !loading,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          if (c.error.value != null) c.error.value = null;
                        },
                        onFieldSubmitted: (_) => c.submit(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: ColorConstants.gray900,
                        ),
                        decoration: InputDecoration(
                          hintText: 'xxxxxxxxxx',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: ColorConstants.gray500,
                          ),
                          errorText: error,
                          errorMaxLines: 3,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          enabledBorder: _border(ColorConstants.grayBorder),
                          focusedBorder: _border(ColorConstants.gray900),
                          errorBorder: _border(ColorConstants.red600),
                          focusedErrorBorder: _border(ColorConstants.red600),
                          disabledBorder: _border(ColorConstants.grayBorder),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: ColorConstants.gray500,
                            ),
                            onPressed: c.obscure.toggle,
                          ),
                        ),
                        validator:
                            (v) =>
                                (v == null || v.isEmpty)
                                    ? 'Please enter your password'
                                    : null,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed:
                                loading ? null : () => Get.back(result: false),
                            style: TextButton.styleFrom(
                              backgroundColor: ColorConstants.grayBackground,
                              foregroundColor: ColorConstants.gray900,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: loading ? null : c.submit,
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: primary,
                              foregroundColor: ColorConstants.white,
                              disabledBackgroundColor: primary.withValues(
                                alpha: 0.6,
                              ),
                              disabledForegroundColor: ColorConstants.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child:
                                loading
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: ColorConstants.white,
                                      ),
                                    )
                                    : const Text(
                                      'Yes',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
