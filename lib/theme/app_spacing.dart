import 'package:flutter/material.dart';

/// Design tokens.
///
/// Every magic number that used to be sprinkled through the widget tree lives
/// here. Using a fixed scale (rather than arbitrary values) is what makes an
/// interface look deliberately designed instead of assembled.
class Insets {
  const Insets._();

  /// 4pt base scale.
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Standard horizontal page gutter.
  static const double gutter = 16;

  /// Bottom padding on scrollables so content clears the nav bar and FAB.
  static const double scrollBottom = 96;

  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: gutter);
  static const EdgeInsets pageTop = EdgeInsets.fromLTRB(gutter, sm, gutter, scrollBottom);
  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets cardTight = EdgeInsets.all(md);
  static const EdgeInsets sheet = EdgeInsets.fromLTRB(xl, sm, xl, xxl);
}

/// Corner radii. Larger surfaces get larger radii so curvature reads as
/// consistent across component sizes.
class Radii {
  const Radii._();

  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius field = BorderRadius.all(Radius.circular(md));
  static const BorderRadius button = BorderRadius.all(Radius.circular(md));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius sheet =
      BorderRadius.vertical(top: Radius.circular(xxl));
  static const BorderRadius stadium = BorderRadius.all(Radius.circular(pill));
}

/// Named durations so motion feels coherent rather than arbitrary.
class Motion {
  const Motion._();

  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 380);
  static const Duration chart = Duration(milliseconds: 620);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasis = Curves.easeOutBack;
}

/// Elevation as shadow recipes. Material 3 leans on tonal elevation, but a
/// small real shadow keeps cards legible against tinted surfaces.
class Shadows {
  const Shadows._();

  static List<BoxShadow> low(Brightness b) => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: b == Brightness.dark ? 0.34 : 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> medium(Brightness b) => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: b == Brightness.dark ? 0.42 : 0.08),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
}

/// Responsive breakpoints. The app is phone-first, but tablets and desktop web
/// should not render a 400pt-wide column in the middle of a 1200pt window.
class Breakpoints {
  const Breakpoints._();

  static const double phone = 600;
  static const double tablet = 905;
  static const double desktop = 1240;

  static bool isPhone(BuildContext c) =>
      MediaQuery.sizeOf(c).width < phone;
  static bool isTablet(BuildContext c) {
    final double w = MediaQuery.sizeOf(c).width;
    return w >= phone && w < desktop;
  }

  static bool isDesktop(BuildContext c) =>
      MediaQuery.sizeOf(c).width >= desktop;

  /// Column count for metric grids at the current width.
  static int metricColumns(BuildContext c) {
    final double w = MediaQuery.sizeOf(c).width;
    if (w >= desktop) return 4;
    if (w >= phone) return 3;
    return 2;
  }

  /// Caps content width on large screens so line length stays readable.
  static double contentMaxWidth(BuildContext c) =>
      isDesktop(c) ? 1100 : double.infinity;
}
