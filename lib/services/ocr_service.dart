import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

/// Needs the `image` package:  flutter pub add image
///
/// Runs ML Kit twice (original photo + an enhanced copy: upscaled, grayscale,
/// contrast-normalised) and keeps whichever result has more useful text.
/// Rows are rebuilt from bounding boxes, with page tilt compensated so the
/// label/value columns of a photographed invoice stay on the same row.
class OcrService {
  final TextRecognizer textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<String> extractText(File imageFile) async {
    try {
      final original = await _recognize(imageFile);

      var enhanced = '';
      File? tmp;
      try {
        final bytes = await compute(_enhanceImage, imageFile.path);
        tmp = File(
          '${Directory.systemTemp.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
        );
        await tmp.writeAsBytes(bytes, flush: true);
        enhanced = await _recognize(tmp);
      } catch (e) {
        debugPrint('OCR enhance pass failed: $e');
      } finally {
        try {
          await tmp?.delete();
        } catch (_) {}
      }

      final best = _score(enhanced) > _score(original) ? enhanced : original;

      debugPrint(
        'OCR original=${_score(original)} enhanced=${_score(enhanced)} '
        'using=${identical(best, enhanced) ? 'enhanced' : 'original'}',
      );
      debugPrint('---- OCR TEXT ----\n$best\n------------------');

      return best;
    } catch (e) {
      throw Exception('Failed to extract text: $e');
    }
  }

  /// Higher = more useful text (letters/digits plus invoice keywords).
  int _score(String text) {
    if (text.isEmpty) return 0;
    final alnum = RegExp(r'[A-Za-z0-9]').allMatches(text).length;
    final keywords =
        RegExp(
          r'invoice|total|vat|date|amount|subtotal|balance|limited|ltd',
          caseSensitive: false,
        ).allMatches(text).length;
    return alnum + keywords * 40;
  }

