import 'package:flutter/material.dart';
import 'package:quick_scanner/screens/exportscreen.dart';
import 'package:quick_scanner/screens/history_screen.dart';
import 'package:quick_scanner/screens/home_screen.dart';
import 'package:quick_scanner/screens/profile.dart';
import '../widgets/bottomnav.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  late int index;

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
  }

  void onNavTap(int value) {
    setState(() {
      index = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          HomeScreen(
            onNavigateToTab: onNavTap,
          ),
          const ScanHistoryScreen(),
          const ExportScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: CommonBottomNav(
        selectedIndex: index,
        onItemSelected: onNavTap,
      ),
    );
  }
}