import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const electricBlue = Color(0xFF2E9BFF);
  static const skyBlue = Color(0xFF4FC3F7);
  static const deepPurple = Color(0xFF7B2FF7);
  static const indigo = Color(0xFF3B4DF0);
  static const surfaceLight = Color(0xFFF7F8FC);
  static const surfaceDark = Color(0xFF0E0F1A);

  static const brandGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [skyBlue, electricBlue, indigo, deepPurple],
  );
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.surfaceLight,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.electricBlue,
          secondary: AppColors.deepPurple,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.surfaceDark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.electricBlue,
          secondary: AppColors.deepPurple,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      );
}
