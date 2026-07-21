import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  static TextStyle display = GoogleFonts.playfairDisplay(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    height: 1.2,
  );
  
  static TextStyle headingLarge = GoogleFonts.playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryText,
    height: 1.4,
  );
  
  static TextStyle headingMedium = GoogleFonts.playfairDisplay(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryText,
  );
  
  static TextStyle headingSmall = GoogleFonts.playfairDisplay(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryText,
  );
  
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w300,
    color: AppColors.secondaryText,
    height: 1.6,
  );
  
  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.secondaryText,
    height: 1.6,
  );
  
  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.secondaryText,
    height: 1.5,
  );
  
  static TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: AppColors.primaryText,
  );
  
  static TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
    color: AppColors.mutedText,
  );
  
  static TextStyle mono = GoogleFonts.spaceMono(
    fontSize: 12,
    color: AppColors.secondaryText,
  );
}
