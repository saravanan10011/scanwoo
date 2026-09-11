import 'package:flutter/material.dart';
import 'package:quick_scanner/screens/extracted_text_screen.dart';
import '../models/scan_record.dart';
import '../services/scan_history_service.dart';
import '../widgets/record_card.dart';

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
    final search = query.trim().toLowerCase();

    return records.where((record) {
      final text = record.text.toLowerCase();

      if (search.isNotEmpty && !text.contains(search)) {
        return false;
      }

      final days = now.difference(record.createdAt).inDays;

      if (filter == 'Today') {
        return days == 0;
      }

      if (filter == 'This Week') {
        return days >= 0 && days <= 7;
      }

      if (filter == 'This Month') {
        return days >= 0 && days <= 30;
      }

      return true;
    }).toList();
  }

  void openExtractedText(ScanRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExtractedTextScreen(
          extractedText: record.text,
          imagePath: record.imagePath,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Invoice History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
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
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, index) {
                          final record = list[index];
                          final originalIndex = records.indexOf(record);

                          return RecordCard(
                            record: record,
                            onEdit: () => openExtractedText(record),
                            onDelete: () {
                              if (originalIndex >= 0) {
                                ScanHistoryService.deleteRecord(
                                  originalIndex,
                                );
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        onChanged: (value) {
          setState(() {
            query = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search invoices...',
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF777777),
          ),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      query = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: primary,
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterChips() {
    const filters = [
      'All',
      'Today',
      'This Week',
      'This Month',
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final currentFilter = filters[index];
          final active = currentFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                filter = currentFilter;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: active ? primary : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? primary
                      : const Color(0xFFE7E7EE),
                ),
              ),
              child: Text(
                currentFilter,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? Colors.white
                      : const Color(0xFF666666),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 34,
                color: primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              query.trim().isNotEmpty
                  ? 'No invoices found'
                  : 'No invoices yet',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              query.trim().isNotEmpty
                  ? 'Try searching with another keyword.'
                  : 'Your saved invoices will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}