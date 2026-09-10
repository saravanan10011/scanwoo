import 'package:flutter/material.dart';
import '../models/scan_record.dart';
import '../services/scan_history_service.dart';
import '../widgets/bottomnav.dart';
import '../widgets/record_card.dart';
import 'exportscreen.dart';
import 'preview_screen.dart';

const primary = Color(0xFF4038D8);
const background = Color(0xFFF5F7FB);

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => ScanHistoryScreenState();
}

class ScanHistoryScreenState extends State<ScanHistoryScreen> {
  String query = '';
  String filter = 'All';

  List<ScanRecord> applyFilter(List<ScanRecord> records) {
    final now = DateTime.now();
    return records.where((r) {
      if (query.isNotEmpty &&
          !r.text.toLowerCase().contains(query.toLowerCase())) {
        return false;
      }
      final days = now.difference(r.createdAt).inDays;
      if (filter == 'Today') return days == 0;
      if (filter == 'This Week') return days <= 7;
      if (filter == 'This Month') return days <= 30;
      return true;
    }).toList();
  }

  void onBottomNavSelected(int index) {
    if (index == 1) return;
    if (index == 0) {
      Navigator.pop(context);
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ExportScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Invoice History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ValueListenableBuilder<List<ScanRecord>>(
        valueListenable: ScanHistoryService.recordsNotifier,
        builder: (_, records, __) {
          final list = applyFilter(records);
          return Column(
            children: [
              _searchBar(),
              const SizedBox(height: 12),
              _filterChips(),
              const SizedBox(height: 12),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('No invoices yet'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final r = list[i];
                          final idx = records.indexOf(r);
                          return RecordCard(
                            record: r,
                            onEdit: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScanPreviewScreen(record: r),
                              ),
                            ),
                            onDelete: () =>
                                ScanHistoryService.deleteRecord(idx),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: CommonBottomNav(
        selectedIndex: 1,
        onItemSelected: onBottomNavSelected,
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        onChanged: (v) => setState(() => query = v),
        decoration: InputDecoration(
          hintText: 'Search invoices...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _filterChips() {
    const filters = ['All', 'Today', 'This Week', 'This Month'];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = filters[i];
          final active = f == filter;
          return GestureDetector(
            onTap: () => setState(() => filter = f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: active ? primary : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active ? primary : const Color(0xFFE7E7EE),
                ),
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : const Color(0xFF666666),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}