import 'package:flutter/material.dart';

/// Design tokens for consistent spacing, sizing, and layout throughout the app
/// Following Material Design 3 guidelines and the UI/UX review recommendations
class AppSpacing {
  // Spacing scale based on 4dp grid
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  // Common padding combinations
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingSM = EdgeInsets.all(sm);
  static const EdgeInsets paddingMD = EdgeInsets.all(md);
  static const EdgeInsets paddingLG = EdgeInsets.all(lg);
  static const EdgeInsets paddingXL = EdgeInsets.all(xl);

  // Card and container spacing
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets screenPadding = EdgeInsets.all(lg);
  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(vertical: lg, horizontal: lg);
}

/// Touch target sizes following accessibility guidelines
class AppSizing {
  // Minimum touch targets (accessibility compliant)
  static const double touchTargetMin = 48.0;
  static const double touchTargetComfortable = 56.0;

  // Icon sizes
  static const double iconXS = 16.0;
  static const double iconSM = 20.0;
  static const double iconMD = 24.0;
  static const double iconLG = 32.0;
  static const double iconXL = 48.0;

  // Border radius
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 20.0;

  // Button heights
  static const double buttonHeightSM = 32.0;
  static const double buttonHeightMD = 40.0;
  static const double buttonHeightLG = 48.0;
  static const double buttonHeightXL = 56.0;
}

/// Typography scale following Material Design 3
class AppTypography {
  // Font weights
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // Font sizes
  static const double fontSizeXS = 10.0;
  static const double fontSizeSM = 12.0;
  static const double fontSizeMD = 14.0;
  static const double fontSizeLG = 16.0;
  static const double fontSizeXL = 18.0;
  static const double fontSizeXXL = 20.0;
  static const double fontSizeXXXL = 24.0;

  // Text styles
  static const TextStyle caption = TextStyle(
    fontSize: fontSizeXS,
    fontWeight: regular,
  );

  static const TextStyle body2 = TextStyle(
    fontSize: fontSizeSM,
    fontWeight: regular,
  );

  static const TextStyle body1 = TextStyle(
    fontSize: fontSizeMD,
    fontWeight: regular,
  );

  static const TextStyle subtitle2 = TextStyle(
    fontSize: fontSizeLG,
    fontWeight: medium,
  );

  static const TextStyle subtitle1 = TextStyle(
    fontSize: fontSizeXL,
    fontWeight: medium,
  );

  static const TextStyle headline6 = TextStyle(
    fontSize: fontSizeXXL,
    fontWeight: semiBold,
  );

  static const TextStyle headline5 = TextStyle(
    fontSize: fontSizeXXXL,
    fontWeight: semiBold,
  );
}

/// Animation durations and curves
class AppAnimations {
  // Durations
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  // Curves
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve bounceIn = Curves.bounceIn;
}

/// Elevation levels for shadows and surfaces
class AppElevation {
  static const double none = 0.0;
  static const double low = 1.0;
  static const double medium = 4.0;
  static const double high = 8.0;
  static const double veryHigh = 16.0;
}

/// Breakpoints for responsive design
class AppBreakpoints {
  static const double mobile = 600.0;
  static const double tablet = 900.0;
  static const double desktop = 1200.0;

  /// Check if current width is mobile
  static bool isMobile(double width) => width < mobile;

  /// Check if current width is tablet
  static bool isTablet(double width) => width >= mobile && width < desktop;

  /// Check if current width is desktop
  static bool isDesktop(double width) => width >= desktop;
}

/// Extension to easily access screen size categories
extension ScreenSizeExtension on BuildContext {
  bool get isMobile => AppBreakpoints.isMobile(MediaQuery.of(this).size.width);
  bool get isTablet => AppBreakpoints.isTablet(MediaQuery.of(this).size.width);
  bool get isDesktop => AppBreakpoints.isDesktop(MediaQuery.of(this).size.width);
}