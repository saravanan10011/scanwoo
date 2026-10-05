// Null-safe invoice models. Nothing here can throw on missing / null /
// unexpected values from the API.

// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'package:quick_scanner/utils/helpers.dart';

InvoiceList invoiceListFromJson(String str) =>
    InvoiceList.fromJson(json.decode(str));

String invoiceListToJson(InvoiceList data) => json.encode(data.toJson());

String _s(dynamic v) {
  final s = v == null ? '' : v.toString().trim();
  return (s.isEmpty || s == '—' || s == '-' || s.toLowerCase() == 'null')
      ? 'N/A'
      : s;
}

String? _sn(dynamic v) => v?.toString();

/// num or numeric String -> double (null if not parsable).
double? _dn(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '').trim());
}

double _d(dynamic v) => _dn(v) ?? 0.0;

int _i(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

bool _b(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v == null) return fallback;
  final t = v.toString().toLowerCase();
  if (t == 'true' || t == '1' || t == 'yes') return true;
  if (t == 'false' || t == '0' || t == 'no') return false;
  return fallback;
}

/// Laravel/PHP sends `[]` instead of `{}` for empty objects -> handle both.
Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<dynamic> _list(dynamic v) => v is List ? v : const [];

// ───────────────────────────── InvoiceList ──────────────────────────────

class InvoiceList {
  bool success;
  List<InvoiceData> data;
  Meta meta;

  InvoiceList({required this.success, required this.data, required this.meta});

  factory InvoiceList.fromJson(Map<String, dynamic> json) => InvoiceList(
    success: _b(json["success"], true),
    data:
        _list(json["data"]).map((x) => InvoiceData.fromJson(_map(x))).toList(),
    meta: Meta.fromJson(_map(json["meta"])),
  );

  Map<String, dynamic> toJson() => {
    "success": success,
    "data": data.map((x) => x.toJson()).toList(),
    "meta": meta.toJson(),
  };
}

// ───────────────────────────── InvoiceData ──────────────────────────────

class InvoiceData {
  int id;
  String supplier;
  String vatNumber;
  String invoiceNo;
  String branch;
  dynamic date;
  double net;
  double? vat;
  double gross;
  dynamic sr;
  dynamic zr;
  dynamic exempt;
  Payment payment;
  String currency; // NEW: "£", "€", "$", "₹" (detected from OCR text)

  OcrStatus ocrStatus;
  Status status;
  DateTime uploadedAt;
  String uploadedAtIso;
  String uploadedAtDisplay;
  Fields fields;
  List<Image> images;
  int imagesUnviewedCount;

  InvoiceData({
    required this.id,
    required this.supplier,
    required this.vatNumber,
    required this.invoiceNo,
    required this.branch,
    required this.date,
    required this.net,
    required this.vat,
    required this.gross,
    required this.sr,
    required this.zr,
    required this.exempt,
    required this.payment,
    this.currency = '£', // NEW
    required this.ocrStatus,
    required this.status,
    required this.uploadedAt,
    required this.uploadedAtIso,
    required this.uploadedAtDisplay,
    required this.fields,
    required this.images,
    required this.imagesUnviewedCount,
  });

  /// NEW: e.g. "£505.82" (symbol + thousands separator + 2 decimals)
  String get grossFormatted => formatMoney(gross, symbol: currency);

  factory InvoiceData.fromJson(Map<String, dynamic> json) {
    final images =
        _list(json["images"]).map((x) => Image.fromJson(_map(x))).toList();

    // New API no longer sends a top-level "fields" object; the OCR text is
    // inside images[].extracted_data. Fall back to the first image's text.
    final Fields fields =
        json["fields"] is Map && (json["fields"] as Map).isNotEmpty
            ? Fields.fromJson(_map(json["fields"]))
            : Fields(
              rawText:
                  images.isNotEmpty ? images.first.extractedData.rawText : null,
              items: const [],
            );

    final cur = _s(json["currency"]).trim();

    return InvoiceData(
      id: _i(json["id"]),
      supplier: _s(json["supplier"]),
      vatNumber: _s(json["vat_number"]),
      invoiceNo: _s(json["invoice_no"]),
      branch: _s(json["branch"]),
      date: json["date"],
      net: _d(json["net"]),
      vat: _dn(json["vat"]),
      gross: _d(json["gross"]),
      sr: json["sr"],
      zr: json["zr"],
      exempt: json["exempt"],
      payment: paymentValues.map[json["payment"]] ?? Payment.EMPTY,
      currency: cur.isEmpty ? '£' : cur, // NEW
      ocrStatus: ocrStatusValues.map[json["ocr_status"]] ?? OcrStatus.UNKNOWN,
      status: statusValues.map[json["status"]] ?? Status.UNKNOWN,
      uploadedAt: parseServerTime(
        json["uploaded_at_iso"] ?? json["uploaded_at"],
      ),
      uploadedAtIso: _s(json["uploaded_at_iso"]),
      uploadedAtDisplay: _s(json["uploaded_at_display"]),
      fields: fields,
      images: images,
      imagesUnviewedCount: _i(json["images_unviewed_count"]),
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "supplier": supplier,
    "vat_number": vatNumber,
    "invoice_no": invoiceNo,
    "branch": branch,
    "date": date,
    "net": net,
    "vat": vat,
    "gross": gross,
    "sr": sr,
    "zr": zr,
    "exempt": exempt,
    "payment": paymentValues.reverse[payment],
    "currency": currency, // NEW
    "ocr_status": ocrStatusValues.reverse[ocrStatus],
    "status": statusValues.reverse[status],
    "uploaded_at": uploadedAt.toUtc().toIso8601String(),
    "uploaded_at_iso": uploadedAtIso,
    "uploaded_at_display": uploadedAtDisplay,
    "fields": fields.toJson(),
    "images": images.map((x) => x.toJson()).toList(),
    "images_unviewed_count": imagesUnviewedCount,
  };
}
// ─────────────────────────────── Fields ─────────────────────────────────

class Fields {
  String? rawText;
  ParsedHeader? parsedHeader;
  List<Item>? items;
  bool? needsReview;
  String? paymentDetails;
  String? accountName;
  String? accountNumber;
  String? ifscCode;
  String? branch;
  String? paymentTerms;
  String? subtotal;
  String? billTo;
  String? shipToIfDifferent;
  String? email;

