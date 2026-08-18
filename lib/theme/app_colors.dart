import 'package:flutter/material.dart';

/// Brand palette.
///
/// The seed and accent are sampled directly from the app icon so the product
/// UI, the launcher icon and generated PDFs all read as the same brand.
/// Status colours are defined as light/dark pairs because a single hue that
/// passes contrast on white will usually fail on a dark surface.
class AppColors {
  const AppColors._();

  // ---- Brand ----------------------------------------------------------

  /// Primary brand blue — the house mark in the app icon.
  static const Color seed = Color(0xFF1A4FD1);

  /// Accent amber — the checklist ticks in the app icon. Used for highlights
  /// and the Pro badge, never for primary actions (it fails contrast as a
  /// button fill with white text).
  static const Color accent = Color(0xFFFEB40B);

  /// Deep brand navy, used for hero surfaces and the dashboard header.
  static const Color brandDark = Color(0xFF0E2E7D);

  // ---- Semantic status ------------------------------------------------
  // Each pair is tuned so the light variant passes 4.5:1 on a white surface
  // and the dark variant passes 4.5:1 on the M3 dark surface.

  static const Color successLight = Color(0xFF1B7F45);
  static const Color successDark = Color(0xFF52D08A);

  static const Color warningLight = Color(0xFFA9700A);
  static const Color warningDark = Color(0xFFF0B429);

  static const Color dangerLight = Color(0xFFC0342F);
  static const Color dangerDark = Color(0xFFFF8A83);

  static const Color infoLight = Color(0xFF1A66C2);
  static const Color infoDark = Color(0xFF7FB4F5);

  static const Color neutralLight = Color(0xFF5C6470);
  static const Color neutralDark = Color(0xFFA5AEBB);

  // ---- Backwards-compatible flat aliases -------------------------------
  // Existing code (enums.dart, screens) reads these directly. They resolve to
  // the light variants; prefer AppColors.of(context) in new code.

  static const Color success = successLight;
  static const Color warning = warningLight;
  static const Color danger = dangerLight;
  static const Color info = infoLight;
  static const Color neutral = neutralLight;

  static const Color paid = successLight;
  static const Color partiallyPaid = warningLight;
  static const Color unpaid = dangerLight;
  static const Color draft = neutralLight;
  static const Color overdue = Color(0xFF9B2620);

  // ---- Chart series ----------------------------------------------------
  // A qualitative ramp that stays distinguishable in both themes and for the
  // most common forms of colour-vision deficiency (no red/green adjacency).

  static const List<Color> chartSeries = <Color>[
    Color(0xFF1A4FD1), // brand blue
    Color(0xFFFEB40B), // amber
    Color(0xFF12A594), // teal
    Color(0xFF8B5CF6), // violet
    Color(0xFFEF6C3E), // coral
    Color(0xFF3E8EDE), // sky
    Color(0xFFB0407A), // magenta
    Color(0xFF6B8E23), // olive
  ];

  // ---- Signature Gradients ---------------------------------------------

  /// Electric Sapphire brand gradient for hero headers and prominent CTAs
  static const LinearGradient primaryGradient = LinearGradient(
    colors: <Color>[Color(0xFF1D55E3), Color(0xFF0C2B78)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Radiant Amber gradient for badges, highlighted metrics and pro accents
  static const LinearGradient accentGradient = LinearGradient(
    colors: <Color>[Color(0xFFFBBF24), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Emerald Success gradient for paid invoices and positive growth
  static const LinearGradient successGradient = LinearGradient(
    colors: <Color>[Color(0xFF10B981), Color(0xFF047857)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Crimson Alert gradient for urgent/overdue highlights
  static const LinearGradient dangerGradient = LinearGradient(
    colors: <Color>[Color(0xFFF87171), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Sleek dark hero card gradient
  static const LinearGradient darkHeroGradient = LinearGradient(
    colors: <Color>[Color(0xFF111827), Color(0xFF0F172A), Color(0xFF030712)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Series colour by index, wrapping if there are more slices than colours.
  static Color series(int index) =>
      chartSeries[index % chartSeries.length];

  /// Brightness-aware accessor for the semantic colours.
  static AppStatusColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const AppStatusColors.dark()
          : const AppStatusColors.light();
}

/// Brightness-resolved semantic colours.
///
/// Read these via `AppColors.of(context)` so a status chip that is legible in
/// light mode stays legible in dark mode.
class AppStatusColors {
  const AppStatusColors.light()
      : success = AppColors.successLight,
        warning = AppColors.warningLight,
        danger = AppColors.dangerLight,
        info = AppColors.infoLight,
        neutral = AppColors.neutralLight,
        accent = const Color(0xFFB07C05),
        isDark = false;

  const AppStatusColors.dark()
      : success = AppColors.successDark,
        warning = AppColors.warningDark,
        danger = AppColors.dangerDark,
        info = AppColors.infoDark,
        neutral = AppColors.neutralDark,
        accent = AppColors.accent,
        isDark = true;

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color neutral;
  final Color accent;
  final bool isDark;

  /// Resolves a flat design-time colour (from `enums.dart`) to the variant
  /// appropriate for the current brightness.
  Color resolve(Color flat) {
    if (!isDark) return flat;
    return switch (flat.toARGB32()) {
      0xFF1B7F45 => success,
      0xFFA9700A => warning,
      0xFFC0342F => danger,
      0xFF1A66C2 => info,
      0xFF5C6470 => neutral,
      0xFF9B2620 => AppColors.dangerDark,
      0xFF1A4FD1 => const Color(0xFF9DBBFF),
      _ => flat,
    };
  }

  /// A low-emphasis fill for the given status colour — used by chips and the
  /// icon plates on metric tiles.
  Color container(Color base) => base.withValues(alpha: isDark ? 0.22 : 0.12);
}
