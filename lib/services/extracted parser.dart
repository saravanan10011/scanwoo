class ExtractedDataParser {
  static Map<String, String> parseKeyValuePairs(String extractedText) {
    final Map<String, String> data = {};

    final lines = extractedText.split('\n');

    for (final rawLine in lines) {
      final line = rawLine.trim();

      if (line.isEmpty) continue;

      String? key;
      String? value;
      if (line.contains('|')) {
        final parts = line
            .split('|')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();

        if (parts.length >= 2) {
          key = parts.first;
          value = parts.sublist(1).join(' ');
        }
      }

      else if (line.contains(':')) {
        final parts = line.split(':');

        if (parts.length >= 2) {
          key = parts.first.trim();
          value = parts.sublist(1).join(':').trim();
        }
      }
      else {
        final result = _detectKnownField(line);

        if (result != null) {
          key = result['key'];
          value = result['value'];
        }
      }

      if (key != null &&
          value != null &&
          key.isNotEmpty &&
          value.isNotEmpty) {
        data[key] = value;
      }
    }

    return data;
  }

  static Map<String, String>? _detectKnownField(String line) {
    final lowerLine = line.toLowerCase();

    final moneyRegex = RegExp(
      r'(£|₹|\$|€|Rs\.?|INR)?\s*'
      r'([0-9]{1,3}(?:,[0-9]{3})*(?:\.\d{2})|[0-9]+\.\d{2})',
      caseSensitive: false,
    );

    final dateRegex = RegExp(
      r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b',
    );

    final moneyMatch = moneyRegex.firstMatch(line);
    final dateMatch = dateRegex.firstMatch(line);

    if (lowerLine.contains('total amount') && moneyMatch != null) {
      return {
        'key': 'Total Amount',
        'value': moneyMatch.group(0)!.trim(),
      };
    }

    if (lowerLine.contains('total') && moneyMatch != null) {
      return {
        'key': 'Total',
        'value': moneyMatch.group(0)!.trim(),
      };
    }

    if (lowerLine.contains('amount') && moneyMatch != null) {
      return {
        'key': 'Amount',
        'value': moneyMatch.group(0)!.trim(),
      };
    }

    if (lowerLine.contains('date') && dateMatch != null) {
      return {
        'key': 'Date',
        'value': dateMatch.group(0)!.trim(),
      };
    }

    return null;
  }
}