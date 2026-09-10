import 'package:quick_scanner/services/apiservice.dart';

import '../models/scan_record.dart';

class HistoryRepository {
  final ApiService _api = ApiService();
  Future<List<ScanRecord>> getHistory(String token) async {
    final response = await _api.get('/scans/history', token: token);
        final List<dynamic> data = response['data'] ?? [];
    
    return data.map((json) => ScanRecord.fromJson(json)).toList();
  }
  Future<void> deleteRecord(String token, String recordId) async {
    await _api.delete('/scans/$recordId', token: token);
  }
  Future<void> uploadRecord(String token, ScanRecord record) async {
    await _api.post('/scans', record.toJson(), token: token);
  }
}