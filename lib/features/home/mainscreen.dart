import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quick_scanner/features/history/logic/history_controller.dart';
import 'package:quick_scanner/features/history/screens/history_screen.dart';
import 'package:quick_scanner/features/home/screen/home_screen.dart';
import 'package:quick_scanner/features/profile/profile.dart';
import '../../widgets/bottomnav.dart';

class MainController extends GetxController {
  static const int tabCount = 4;

  final int initialIndex;
  MainController({this.initialIndex = 0});

  late final RxInt index = initialIndex.clamp(0, tabCount - 1).obs;

  void onNavTap(int value) {
    if (value == index.value) return; // avoid pointless rebuilds
    // Leaving the History tab -> clear search, filter and page.
    if (index.value == 1 && Get.isRegistered<HistoryController>()) {
      Get.find<HistoryController>().resetFilters();
    }
    index.value = value;
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<MainController>();

    // Built once, so tab state is preserved by IndexedStack
    final screens = <Widget>[
      HomeScreen(onNavigateToTab: c.onNavTap),
      ScanHistoryScreen(onBack: () => c.onNavTap(0)),
      // ExportScreen(),
      const ProfileScreen(),
    ];

    // One Obx for the whole screen.
    return Obx(
      () => Scaffold(
        body: IndexedStack(index: c.index.value, children: screens),
        bottomNavigationBar: CommonBottomNav(
          selectedIndex: c.index.value,
          onItemSelected: c.onNavTap,
        ),
      ),
    );
  }
}
