import 'dart:io';

import 'package:get/get.dart';
import 'package:quick_scanner/features/forget_password/logic/forget_password_view_model.dart';
import 'package:quick_scanner/features/forget_password/screen/forget_password_screen.dart';
import 'package:quick_scanner/features/forget_password/screen/reset_password_screen.dart';
import 'package:quick_scanner/features/history/logic/history_controller.dart';
import 'package:quick_scanner/features/history/model/history_model.dart';
import 'package:quick_scanner/features/history/screens/edit_screen.dart';
import 'package:quick_scanner/features/history/screens/sub_screen/edit_screen.dart';
import 'package:quick_scanner/features/home/mainscreen.dart';
import 'package:quick_scanner/features/login_screen/logic/login_controller.dart';
import 'package:quick_scanner/features/login_screen/screen/login_screen.dart';
import 'package:quick_scanner/features/profile/change_password.dart';
import 'package:quick_scanner/features/profile/logic/profile_controller.dart';
import 'package:quick_scanner/features/scan_document/logic/scannercontroller.dart';
import 'package:quick_scanner/features/scan_document/screens/crop_screen.dart';
import 'package:quick_scanner/features/scan_document/screens/preview_screen.dart';
import 'package:quick_scanner/features/scan_document/screens/processing_screen.dart';
import 'package:quick_scanner/features/scan_document/screens/scanner_screen.dart';
import 'package:quick_scanner/features/splash/splash_screen.dart';
import 'package:quick_scanner/routes_list.dart';
import 'package:quick_scanner/services/models/scan_record.dart';

class Routes {
  Routes._();

  static Map<String, dynamic> get _args =>
      (Get.arguments as Map?)?.cast<String, dynamic>() ?? const {};

  static final routes = <GetPage>[
    GetPage(name: RouteList.inital, page: () => SplashScreen()),

    // ---- Auth ------------------------------------------------------------
    GetPage(
      name: RouteList.login,
      page: () => LoginScreen(),
      binding: BindingsBuilder(
        () => Get.lazyPut<LoginController>(() => LoginController()),
      ),
    ),
    GetPage(
      name: RouteList.forgetpassword,
      page: () => ForgetPasswordScreen(),
      binding: BindingsBuilder(
        () => Get.lazyPut<ForgetPasswordViewModel>(
          () => ForgetPasswordViewModel(),
        ),
      ),
    ),
    GetPage(
      name: RouteList.resetPassword,
      page: () => ResetPasswordScreen(),
      binding: BindingsBuilder(
        () => Get.lazyPut<ForgetPasswordViewModel>(
          () => ForgetPasswordViewModel(),
        ),
      ),
    ),

    // ---- Main (tabs: home / history / export / profile) -------------------
    GetPage(
      name: RouteList.mainscreen,
      page: () => const MainScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut<MainController>(
          () => MainController(
            initialIndex: (_args['initialIndex'] as int?) ?? 0,
          ),
        );
        Get.lazyPut<HistoryController>(() => HistoryController(), fenix: true);
        Get.lazyPut<ProfileController>(() => ProfileController(), fenix: true);
      }),
    ),
    GetPage(
      name: RouteList.changepassword,
      page: () => ProfileChangePasswordScreen(),
      binding: BindingsBuilder(
        () => Get.lazyPut<ProfileController>(
          () => ProfileController(),
          fenix: true,
        ),
      ),
    ),

    // ---- Scan flow -------------------------------------------------------
    GetPage(
      name: RouteList.scanner,
      page: () => const ScannerScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut<ScannerController>(() => ScannerController());
        Get.lazyPut<ScannerScreenController>(() => ScannerScreenController());
        Get.lazyPut<HistoryController>(() => HistoryController(), fenix: true);
        Get.lazyPut<ProfileController>(() => ProfileController(), fenix: true);
      }),
    ),
    GetPage(
      name: RouteList.cropAdjust,
      page: () => CropAdjustScreen(image: _args['image'] as File),
    ),
    GetPage(
      name: RouteList.processing,
      page:
          () => ProcessingScreen(
            imagePaths: (_args['imagePaths'] as List).cast<String>(),
            onProcess:
                _args['onProcess']
                    as Future<List<String>> Function(List<String> paths),
          ),
    ),
    GetPage(
      name: RouteList.scanPreview,
      page: () => ScanPreviewScreen(record: _args['record'] as ScanRecord),
    ),
    GetPage(
      name: RouteList.editRecord,
      page:
          () =>
              EditRecordScreen(extractedText: _args['extractedText'] as String),
    ),

    // ---- History ---------------------------------------------------------
    GetPage(
      name: RouteList.editRawText,
      page:
          () => EditRawTextScreen(
            invoice: _args['invoice'] as InvoiceData,
            initialText: _args['initialText'] as String,
            onSave: _args['onSave'] as Future<void> Function(String text),
          ),
    ),
  ];
}
