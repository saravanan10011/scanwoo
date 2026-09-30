import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/features/history/screens/history_screen.dart';
import 'package:quick_scanner/features/home/screen/home_screen.dart';
import 'package:quick_scanner/features/profile/profile.dart';
import 'package:quick_scanner/features/scan_document/screens/exportscreen.dart';
import '../../widgets/bottomnav.dart';

class MainController extends GetxController {
  static const int tabCount = 4;

  final int initialIndex;
  MainController({this.initialIndex = 0});

  late final RxInt index = initialIndex.clamp(0, tabCount - 1).obs;

  void onNavTap(int value) {
    if (value == index.value) return; // avoid pointless rebuilds
    index.value = value;
  }
}

class MainScreen extends StatelessWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(MainController(initialIndex: initialIndex));

    // Built once, so tab state is preserved by IndexedStack
    final screens = <Widget>[
      HomeScreen(onNavigateToTab: c.onNavTap),
      ScanHistoryScreen(onBack: () => c.onNavTap(0)),
      ExportScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: Obx(() => IndexedStack(index: c.index.value, children: screens)),
      bottomNavigationBar: Obx(
        () => CommonBottomNav(
          selectedIndex: c.index.value,
          onItemSelected: c.onNavTap,
        ),
      ),
    );
  }
}
