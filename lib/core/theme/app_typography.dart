import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

// Fallback fonts bundled locally to cover characters (e.g. ₹) that the
// primary Google Fonts may not include, especially on Flutter Web.
const _fontFallbacks = ['NotoSans', 'NotoSansSymbols'];

class AppTypography {
  static TextStyle display = GoogleFonts.playfairDisplay(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    height: 1.2,
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle headingLarge = GoogleFonts.playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryText,
    height: 1.4,
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle headingMedium = GoogleFonts.playfairDisplay(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryText,
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle headingSmall = GoogleFonts.playfairDisplay(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryText,
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w300,
    color: AppColors.secondaryText,
    height: 1.6,
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.secondaryText,
    height: 1.6,
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.secondaryText,
    height: 1.5,
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: AppColors.primaryText,
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
    color: AppColors.mutedText,
  ).copyWith(fontFamilyFallback: _fontFallbacks);

  static TextStyle mono = GoogleFonts.spaceMono(
    fontSize: 12,
    color: AppColors.secondaryText,
  ).copyWith(fontFamilyFallback: _fontFallbacks);
}