  Fields({
    this.rawText,
    this.parsedHeader,
    this.items,
    this.needsReview,
    this.paymentDetails,
    this.accountName,
    this.accountNumber,
    this.ifscCode,
    this.branch,
    this.paymentTerms,
    this.subtotal,
    this.billTo,
    this.shipToIfDifferent,
    this.email,
  });

  factory Fields.fromJson(Map<String, dynamic> json) => Fields(
    rawText: _sn(json["raw_text"]),
    parsedHeader:
        json["parsed_header"] is Map
            ? ParsedHeader.fromJson(_map(json["parsed_header"]))
            : null,
    items: _list(json["items"]).map((x) => Item.fromJson(_map(x))).toList(),
    needsReview: json["needs_review"] == null ? null : _b(json["needs_review"]),
    paymentDetails: _sn(json["Payment Details"]),
    accountName: _sn(json["Account Name"]),
    accountNumber: _sn(json["Account Number"]),
    ifscCode: _sn(json["IFSC Code"]),
    branch: _sn(json["Branch"]),
    paymentTerms: _sn(json["Payment Terms"]),
    subtotal: _sn(json["Subtotal"]),
    billTo: _sn(json["Bill To"]),
    shipToIfDifferent: _sn(json["Ship To (If Different)"]),
    email: _sn(json["Email"]),
  );

  Map<String, dynamic> toJson() => {
    "raw_text": rawText,
    "parsed_header": parsedHeader?.toJson(),
    "items": items?.map((x) => x.toJson()).toList() ?? [],
    "needs_review": needsReview,
    "Payment Details": paymentDetails,
    "Account Name": accountName,
    "Account Number": accountNumber,
    "IFSC Code": ifscCode,
    "Branch": branch,
    "Payment Terms": paymentTerms,
    "Subtotal": subtotal,
    "Bill To": billTo,
    "Ship To (If Different)": shipToIfDifferent,
    "Email": email,
  };
}

// ─────────────────────────────── Item ───────────────────────────────────

class Item {
  String qty;
  String description;
  String amount;
  String vat;
  String total;
  String rawOcrLine;
  NeedsReview needsReview;

  Item({
    required this.qty,
    required this.description,
    required this.amount,
    required this.vat,
    required this.total,
    required this.rawOcrLine,
    required this.needsReview,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
    qty: _s(json["qty"]),
    description: _s(json["description"]),
    amount: _s(json["amount"]),
    vat: _s(json["vat"]),
    total: _s(json["total"]),
    rawOcrLine: _s(json["raw_ocr_line"]),
    needsReview: needsReviewValues.map[json["needs_review"]] ?? NeedsReview.NO,
  );

  Map<String, dynamic> toJson() => {
    "qty": qty,
    "description": description,
    "amount": amount,
    "vat": vat,
    "total": total,
    "raw_ocr_line": rawOcrLine,
    "needs_review": needsReviewValues.reverse[needsReview],
  };
}

enum NeedsReview { NO, YES }

final needsReviewValues = EnumValues({
  "No": NeedsReview.NO,
  "Yes": NeedsReview.YES,
});

// ───────────────────────────── ParsedHeader ─────────────────────────────

class ParsedHeader {
  String companyName;
  String? totalVat;
  Payment? paymentTerms;
  String? vatNumber;
  String? invoiceNo;
  String? invoiceDate;
  String? accountNo;
  String? subTotal;
  String? grandTotal;
  String? previousBalance;

