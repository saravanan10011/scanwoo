// To parse this JSON data, do
//
//     final dashboard = dashboardFromJson(jsonString);

import 'dart:convert';

Dashboard dashboardFromJson(String str) => Dashboard.fromJson(json.decode(str));

String dashboardToJson(Dashboard data) => json.encode(data.toJson());

class Dashboard {
  bool success;
  Data data;

  Dashboard({required this.success, required this.data});

  factory Dashboard.fromJson(Map<String, dynamic> json) =>
      Dashboard(success: json["success"], data: Data.fromJson(json["data"]));

  Map<String, dynamic> toJson() => {"success": success, "data": data.toJson()};
}

class Data {
  Client client;
  Stats stats;

  Data({required this.client, required this.stats});

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    client: Client.fromJson(json["client"]),
    stats: Stats.fromJson(json["stats"]),
  );

  Map<String, dynamic> toJson() => {
    "client": client.toJson(),
    "stats": stats.toJson(),
  };
}

class Client {
  int id;
  String name;
  String email;

  Client({required this.id, required this.name, required this.email});

  factory Client.fromJson(Map<String, dynamic> json) =>
      Client(id: json["id"], name: json["name"], email: json["email"]);

  Map<String, dynamic> toJson() => {"id": id, "name": name, "email": email};
}

class Stats {
  int invoicesThisMonth;
  int invoicesLastMonth;
  int invoicesChange;
  int uploadedInvoices;
  int uploadedTotal;

  Stats({
    required this.invoicesThisMonth,
    required this.invoicesLastMonth,
    required this.invoicesChange,
    required this.uploadedInvoices,
    required this.uploadedTotal,
  });

  factory Stats.fromJson(Map<String, dynamic> json) => Stats(
    invoicesThisMonth: (json["invoices_this_month"] as num).toInt(),
    invoicesLastMonth: (json["invoices_last_month"] as num).toInt(),
    invoicesChange: (json["invoices_change"] as num).toInt(),
    uploadedInvoices: (json["uploaded_invoices"] as num).toInt(),
    uploadedTotal: (json["uploaded_total"] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {
    "invoices_this_month": invoicesThisMonth,
    "invoices_last_month": invoicesLastMonth,
    "invoices_change": invoicesChange,
    "uploaded_invoices": uploadedInvoices,
    "uploaded_total": uploadedTotal,
  };
}
