import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle title = GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle cardTitle = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle body = GoogleFonts.poppins(
    fontSize: 11,
    color: AppColors.textSecondary,
  );

  static TextStyle metric = GoogleFonts.poppins(
    fontSize: 32,
    color: AppColors.white,
    fontWeight: FontWeight.w400,
  );
  
  static TextStyle small = GoogleFonts.poppins(
    fontSize: 9,
    color: AppColors.textSecondary,
  );
}
