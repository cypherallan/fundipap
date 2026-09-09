import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FundipapColors {
  static const primaryYellow = Color(0xFFFFC107);
  static const blackGray = Color(0xFF121212);
  static const greenSuccess = Color(0xFF4CAF50);
  static const redAlert = Color(0xFFF44336);
  static const bgLight = Color(0xFFFBF8F0);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      scaffoldBackgroundColor: FundipapColors.bgLight,
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: FundipapColors.primaryYellow,
        secondary: FundipapColors.blackGray,
        error: FundipapColors.redAlert,
      ),
    );
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          color: FundipapColors.blackGray,
        ),
        titleLarge: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          color: FundipapColors.blackGray,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FundipapColors.blackGray,
          foregroundColor: FundipapColors.primaryYellow,
          textStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  static const primary = FundipapColors.primaryYellow;
}
