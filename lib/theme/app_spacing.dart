import 'package:flutter/material.dart';

/// Consistent spacing system following 8px grid
class AppSpacing {
  // Base spacing unit (8px)
  static const double base = 8.0;

  // Spacing scale
  static const double xs = base * 0.5; // 4px
  static const double sm = base; // 8px
  static const double md = base * 2; // 16px
  static const double lg = base * 3; // 24px
  static const double xl = base * 4; // 32px
  static const double xxl = base * 6; // 48px
  static const double xxxl = base * 8; // 64px

  // Padding shortcuts
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingSM = EdgeInsets.all(sm);
  static const EdgeInsets paddingMD = EdgeInsets.all(md);
  static const EdgeInsets paddingLG = EdgeInsets.all(lg);
  static const EdgeInsets paddingXL = EdgeInsets.all(xl);

  // Horizontal padding
  static const EdgeInsets paddingHorizontalXS =
      EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets paddingHorizontalSM =
      EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets paddingHorizontalMD =
      EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHorizontalLG =
      EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets paddingHorizontalXL =
      EdgeInsets.symmetric(horizontal: xl);

  // Vertical padding
  static const EdgeInsets paddingVerticalXS =
      EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets paddingVerticalSM =
      EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets paddingVerticalMD =
      EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets paddingVerticalLG =
      EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets paddingVerticalXL =
      EdgeInsets.symmetric(vertical: xl);

  // SizedBox shortcuts
  static const SizedBox gapXS = SizedBox(width: xs, height: xs);
  static const SizedBox gapSM = SizedBox(width: sm, height: sm);
  static const SizedBox gapMD = SizedBox(width: md, height: md);
  static const SizedBox gapLG = SizedBox(width: lg, height: lg);
  static const SizedBox gapXL = SizedBox(width: xl, height: xl);

  // Horizontal gaps
  static const SizedBox gapHorizontalXS = SizedBox(width: xs);
  static const SizedBox gapHorizontalSM = SizedBox(width: sm);
  static const SizedBox gapHorizontalMD = SizedBox(width: md);
  static const SizedBox gapHorizontalLG = SizedBox(width: lg);
  static const SizedBox gapHorizontalXL = SizedBox(width: xl);

  // Vertical gaps
  static const SizedBox gapVerticalXS = SizedBox(height: xs);
  static const SizedBox gapVerticalSM = SizedBox(height: sm);
  static const SizedBox gapVerticalMD = SizedBox(height: md);
  static const SizedBox gapVerticalLG = SizedBox(height: lg);
  static const SizedBox gapVerticalXL = SizedBox(height: xl);

  // Border radius
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 24.0;

  // BorderRadius shortcuts
  static const BorderRadius borderRadiusXS =
      BorderRadius.all(Radius.circular(radiusXS));
  static const BorderRadius borderRadiusSM =
      BorderRadius.all(Radius.circular(radiusSM));
  static const BorderRadius borderRadiusMD =
      BorderRadius.all(Radius.circular(radiusMD));
  static const BorderRadius borderRadiusLG =
      BorderRadius.all(Radius.circular(radiusLG));
  static const BorderRadius borderRadiusXL =
      BorderRadius.all(Radius.circular(radiusXL));
  static const BorderRadius borderRadiusXXL =
      BorderRadius.all(Radius.circular(radiusXXL));
}

/// Elevation system following Material Design 3
class AppElevation {
  // Elevation levels
  static const double level0 = 0.0;
  static const double level1 = 1.0;
  static const double level2 = 3.0;
  static const double level3 = 6.0;
  static const double level4 = 8.0;
  static const double level5 = 12.0;

  // Shadow colors
  static const Color shadowColor = Color(0x1F000000);
  static const Color surfaceTintColor = Color(0x00000000);

  // BoxShadow presets
  static const List<BoxShadow> shadow1 = [
    BoxShadow(
      color: shadowColor,
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> shadow2 = [
    BoxShadow(
      color: shadowColor,
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 2,
    ),
  ];

  static const List<BoxShadow> shadow3 = [
    BoxShadow(
      color: shadowColor,
      offset: Offset(0, 1),
      blurRadius: 3,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 3,
    ),
  ];

  static const List<BoxShadow> shadow4 = [
    BoxShadow(
      color: shadowColor,
      offset: Offset(0, 2),
      blurRadius: 3,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 6),
      blurRadius: 10,
      spreadRadius: 4,
    ),
  ];

  static const List<BoxShadow> shadow5 = [
    BoxShadow(
      color: shadowColor,
      offset: Offset(0, 4),
      blurRadius: 4,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 8),
      blurRadius: 12,
      spreadRadius: 6,
    ),
  ];
}
