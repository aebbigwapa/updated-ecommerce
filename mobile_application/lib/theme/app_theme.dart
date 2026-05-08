import 'package:flutter/material.dart';

class AppTheme {
  // Colors matching web app CSS variables
  static const Color primaryLight = Color(0xFFFF2BAC);
  static const Color primaryMid = Color(0xFFFF6BCE);
  static const Color primaryDark = Color(0xFFFF9ED6);
  static const Color accentBeige = Color(0xFFF5E6D3);
  static const Color textDark = Color(0xFF2D3748);
  static const Color textLight = Color(0xFF718096);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grayLight = Color(0xFFF7FAFC);
  static const Color gray = Color(0xFFE2E8F0);
  static const Color border = Color(0xFFCBD5E0);
  static const Color success = Color(0xFF48BB78);
  static const Color warning = Color(0xFFED8936);
  static const Color error = Color(0xFFF56565);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryLight, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Typography
  static const String fontDisplay = 'Playfair Display';
  static const String fontBody = 'Inter';

  // Spacing
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // Border radius
  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;

  // Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Color(0x05000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> pinkGlow = [
    BoxShadow(
      color: Color(0x40FF2BAC),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  // Theme data
  static ThemeData get theme {
    return ThemeData(
      primarySwatch: Colors.pink,
      primaryColor: primaryLight,
      fontFamily: fontBody,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: fontDisplay,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        displayMedium: TextStyle(
          fontFamily: fontDisplay,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        displaySmall: TextStyle(
          fontFamily: fontDisplay,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        headlineLarge: TextStyle(
          fontFamily: fontDisplay,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        headlineMedium: TextStyle(
          fontFamily: fontBody,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        headlineSmall: TextStyle(
          fontFamily: fontBody,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        bodyLarge: TextStyle(
          fontFamily: fontBody,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textDark,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontBody,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textDark,
        ),
        bodySmall: TextStyle(
          fontFamily: fontBody,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textLight,
        ),
        labelLarge: TextStyle(
          fontFamily: fontBody,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: white,
        ),
        labelMedium: TextStyle(
          fontFamily: fontBody,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textLight,
        ),
        labelSmall: TextStyle(
          fontFamily: fontBody,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textLight,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: lg, vertical: md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontFamily: fontBody,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: grayLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: md, vertical: md),
        labelStyle: const TextStyle(
          fontFamily: fontBody,
          fontSize: 14,
          color: textLight,
        ),
        hintStyle: const TextStyle(
          fontFamily: fontBody,
          fontSize: 14,
          color: textLight,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        color: white,
        shadowColor: Colors.black.withValues(alpha: 0.1),
      ),
    );
  }
}
