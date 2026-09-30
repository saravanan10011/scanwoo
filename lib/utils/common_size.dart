import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// ```
class Sizes {
  Sizes._();

  static const double _designWidth = 375;
  static const double _designHeight = 812;

  /// Full screen width / height (GetX, no BuildContext needed).
  static double get screenWidth => Get.width;
  static double get screenHeight => Get.height;

  /// Status bar / bottom inset. Falls back to 0 before the first frame.
  static double get topInset => Get.mediaQuery.padding.top;
  static double get bottomInset => Get.mediaQuery.padding.bottom;

  /// Scale a design-width pixel value to this screen's width.
  static double w(double px) => screenWidth * (px / _designWidth);

  /// Scale a design-height pixel value to this screen's height.
  static double h(double px) => screenHeight * (px / _designHeight);

  /// Font / icon size: scales with width but is clamped so text never gets
  /// tiny on small phones or huge on tablets.
  static double sp(double px) => w(px).clamp(px * 0.85, px * 1.25).toDouble();

  static double get scale => (screenWidth / _designWidth).clamp(0.9, 1.25);
  static double s(double px) => px * scale;

  /// Fraction of screen width / height, e.g. `Sizes.hp(0.02)` = 2%.
  static double wp(double fraction) => screenWidth * fraction;
  static double hp(double fraction) => screenHeight * fraction;

  /// Spacer widgets.
  static Widget gapH(double px) => SizedBox(height: h(px));
  static Widget gapW(double px) => SizedBox(width: w(px));
}
