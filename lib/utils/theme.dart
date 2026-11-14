import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF1B1F2A);
  static const teal = Color(0xFF0E6B63);
  static const tealDark = Color(0xFF083F3B);
  static const marigold = Color(0xFFF2A93B);
  static const rose = Color(0xFFD6456B);
  static const bg = Color(0xFFF4F6F7);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE3E7EA);
}

const String kAppName = 'Book Haven By Muhammad Usman';
const String kTagline = 'Every Great Read, One Tap Away';

const List<String> kSerif = ['Georgia', 'Times New Roman', 'serif'];
const List<String> kGenres = ['Programming', 'Fiction', 'Self-Help', 'Business', 'Non-Fiction'];
const List<String> kOrderStatuses = ['Pending', 'Shipped', 'Delivered', 'Cancelled'];
const double kFreeDeliveryAbove = 3000;
const double kDeliveryFee = 200;

double asDouble(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
int asInt(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);

Color tint(Color c, double opacity) => c.withAlpha((opacity * 255).round());

/// 1850 -> "Rs. 1,850"
String rs(num v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return 'Rs. $buf';
}

TextStyle serif(double size,
        {FontWeight weight = FontWeight.w700, Color color = AppColors.ink, double height = 1.2}) =>
    TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        fontFamilyFallback: kSerif);

Color statusColor(String status) {
  switch (status) {
    case 'Delivered':
      return const Color(0xFF2E8B57);
    case 'Shipped':
      return const Color(0xFF2F6F9E);
    case 'Cancelled':
      return AppColors.rose;
    default:
      return const Color(0xFFD98A12);
  }
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.teal).copyWith(
    primary: AppColors.teal,
    onPrimary: Colors.white,
    secondary: AppColors.marigold,
    surface: Colors.white,
    error: AppColors.rose,
  );
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamilyFallback: kSerif),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.teal, 1.6),
      errorBorder: border(AppColors.rose),
      focusedErrorBorder: border(AppColors.rose, 1.6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(88, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(88, 48),
        foregroundColor: AppColors.teal,
        side: const BorderSide(color: AppColors.teal),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppColors.teal,
      side: BorderSide(color: AppColors.line),
      shape: StadiumBorder(),
      showCheckmark: false,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
