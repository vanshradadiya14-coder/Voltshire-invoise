import 'package:flutter/material.dart';

/// Brand palette. The seed drives the Material 3 colour scheme; the status
/// colours are used for chips (job status, invoice status, etc.).
class AppColors {
  const AppColors._();

  /// Primary brand seed — a professional builder's blue matching the logo.
  static const Color seed = Color(0xFF2A5BD7);

  // Semantic status colours (tuned to read well in both light & dark).
  static const Color success = Color(0xFF2E9E5B);
  static const Color warning = Color(0xFFE0A106);
  static const Color danger = Color(0xFFD64545);
  static const Color info = Color(0xFF2A7DE1);
  static const Color neutral = Color(0xFF6B7280);

  // Invoice / payment status colours.
  static const Color paid = success;
  static const Color partiallyPaid = warning;
  static const Color unpaid = danger;
  static const Color draft = neutral;
  static const Color overdue = Color(0xFFB3261E);
}
