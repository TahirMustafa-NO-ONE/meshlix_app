import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF141414);
  static const Color surfaceVariant = Color(0xFF1A1A1A);
  static const Color inputFill = Color(0xFF1E1E1E);

  // Accents
  static const Color primaryAccent = Color(0xFFC8E000);
  static const Color secondaryAccent = Color(0xFF8AAA00);
  static const Color darkAccent = Color(0xFF3D5200);
  static const Color accentGlow = Color(0x44C8E000);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textHint = Color(0xFF666666);

  // Borders
  static const Color border = Color(0xFF333333);
  static const Color borderAccent = Color(0xFFC8E000);

  // Semantic
  static const Color error = Color(0xFFFF4444);
  static const Color success = Color(0xFF00C853);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryAccent, secondaryAccent],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
