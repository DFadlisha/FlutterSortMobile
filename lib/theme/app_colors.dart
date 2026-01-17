import 'package:flutter/material.dart';

class AppColors {
  // Logo Colors
  static const Color primaryPurple = Color(0xFF7B61FF);
  static const Color midnightBlue = Color(0xFF131131);
  
  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF131131);
  static const Color darkSurface = Color(0xFF1C1A45);
  static const Color darkCard = Color(0xFF2D3561);
  static const Color darkAccent = Color(0xFF6344FF);
  
  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF5F5F7);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Color(0xFFEBEBF5);
  
  // Chart Colors
  static const List<Color> chartGradients = [
    primaryPurple,
    darkAccent,
  ];
}