  ParsedHeader({
    required this.companyName,
    this.totalVat,
    this.paymentTerms,
    this.vatNumber,
    this.invoiceNo,
    this.invoiceDate,
    this.accountNo,
    this.subTotal,
    this.grandTotal,
    this.previousBalance,
  });

  factory ParsedHeader.fromJson(Map<String, dynamic> json) => ParsedHeader(
    companyName: _s(json["company_name"]),
    totalVat: _sn(json["total_vat"]),
    paymentTerms: paymentValues.map[json["payment_terms"]],
    vatNumber: _sn(json["vat_number"]),
    invoiceNo: _sn(json["invoice_no"]),
    invoiceDate: _sn(json["invoice_date"]),
    accountNo: _sn(json["account_no"]),
    subTotal: _sn(json["sub_total"]),
    grandTotal: _sn(json["grand_total"]),
    previousBalance: _sn(json["previous_balance"]),
  );

  Map<String, dynamic> toJson() => {
    "company_name": companyName,
    "total_vat": totalVat,
    "payment_terms":
        paymentTerms == null ? null : paymentValues.reverse[paymentTerms],
    "vat_number": vatNumber,
    "invoice_no": invoiceNo,
    "invoice_date": invoiceDate,
    "account_no": accountNo,
    "sub_total": subTotal,
    "grand_total": grandTotal,
    "previous_balance": previousBalance,
  };
}

// ───────────────────────────── Enums (safe) ─────────────────────────────

enum Payment { CARD, CASH, CREDIT, EMPTY }

final paymentValues = EnumValues({
  "Card": Payment.CARD,
  "Cash": Payment.CASH,
  "Credit": Payment.CREDIT,
  "—": Payment.EMPTY,
});

enum OcrStatus { COMPLETE, UNKNOWN }

final ocrStatusValues = EnumValues({
  "complete": OcrStatus.COMPLETE,
  "unknown": OcrStatus.UNKNOWN,
});

enum Status { PENDING, UNKNOWN }

final statusValues = EnumValues({
  "pending": Status.PENDING,
  "unknown": Status.UNKNOWN,
});

// ─────────────────────────────── Image ──────────────────────────────────

class Image {
  int id;
  String filePath;
  String url;
  String originalName;
  String mimeType;
  ExtractedData extractedData;
  OcrStatus ocrStatus;
  int size;
  int sortOrder;
  bool isViewed;
  dynamic viewedAt;

  Image({
    required this.id,
    required this.filePath,
    required this.url,
    required this.originalName,
    required this.mimeType,
    required this.extractedData,
    required this.ocrStatus,
    required this.size,
    required this.sortOrder,
    required this.isViewed,
    required this.viewedAt,
  });

  factory Image.fromJson(Map<String, dynamic> json) => Image(
    id: _i(json["id"]),
    filePath: _s(json["file_path"]),
    url: _s(json["url"]),
    originalName: _s(json["original_name"]),
    mimeType: _s(json["mime_type"]),
    extractedData: ExtractedData.fromJson(_map(json["extracted_data"])),
    ocrStatus: ocrStatusValues.map[json["ocr_status"]] ?? OcrStatus.UNKNOWN,
    size: _i(json["size"]),
    sortOrder: _i(json["sort_order"]),
    isViewed: _b(json["is_viewed"]),
    viewedAt: json["viewed_at"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "file_path": filePath,
    "url": url,
    "original_name": originalName,
    "mime_type": mimeType,
    "extracted_data": extractedData.toJson(),
    "ocr_status": ocrStatusValues.reverse[ocrStatus],
    "size": size,
    "sort_order": sortOrder,
    "is_viewed": isViewed,
    "viewed_at": viewedAt,
  };
}

class ExtractedData {
  String rawText;

  ExtractedData({required this.rawText});

  factory ExtractedData.fromJson(Map<String, dynamic> json) =>
      ExtractedData(rawText: _s(json["raw_text"]));

  Map<String, dynamic> toJson() => {"raw_text": rawText};
}

class Meta {
  int currentPage;
  int lastPage;
  int perPage;
  int total;

  Meta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory Meta.fromJson(Map<String, dynamic> json) => Meta(
    currentPage: _i(json["current_page"], 1),
    lastPage: _i(json["last_page"], 1),
    perPage: _i(json["per_page"]),
    total: _i(json["total"]),
  );

  Map<String, dynamic> toJson() => {
    "current_page": currentPage,
    "last_page": lastPage,
    "per_page": perPage,
    "total": total,
  };
}

class EnumValues<T> {
  Map<String, T> map;
  late Map<T, String> reverseMap = map.map((k, v) => MapEntry(v, k));

  EnumValues(this.map);

  Map<T, String> get reverse => reverseMap;
}