  Future<String> _recognize(File file) async {
    final recognized = await textRecognizer.processImage(
      InputImage.fromFile(file),
    );
    if (recognized.blocks.isEmpty) return '';

    // 1. Collect every line with its geometry.
    final raw = <_RawLine>[];
    final slopes = <double>[];

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final box = line.boundingBox;
        final elements =
            line.elements
                .map(
                  (e) => TextElementData(
                    text: e.text.trim(),
                    top: e.boundingBox.top,
                    bottom: e.boundingBox.bottom,
                    left: e.boundingBox.left,
                    right: e.boundingBox.right,
                  ),
                )
                .where((e) => e.text.isNotEmpty)
                .toList()
              ..sort((a, b) => a.left.compareTo(b.left));

        final text =
            elements.isEmpty
                ? line.text.trim()
                : _buildPositionAwareLine(elements);
        if (text.isEmpty) continue;

        // Slope of this line = tilt of the page at this spot.
        if (elements.length >= 2) {
          final f = elements.first;
          final l = elements.last;
          final dx = ((l.left + l.right) - (f.left + f.right)) / 2;
          if (dx > 80) {
            final dy = ((l.top + l.bottom) - (f.top + f.bottom)) / 2;
            slopes.add(dy / dx);
          }
        }

        raw.add(
          _RawLine(
            text: text,
            top: box.top,
            bottom: box.bottom,
            left: box.left,
            right: box.right,
          ),
        );
      }
    }

    // 2. Page tilt (median slope of long lines), clamped to about +-8 degrees.
    var slope = 0.0;
    if (slopes.length >= 3) {
      slopes.sort();
      slope = slopes[slopes.length ~/ 2].clamp(-0.14, 0.14).toDouble();
    }

    // 3. Group lines into rows using tilt-corrected Y.
    final rows = <OcrRow>[];
    for (final l in raw) {
      final shift = slope * ((l.left + l.right) / 2);
      _addLineToRow(
        rows,
        TextLineData(
          text: l.text,
          top: l.top - shift,
          bottom: l.bottom - shift,
          left: l.left,
          right: l.right,
        ),
      );
    }

    rows.sort((a, b) => a.centerY.compareTo(b.centerY));

    final result = StringBuffer();
    for (final row in rows) {
      row.lines.sort((a, b) => a.left.compareTo(b.left));
      for (var i = 0; i < row.lines.length; i++) {
        if (i > 0) result.write(' | ');
        result.write(row.lines[i].text);
      }
      result.writeln();
    }
    return result.toString().trim();
  }

  String _buildPositionAwareLine(List<TextElementData> elements) {
    if (elements.length == 1) return elements.first.text;

    final gaps = <double>[];
    for (var i = 1; i < elements.length; i++) {
      gaps.add(elements[i].left - elements[i - 1].right);
    }

    final positiveGaps = gaps.where((gap) => gap > 0).toList();
    if (positiveGaps.isEmpty) {
      return elements.map((e) => e.text).join(' ');
    }

    positiveGaps.sort();
    final medianGap = positiveGaps[positiveGaps.length ~/ 2];
    final averageHeight =
        elements.fold<double>(0, (sum, e) => sum + e.height) / elements.length;

    final columnGap = [
      medianGap * 2.8,
      averageHeight * 1.2,
      14.0,
    ].reduce((a, b) => a > b ? a : b);

    final result = StringBuffer();
    for (var i = 0; i < elements.length; i++) {
      if (i > 0) {
        final gap = elements[i].left - elements[i - 1].right;
        result.write(gap >= columnGap ? ' | ' : ' ');
      }
      result.write(elements[i].text);
    }
    return result.toString().trim();
  }

  void _addLineToRow(List<OcrRow> rows, TextLineData line) {
    OcrRow? matched;
    for (final row in rows) {
      final distance = (line.centerY - row.centerY).abs();
      final tolerance = ((line.height + row.averageHeight) / 2) * 0.65;
      if (distance <= tolerance) {
        matched = row;
        break;
      }
    }
    if (matched != null) {
      matched.add(line);
    } else {
      rows.add(OcrRow(line));
    }
  }

  void dispose() {
    textRecognizer.close();
  }
}

/// Runs in a background isolate (via compute).
Uint8List _enhanceImage(String path) {
  final bytes = File(path).readAsBytesSync();
  var image = img.decodeImage(bytes);
  if (image == null) return bytes;

  image = img.bakeOrientation(image);

  // Small text needs enough pixels: bring the long side to ~2600px.
  final longSide = math.max(image.width, image.height);
  const target = 2600;
  if (longSide < target) {
    final scale = target / longSide;
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );
  } else if (longSide > 3600) {
    final scale = 3200 / longSide;
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }

  image = img.grayscale(image);
  image = img.normalize(image, min: 0, max: 255);
  image = img.adjustColor(image, contrast: 1.25);

  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

class _RawLine {
  final String text;
  final double top;
  final double bottom;
  final double left;
  final double right;

  _RawLine({
    required this.text,
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });
}

class TextElementData {
  final String text;
  final double top;
  final double bottom;
  final double left;
  final double right;

  TextElementData({
    required this.text,
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  double get height => bottom - top;
}

class TextLineData {
  final String text;
  final double top;
  final double bottom;
  final double left;
  final double right;

  TextLineData({
    required this.text,
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  double get height => bottom - top;

  double get centerY => (top + bottom) / 2;
}

class OcrRow {
  final List<TextLineData> lines = [];

  OcrRow(TextLineData firstLine) {
    lines.add(firstLine);
  }

  void add(TextLineData line) {
    lines.add(line);
  }

  double get centerY {
    if (lines.isEmpty) return 0;
    return lines.fold<double>(0, (sum, line) => sum + line.centerY) /
        lines.length;
  }

  double get averageHeight {
    if (lines.isEmpty) return 10;
    return lines.fold<double>(0, (sum, line) => sum + line.height) /
        lines.length;
  }
}
