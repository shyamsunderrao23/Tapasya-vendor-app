import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Premium Color Palette
  static const Color primaryColor = Color(0xFF6A0DAD); // Deep Purple
  static const Color secondaryColor = Color(0xFF9D50BB); // Lighter Purple (Gradient)
  static const Color accentColor = Color(0xFFFFD700); // Gold/Yellow for alerts/ratings
  
  static const Color scaffoldBG = Color(0xFFFFFFFF); // Pure White
  static const Color whiteColor = Color(0xFFFFFFFF);
  static const Color blackColor = Color(0xFF1A1A1A); // Softer black
  static const Color greyColor = Color(0xFF909090);
  static const Color lightGreyColor = Color(0xFFF0F0F0);
  
  static const Color successColor = Color(0xFF00C853);
  static const Color errorColor = Color(0xFFFF3D00);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Colors.white, Color(0xFFFAFAFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadows
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 5),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF6A0DAD).withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // Typography
  static TextStyle get headingStyle => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: blackColor,
        letterSpacing: -0.5,
      );

  static TextStyle get subHeadingStyle => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: blackColor,
        letterSpacing: 0,
      );

  static TextStyle get bodyStyle => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFF4A4A4A),
        height: 1.5,
      );

  static TextStyle get labelStyle => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: greyColor,
      );

  static TextStyle get buttonTextStyle => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: whiteColor,
      );

  // Theme Data
  static ThemeData get lightTheme => ThemeData(
        scaffoldBackgroundColor: scaffoldBG,
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: secondaryColor,
          background: scaffoldBG,
        ),
        useMaterial3: true,
        fontFamily: GoogleFonts.poppins().fontFamily,
        
        appBarTheme: const AppBarTheme(
          backgroundColor: scaffoldBG,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: blackColor),
          titleTextStyle: TextStyle(
            color: blackColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'Poppins',
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: whiteColor,
            elevation: 8,
            shadowColor: primaryColor.withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            textStyle: buttonTextStyle,
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: whiteColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryColor, width: 2),
            // Removed shadow here as Input doesn't support generic shadows easily, handled in widget
          ),
          contentPadding: const EdgeInsets.all(20),
          hintStyle: labelStyle,
        ),
      );
}
