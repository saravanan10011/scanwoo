import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quick_scanner/screens/profile.dart';
import '../widgets/bottomnav.dart';
import 'exportscreen.dart';
import 'history_screen.dart';
import 'scanner_screen.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => HomeScreenState();
}
class HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  void openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
  }
  void openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanHistoryScreen()),
    );
  }
  void openExport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExportScreen()),
    );
  }
  void openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }
  void onBottomNavSelected(int index) {
    setState(() => selectedIndex = index);
    if (index == 1) {
      openHistory();
    } else if (index == 2) {
      openExport();
    } else if (index == 3) {
      openProfile();
    }
  }
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF3038D8),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              topSection(),
              content(),
            ],
          ),
        ),
        bottomNavigationBar: CommonBottomNav(
          selectedIndex: selectedIndex,
          onItemSelected: onBottomNavSelected,
        ),
      ),
    );
  }

  Widget topSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 45, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3038D8), Color(0xFF5146E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hello, User!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Good to see you!',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: openScanner,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9E9FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.document_scanner_outlined,
                      color: Color(0xFF4038D8),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan Invoice',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Extract data in seconds',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Color(0xFF4038D8),
                    size: 17,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget content() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: actionCard(
                  Icons.camera_alt_outlined,
                  'Scan with Camera',
                  'Capture new invoice',
                  openScanner,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: actionCard(
                  Icons.image_outlined,
                  'Pick from Gallery',
                  'Select from device',
                  openScanner,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: actionCard(
                  Icons.history,
                  'View History',
                  'Previous scans',
                  openHistory,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: actionCard(
                  Icons.description_outlined,
                  'Export Records',
                  'Excel / PDF',
                  openExport,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Invoices',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: openHistory,
                child: const Text('View all →'),
              ),
            ],
          ),
          invoice('ABC Textiles', 'INV-1025 • 01 Sep 2026', '₹3,465'),
          invoice('XYZ Mart', 'BILL-4567 • 28 Aug 2026', '₹2,450'),
          invoice(
            'Sri Venkateshwara Traders',
            'INV-2201 • 25 Aug 2026',
            '₹1,890',
          ),
        ],
      ),
    );
  }

  Widget actionCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 105,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF4038D8), size: 25),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget invoice(String company, String details, String amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF0FF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Color(0xFF4038D8),
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  details,
                  style: const TextStyle(color: Colors.grey, fontSize: 9),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}