import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Classic white theme color scheme
  static const Color primaryBlue = Color(0xFF3B82F6);      
  static const Color lightBlue = Color(0xFFE6F0FF);        
  static const Color darkBlue = Color(0xFF1E3A8A);        
  static const Color nearBlack = Color(0xFF0F172A);        
  static const Color darkGray = Color(0xFF1F2937);        
  static const Color mediumGray = Color(0xFF6B7280);      
  static const Color lightGray = Color(0xFFF9FAFB);       
  static const Color borderGray = Color(0xFFE5E7EB);       
  static const Color surfaceWhite = Color(0xFFFFFFFF);    
  static const Color surfaceDark = Color(0xFFF8FAFC);    
  static const Color surfaceCard = Color(0xFFFFFFFF);    
  static const Color successGreen = Color(0xFF10B981);    
  static const Color warningOrange = Color(0xFFF59E0B);    
  static const Color errorRed = Color(0xFFEF4444);    

  static ThemeData get lightTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: surfaceWhite,
        textTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: darkGray,
          displayColor: darkGray,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: surfaceWhite,
          foregroundColor: darkGray,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: surfaceCard,
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: surfaceWhite,
            elevation: 2,
            shadowColor: primaryBlue.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
} 