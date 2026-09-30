import 'package:flutter/widgets.dart';

/// Single source of truth for every colour in the app.
/// Use `ColorConstants.xxx` - never `Color(0x...)` or `Colors.xxx` in a screen.
class ColorConstants {
  ColorConstants._();

  // ---- Brand
  static const Color primary = Color(0xFF4038D8);
  static const Color unBlockButtonColor = Color(0xFFD22A79);
  static const Color buttonColor = Color(0xFFD42A7A);
  static const Color secondary = Color(0xFF6E163F);
  static const Color primaryDark = Color(0xFF2C2AC0);
  static const Color primaryLight = Color(0xFF6C63FF);
  static const Color primaryDeep = Color(0xFF211F8C);
  static const Color primaryBright = Color(0xFF3F3DF0);
  static const Color accent = Color(0xFF7B79FF);
  static const Color primarySoft = Color(0xFFEDEDFF);
  static const Color primaryTint = Color(0xFFF3F2FF);
  static const Color primaryMist = Color(0xFFEEF0FF);
  static const Color primaryPale = Color(0xFFEDECFB);
  static const Color primaryDisabled = Color(0xFFB8B6E8);
  static const Color indigo = Color(0xFF4F46E5);
  static const Color indigoDark = Color(0xFF4338CA);
  static const Color indigoLight = Color(0xFF7C74F0);
  static const Color authPrimary = Color(0xFF5146F5);
  static const Color authPrimaryDark = Color(0xFF3E35D6);
  static const Color authPrimaryLight = Color(0xFF7A70FF);
  static const Color navBackground = Color(0xFF2523A8);
  static const Color navInactive = Color(0xFFB8BED3);
  static const Color blue = Color(0xFF2456D6);
  static const Color blueSoft = Color(0xFF3A6FD8);
  static const Color primaryAlpha20 = Color(0x333038D8);

  // ---- Backgrounds / surfaces
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color background = Color(0xFFF5F7FB);
  static const Color backgroundAlt = Color(0xFFF6F7FB);
  static const Color backgroundHome = Color(0xFFF4F5FA);
  static const Color backgroundSoft = Color(0xFFF7F7FB);
  static const Color surfaceAlt = Color(0xFFF8F9FC);
  static const Color fieldFill = Color(0xFFF8F9FD);
  static const Color authBackground = Color(0xFFF6F6FC);
  static const Color grayFill = Color(0xFFF9FAFB);
  static const Color grayBackground = Color(0xFFF3F4F6);
  static const Color surfaceWhite = Color(0xFFFDFDFF);
  static const Color surfaceGray = Color(0xFFF1F2F6);
  static const Color surfaceGray2 = Color(0xFFF0F0F5);
  static const Color surfaceGray3 = Color(0xFFF0F0F0);
  static const Color surfaceMuted = Color(0xFFEEEFF5);

  // ---- Text
  static const Color textField = Color(0xFF8A8888);
  static const Color textDark = Color(0xFF1A1B25);
  static const Color textMuted = Color(0xFF8B8D98);
  static const Color authText = Color(0xFF25254A);
  static const Color authHint = Color(0xFF9696A8);
  static const Color gray900 = Color(0xFF111827);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color textDark2 = Color(0xFF1D1E2C);
  static const Color textMuted2 = Color(0xFF8C8FA3);
  static const Color textDark3 = Color(0xFF1C1C28);
  static const Color textMuted3 = Color(0xFF7A7A8C);
  static const Color textDark4 = Color(0xFF1C1C1F);
  static const Color ink = Color(0xFF1A1A1A);
  static const Color inkDeep = Color(0xFF13122B);
  static const Color inkMuted = Color(0xFF6B6A85);
  static const Color inkMutedSoft = Color(0xFF9C9BB4);
  static const Color hint = Color(0xFF9B9BAB);
  static const Color hint2 = Color(0xFF9999A8);
  static const Color mutedGrey = Color(0xFF9A9A9A);
  static const Color grey44 = Color(0xFF444444);
  static const Color grey22 = Color(0xFF222222);
  static const Color grey66 = Color(0xFF666666);

  // ---- Borders / dividers
  static const Color border = Color(0xFFE2E2EA);
  static const Color divider = Color(0xFFE7E8F2);
  static const Color border2 = Color(0xFFDBDCE8);
  static const Color border3 = Color(0xFFE7E7EE);
  static const Color border4 = Color(0xFFEDEDF4);
  static const Color border5 = Color(0xFFEAEAF3);
  static const Color grayBorder = Color(0xFFD1D5DB);
  static const Color border6 = Color(0xFFBFC5D6);

  // ---- Status
  static const Color warning = Color(0xFFF29D1F);
  static const Color warning2 = Color(0xFFE59A1F);
  static const Color warning3 = Color(0xFFE08A00);
  static const Color danger = Color(0xFFE0473E);
  static const Color danger2 = Color(0xFFE5484D);
  static const Color danger3 = Color(0xFFD64545);
  static const Color red600 = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static const Color success2 = Color(0xFF15803D);
  static const Color success3 = Color(0xFF2E9E5B);
  static const Color success4 = Color(0xFF2E7D32);
  static const Color success5 = Color(0xFF1D8234);
  static const Color teal = Color(0xFF00A389);
  static const Color successSoft = Color(0xFFEAFBF1);

  // ---- Shadows
  static const Color shadow08 = Color(0x14000000);
  static const Color shadow06 = Color(0x0F000000);
  static const Color shadow20 = Color(0x33000000);
  static const Color shadow13 = Color(0x22000000);
  static const Color shadow06b = Color(0x10000000);
  static const Color shadow05 = Color(0x0D000000);
  static const Color shadowInk04 = Color(0x0A13122B);

  // ---- Material equivalents (same values as Flutter's Colors.*)
  static const Color transparent = Color(0x00000000);
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color white30 = Color(0x4DFFFFFF);
  static const Color white24 = Color(0x3DFFFFFF);
  static const Color black54 = Color(0x8A000000);
  static const Color black38 = Color(0x61000000);
  static const Color redAccent = Color(0xFFFF5252);
  static const Color red = Color(0xFFF44336);
  static const Color green = Color(0xFF4CAF50);
  static const Color materialBlue = Color(0xFF2196F3);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
}
