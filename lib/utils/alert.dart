import 'package:quick_scanner/utils/common_color.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum AlertType { success, error, info, warning }

class AppAlert {
  static void show(
    String message, {
    String? title,
    AlertType type = AlertType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final config = _config(type);

    // Close any snackbar that's currently showing so they don't queue up
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();

    Get.snackbar(
      '',
      '',
      titleText: Text(
        title ?? config.title,
        style: const TextStyle(
          color: ColorConstants.white,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      messageText: Text(
        message,
        style: TextStyle(
          color: ColorConstants.white.withValues(alpha: 0.92),
          fontSize: 13,
        ),
      ),
      icon: Icon(config.icon, color: ColorConstants.white, size: 28),
      shouldIconPulse: false,
      backgroundColor: config.color,
      borderRadius: 12,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      snackPosition: SnackPosition.TOP,
      duration: duration,
      animationDuration: const Duration(milliseconds: 350),
      forwardAnimationCurve: Curves.easeOutBack,
      reverseAnimationCurve: Curves.easeIn,
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
      boxShadows: [
        BoxShadow(
          color: ColorConstants.black.withValues(alpha: 0.15),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static void success(String message, {String? title}) =>
      show(message, title: title, type: AlertType.success);

  static void error(String message, {String? title}) => show(
    message,
    title: title,
    type: AlertType.error,
    duration: const Duration(seconds: 4),
  );

  static void info(String message, {String? title}) =>
      show(message, title: title, type: AlertType.info);

  static void warning(String message, {String? title}) =>
      show(message, title: title, type: AlertType.warning);

  static _AlertConfig _config(AlertType type) {
    switch (type) {
      case AlertType.success:
        return _AlertConfig(
          ColorConstants.success3,
          Icons.check_circle_rounded,
          'Success',
        );
      case AlertType.error:
        return _AlertConfig(
          ColorConstants.danger3,
          Icons.error_rounded,
          'Error',
        );
      case AlertType.warning:
        return _AlertConfig(
          ColorConstants.warning2,
          Icons.warning_rounded,
          'Warning',
        );
      case AlertType.info:
        return _AlertConfig(
          ColorConstants.blueSoft,
          Icons.info_rounded,
          'Info',
        );
    }
  }
}

class _AlertConfig {
  final Color color;
  final IconData icon;
  final String title;
  _AlertConfig(this.color, this.icon, this.title);
}
