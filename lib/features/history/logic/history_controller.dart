import 'package:quick_scanner/utils/common_color.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:quick_scanner/features/history/data/history_resp_imp.dart';
import 'package:quick_scanner/features/history/data/history_respostires.dart';
import 'package:quick_scanner/features/history/model/history_model.dart';
import 'package:quick_scanner/networks/api_status.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:quick_scanner/networks/data_service.dart';
import 'package:quick_scanner/utils/const.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class HistoryController extends GetxController {
  /// First load (no data on screen yet) -> skeleton cards.
  final isLoading = false.obs;

  /// Pull-to-refresh / silent refresh while data is already on screen.
  final isRefreshing = false.obs;

  /// Remaining pages are still being fetched in the background.
  final isLoadingMore = false.obs;

  /// Set when the list could not be loaded (cleared on the next attempt).
  final errorMessage = RxnString();

  final invoices = <InvoiceData>[].obs;
  final meta = Rxn<Meta>();
  final tokenDataService = Get.find<TokenDataServiceImp>();

  /// Applied (debounced) search text and selected filter.
  final query = ''.obs;
  final filter = 'All'.obs;

  /// Updates instantly as the user types (drives the clear button).
  final hasSearchText = false.obs;

  /// Search + filter result, recomputed only when its inputs change.
  final filteredList = <InvoiceData>[].obs;

  final searchController = TextEditingController();
  final scrollController = ScrollController();

  final HistoryRespostires _repo = HistoryRespostiresImp();

  static const perPage = 5;
  static const _searchDelay = Duration(milliseconds: 300);
  final page = 1.obs;

  Timer? _searchDebounce;
  int _loadToken = 0; // a newer load makes older ones stop

  @override
  void onInit() {
    super.onInit();
    // any search or filter change goes back to page 1
    ever(query, (_) => page.value = 1);
    ever(filter, (_) => page.value = 1);
    everAll([invoices, query, filter], (_) => _recompute());
    fetchInvoices(); // also fills `recent` from the first page
  }

  int get totalPages {
    final n = filteredList.length;
    return n == 0 ? 1 : (n / perPage).ceil();
  }

  /// Reset search + filter + page back to defaults
  void resetFilters() {
    _searchDebounce?.cancel();
    searchController.clear();
    hasSearchText.value = false;
    query.value = '';
    filter.value = 'All';
    page.value = 1;
  }

  int get safePage => page.value.clamp(1, totalPages);

  // the 7 invoices of the current page
  List<InvoiceData> get paged {
    final start = (safePage - 1) * perPage;
    return filteredList.skip(start).take(perPage).toList();
  }

  void goToPage(int p) {
    page.value = p.clamp(1, totalPages);
    if (scrollController.hasClients) scrollController.jumpTo(0);
  }

  // [1, -1, 4, 5, 6, -1, 20]  (-1 = "…")
  List<int> get pageItems {
    final l = totalPages, c = safePage;
    if (l <= 5) return List.generate(l, (i) => i + 1);
    final s = <int>{1, l, c - 1, c, c + 1}..removeWhere((p) => p < 1 || p > l);
    final sorted = s.toList()..sort();
    final out = <int>[];
    for (var i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) out.add(-1);
      out.add(sorted[i]);
    }
    return out;
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    searchController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  final isExporting = false.obs;

  // Prefer the invoice-level raw_text, fall back to the per-image OCR text
  String rawTextOf(InvoiceData inv) {
    final top = inv.fields.rawText?.trim() ?? '';
    if (top.isNotEmpty) return top;
    return inv.images
        .map((i) => i.extractedData.rawText.trim())
        .where((t) => t.isNotEmpty)
        .join('\n\n');
  }

  /// One page from the API. Throws a readable message on failure.
  Future<InvoiceList?> _fetchPage(int page) async {
    final result = await _repo.invoiceList(page: page);
    if (result is SuccessStatus) return invoiceListFromJson(result.responseStr);
    if (result is FailureStatus) throw Exception(_friendly(result));
    return null;
  }

  String _friendly(FailureStatus f) {
    switch (f.statusCode) {
      case 101:
        return 'No internet connection';
      case 401:
      case 403:
        return 'Your session has expired. Please log in again.';
      default:
        return 'Could not load invoices (${f.statusCode})';
    }
  }

  String _errorText(Object e) =>
      e.toString().replaceFirst('Exception: ', '').replaceFirst('Error: ', '');

  // Loops through every page so the export contains all invoices, not just one page
  Future<List<InvoiceData>> fetchAllInvoices() async {
    final all = <InvoiceData>[];
    final seen = <int>{};
    try {
      var page = 1;
      var last = 1;
      do {
        final list = await _fetchPage(page);
        if (list == null) break;
        final fresh = list.data.where((e) => seen.add(e.id)).toList();
        if (fresh.isEmpty) break; // server ignored ?page= -> stop, no duplicates
        all.addAll(fresh);
        last = list.meta.lastPage;
        page++;
      } while (page <= last);
    } catch (e, s) {
      log('Export fetch error: $e\n$s');
    }
    return all;
  }

  final isDownloading = false.obs;

  /// Which invoice is downloading (so only its button shows a spinner).
  final downloadingId = RxnInt();

  /// format: 'pdf' or 'csv'. Adjust the query param to match your backend.
  Future<void> downloadInvoice(int invoiceId, {required String format}) async {
    if (isDownloading.value) return;
    isDownloading.value = true;
    downloadingId.value = invoiceId;

    try {
      final url = Uri.parse(
        '${APICalls.baseUrl}/invoices/$invoiceId/download?format=$format',
      );

      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer ${tokenDataService.accessToken}',
              'Accept': format == 'pdf' ? 'application/pdf' : 'text/csv',
            },
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        _toast('Download failed (${response.statusCode})', isError: true);
        return;
      }

      final bytes = response.bodyBytes;

      // Trust the actual bytes, not the requested format
      final isPdf =
          bytes.length >= 4 && String.fromCharCodes(bytes.take(4)) == '%PDF';
      final ext = isPdf ? 'pdf' : 'csv';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/invoice-$invoiceId.$ext');
      await file.writeAsBytes(bytes, flush: true);

      _toast('Invoice downloaded');

      // Option A: open it in a viewer app
      final result = await OpenFilex.open(file.path);

      // Option B (fallback): let the user save/share it to Files, Drive, etc.
      if (result.type != ResultType.done) {
        await Share.shareXFiles([XFile(file.path)]);
      }
    } catch (e, s) {
      log('Download error: $e\n$s');
      _toast('Something went wrong while downloading', isError: true);
    } finally {
      isDownloading.value = false;
      downloadingId.value = null;
    }
  }

  void _toast(String msg, {bool isError = false}) {
    final ctx = Get.context;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        backgroundColor: isError ? ColorConstants.red : ColorConstants.green,
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  // Future<void> downloadInvoicePdf(int invoiceId) async {
  //   final url = Uri.parse('${APICalls.baseUrl}/invoices/$invoiceId/download');

  //   try {
  //     final response = await http.get(
  //       url,
  //       headers: {
  //         'Authorization': 'Bearer ${tokenDataService.accessToken}',
  //         'Accept': 'application/pdf, text/csv, */*',
  //       },
  //     );

  //     if (response.statusCode != 200) {
  //       return;
  //     }

  //     final bytes = response.bodyBytes;

  //     // A real PDF always starts with "%PDF"
  //     final isPdf =
  //         bytes.length > 4 && String.fromCharCodes(bytes.take(4)) == '%PDF';

  //     final ext = isPdf ? 'pdf' : 'csv';

  //     final dir = await getApplicationDocumentsDirectory();
  //     final file = File('${dir.path}/invoice-$invoiceId.$ext');
  //     await file.writeAsBytes(bytes);
  //     // ignore: empty_catches
  //   } catch (e) {}
  // }

  /// Loads page 1 straight away, then the remaining pages in the background,
  /// so search / filter / export always work on the complete list.
  ///  * first load  -> first page shows immediately, others are appended
  ///  * refresh     -> old list stays on screen and is swapped once, no flicker
  /// A newer call cancels an older one (no stale data, no duplicates).
  Future<void> fetchInvoices({VoidCallback? onFirstPage}) async {
    final token = ++_loadToken;
    final firstLoad = invoices.isEmpty;

    errorMessage.value = null;
    isLoadingMore.value = false;
    if (firstLoad) {
      isLoading.value = true;
      isRecentLoading.value = recent.isEmpty;
    } else {
      isRefreshing.value = true;
    }

    try {
      final first = await _fetchPage(1);
      if (token != _loadToken || first == null) return;

      meta.value = first.meta;
      _setRecent(first);
      final all = List<InvoiceData>.of(first.data);
      final seen = all.map((e) => e.id).toSet();
      if (firstLoad) invoices.assignAll(all);
      isLoading.value = false;
      isRecentLoading.value = false;
      onFirstPage?.call();

      var page = first.meta.currentPage;
      final last = first.meta.lastPage;
      if (page < last) isLoadingMore.value = true;

      while (page < last) {
        page++;
        final next = await _fetchPage(page);
        if (token != _loadToken) return;
        if (next == null) break;
        final fresh = next.data.where((e) => seen.add(e.id)).toList();
        if (fresh.isEmpty) break; // server ignored ?page= -> stop
        all.addAll(fresh);
        meta.value = next.meta;
        if (firstLoad) invoices.addAll(fresh);
      }

      if (!firstLoad) invoices.assignAll(all);
    } catch (e, s) {
      log('Invoice load error: $e\n$s');
      if (token != _loadToken) return;
      final msg = _errorText(e);
      if (invoices.isEmpty) {
        errorMessage.value = msg; // full-screen error with Retry
      } else {
        _toast(msg, isError: true); // keep the list, just tell the user
      }
    } finally {
      if (token == _loadToken) {
        isLoading.value = false;
        isRefreshing.value = false;
        isLoadingMore.value = false;
        isRecentLoading.value = false;
      }
    }
  }

  /// For RefreshIndicator: completes as soon as the first page is back (the
  /// rest keeps loading in the background, shown by a thin progress bar).
  Future<void> refreshList() {
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    fetchInvoices(onFirstPage: finish).whenComplete(finish);
    return done.future;
  }

  final recent = <InvoiceData>[].obs;
  final recentTotal = 0.obs;
  final isRecentLoading = false.obs;

  void _setRecent(InvoiceList list) {
    recent.assignAll(list.data.take(4));
    recentTotal.value = list.meta.total;
  }

  /// Lightweight refresh of the "recent" strip only.
  Future<void> fetchRecent() async {
    isRecentLoading.value = recent.isEmpty;
    try {
      final first = await _fetchPage(1);
      if (first != null) _setRecent(first);
    } catch (e, s) {
      log('Recent invoices error: $e\n$s');
    } finally {
      isRecentLoading.value = false;
    }
  }

  /// Saves the edited text. Throws (so the edit screen stays open) on failure.
  Future<void> updateRawText(int id, String text) async {
    final http.Response res;
    try {
      res = await http
          .patch(
            Uri.parse('${APICalls.baseUrl}/invoices/$id'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${tokenDataService.accessToken}',
            },
            body: jsonEncode({'extracted_data': text}),
          )
          .timeout(const Duration(seconds: 30));
    } on SocketException {
      throw Exception('No internet connection');
    } on TimeoutException {
      throw Exception('The server took too long to respond');
    }

    debugPrint('Update ${res.statusCode}: ${res.body}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Update failed: ${res.statusCode}');
    }

    // Show the new text right away everywhere, then sync with the server.
    for (final list in [invoices, recent]) {
      for (final inv in list) {
        if (inv.id == id) inv.fields.rawText = text;
      }
      list.refresh();
    }
    _toast('Invoice updated successfully.');
    unawaited(fetchInvoices());
  }

  /// Called on every keystroke: the clear button reacts instantly, the (heavier)
  /// filtering waits until the user pauses typing.
  void onSearchChanged(String v) {
    hasSearchText.value = v.isNotEmpty;
    _searchDebounce?.cancel();
    if (v.trim().isEmpty) {
      query.value = '';
      return;
    }
    _searchDebounce = Timer(_searchDelay, () => query.value = v);
  }

  void clearSearch() {
    _searchDebounce?.cancel();
    searchController.clear();
    hasSearchText.value = false;
    query.value = '';
  }

  void deleteInvoice(int id) {
    invoices.removeWhere((e) => e.id == id);
  }

  /// Search + filter result (cached in [filteredList]).
  List<InvoiceData> get filtered => filteredList;

  void _recompute() {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    // every word typed must appear somewhere in the invoice
    final terms =
        query.value
            .trim()
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty)
            .toList();
    final f = filter.value;

    bool inRange(DateTime uploaded) {
      final d = uploaded.toLocal();
      final day = DateTime.utc(d.year, d.month, d.day);
      final diff = today.difference(day).inDays; // whole calendar days
      switch (f) {
        case 'Today':
          return diff == 0;
        case 'This Week':
          return diff >= 0 && diff < 7;
        case 'This Month':
          return day.year == today.year && day.month == today.month;
        default:
          return true;
      }
    }

    bool matches(InvoiceData inv) {
      if (terms.isEmpty) return true;
      final hay =
          [
            inv.supplier,
            inv.invoiceNo,
            inv.branch,
            inv.date?.toString() ?? '',
            inv.gross.toString(),
            inv.fields.rawText ?? '',
          ].join(' ').toLowerCase();
      return terms.every(hay.contains);
    }

    filteredList.assignAll(
      invoices.where((inv) => inRange(inv.uploadedAt) && matches(inv)),
    );
    // keep the current page valid after the result set shrinks
    if (page.value > totalPages) page.value = totalPages;
  }

  Map<String, List<InvoiceData>> grouped(List<InvoiceData> list) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(const Duration(days: 7));

    final groups = <String, List<InvoiceData>>{
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'Earlier': [],
    };

    for (final inv in list) {
      final d = inv.uploadedAt.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      if (day == today) {
        groups['Today']!.add(inv);
      } else if (day == yesterday) {
        groups['Yesterday']!.add(inv);
      } else if (day.isAfter(weekStart)) {
        groups['This Week']!.add(inv);
      } else {
        groups['Earlier']!.add(inv);
      }
    }
    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }
}
