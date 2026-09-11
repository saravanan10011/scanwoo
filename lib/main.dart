import 'package:flutter/material.dart';
import 'package:quick_scanner/screens/splash_screen.dart';
import 'services/scan_history_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ScanHistoryService.initialize();

  runApp(const QuickScannerApp());
}

class QuickScannerApp extends StatelessWidget {
  const QuickScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}