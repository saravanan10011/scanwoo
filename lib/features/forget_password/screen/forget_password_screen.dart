import 'package:quick_scanner/utils/common_color.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/features/forget_password/logic/forget_password_view_model.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => ForgetPasswordScreenState();
}

class ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  final ForgetPasswordViewModel _forgetPasswordViewModel = Get.find<ForgetPasswordViewModel>();

  final GlobalKey<FormState> _forgetKey = GlobalKey<FormState>();

  static const primary = ColorConstants.authPrimary;
  static const primaryDark = ColorConstants.authPrimaryDark;
  static const primaryLight = ColorConstants.authPrimaryLight;
  static const textColor = ColorConstants.authText;
  static const hintColor = ColorConstants.authHint;
  static const borderColor = ColorConstants.border;
  static const bgColor = ColorConstants.authBackground;
  static const fieldFill = ColorConstants.fieldFill;

  // void message(String text) {
  //   ScaffoldMessenger.of(context)
  //     ..hideCurrentSnackBar()
  //     ..showSnackBar(
  //       SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  //     );
  // }

  InputDecoration decoration(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: hintColor, fontSize: 13),
      prefixIcon: Icon(icon, size: 18, color: hintColor),
      suffixIcon: suffix,
      filled: true,
      fillColor: ColorConstants.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ColorConstants.redAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Soft decorative gradient blobs in the background for depth.
          Positioned(
            top: -80,
            right: -60,
            child: _blob(220, primaryLight.withValues(alpha: 0.14)),
          ),
          Positioned(
            bottom: -100,
            left: -70,
            child: _blob(240, primary.withValues(alpha: 0.08)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Form(
                  key: _forgetKey,
                  child: Obx(
                    () => Container(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      decoration: BoxDecoration(
                        color: ColorConstants.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: ColorConstants.white, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                          BoxShadow(
                            color: ColorConstants.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 84,
                            width: 84,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primary.withValues(alpha: .14),
                                  primaryLight.withValues(alpha: .06),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              color: primary,
                              size: 42,
                            ),
                          ),

                          const SizedBox(height: 22),

                          const Text(
                            "Forgot Password?",
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: textColor,
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            "Enter your registered email address and we'll send you a password reset link.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: hintColor,
                              height: 1.55,
                            ),
                          ),

                          const SizedBox(height: 32),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "EMAIL ADDRESS",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: hintColor,
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          TextFormField(
                            controller:
                                _forgetPasswordViewModel.emailController.value,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: textColor,
                              fontWeight: FontWeight.w500,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Email is required";
                              }

                              if (!GetUtils.isEmail(value.trim())) {
                                return "Enter valid email";
                              }

                              return null;
                            },
                            decoration: InputDecoration(
                              hintText: "you@example.com",
                              hintStyle: const TextStyle(
                                color: hintColor,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                size: 20,
                                color: hintColor,
                              ),
                              filled: true,
                              fillColor: fieldFill,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: primary,
                                  width: 1.6,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: ColorConstants.redAccent,
                                  width: 1.2,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: ColorConstants.redAccent,
                                  width: 1.6,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [primary, primaryDark],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withValues(alpha: 0.35),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  if (_forgetKey.currentState!.validate()) {
                                    // forgot password api
                                    _forgetPasswordViewModel
                                        .clientForgetPassword();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ColorConstants.transparent,
                                  shadowColor: ColorConstants.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child:
                                    _forgetPasswordViewModel.isLoading.value
                                        ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: ColorConstants.white,
                                          ),
                                        )
                                        : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Text(
                                              "Send Reset Link",
                                              style: TextStyle(
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.w700,
                                                color: ColorConstants.white,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 18,
                                              color: ColorConstants.white,
                                            ),
                                          ],
                                        ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          TextButton.icon(
                            onPressed: () {
                              Get.back();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 14,
                            ),
                            label: const Text(
                              "Back to Login",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
