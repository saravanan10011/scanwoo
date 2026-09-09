class ScanRecord {
  final String text;
  final String imagePath;
  final DateTime createdAt;

  ScanRecord({
    required this.text,
    required this.imagePath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ScanRecord.fromJson(Map<String, dynamic> json) {
    return ScanRecord(
      text: json['text'] ?? '',
      imagePath: json['imagePath'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}