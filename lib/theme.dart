import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand colours that stay constant across light / dark, ported verbatim from
/// the original design tokens.
class Brand {
  static const accent = Color(0xFFE0533D); // primary orange-red
  static const green = Color(0xFF1F8A5B); // income / positive
  static const greenDot = Color(0xFF34C77B);

  // Soft "tinted" chip palette (literal in both themes in the source design).
  static const tintBg = Color(0xFFFBEAE6);
  static const tintBorder = Color(0xFFF3D6CF);
  static const tintInk = Color(0xFF9A2E1C);
  static const tintSub = Color(0xFFB96452);
  static const greenTintBg = Color(0xFFEAF5EE);
  static const greenInk = Color(0xFF1F6B49);
}

/// Resolves the CSS custom-property tokens (`--bg`, `--card`, …) for the
/// current brightness.
class AppColors {
  final bool dark;
  const AppColors(this.dark);

  Color get bg => dark ? const Color(0xFF14141A) : const Color(0xFFFAFAF8);
  Color get card => dark ? const Color(0xFF1E1E25) : const Color(0xFFFFFFFF);
  Color get ink => dark ? const Color(0xFFF1F1EE) : const Color(0xFF1A1A17);
  Color get ink2 => dark ? const Color(0xFF8C8C95) : const Color(0xFF9A9A92);
  Color get line => dark ? const Color(0xFF2C2C34) : const Color(0xFFECECE6);
  Color get line2 => dark ? const Color(0xFF26262D) : const Color(0xFFF4F4EF);
  Color get field => dark ? const Color(0xFF26262D) : const Color(0xFFFAFAF8);
  Color get hero => dark ? const Color(0xFF000000) : const Color(0xFF1A1A17);
  Color get heroSub => dark ? const Color(0xFF26262D) : const Color(0xFF272722);
  Color get key => dark ? const Color(0xFF26262D) : const Color(0xFFF5F5F0);

  static AppColors of(BuildContext context) =>
      AppColors(Theme.of(context).brightness == Brightness.dark);
}

/// Lightens the design's heavy weights so the UI reads cleaner. The original
/// uses w800/w700 almost everywhere; this caps emphasis at semibold (w600) and
/// drops body text to medium/regular. Centralised so the whole app lightens
/// without touching every call site.
final _soften = <FontWeight, FontWeight>{
  FontWeight.w900: FontWeight.w600,
  FontWeight.w800: FontWeight.w500,
  FontWeight.w700: FontWeight.w600,
  FontWeight.w600: FontWeight.w500,
  FontWeight.w500: FontWeight.w400,
};

/// A few shared text styles built on Manrope.
TextStyle manrope({
  double size = 14,
  FontWeight weight = FontWeight.w600,
  Color? color,
  double? letterSpacing,
  double? height,
}) =>
    GoogleFonts.manrope(
      fontSize: size,
      fontWeight: _soften[weight] ?? weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );

ThemeData buildTheme(bool dark) {
  final c = AppColors(dark);
  final base = dark ? ThemeData.dark() : ThemeData.light();
  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: c.ink,
      displayColor: c.ink,
    ),
    colorScheme: base.colorScheme.copyWith(
      primary: Brand.accent,
      surface: c.card,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    // Floating snackbars sit above the docked FAB instead of pushing it up.
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
