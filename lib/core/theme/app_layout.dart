import 'package:flutter/material.dart';

class AppLayout {
  // Breakpoints
  static const double mobileMaxWidth = 600.0;
  static const double tabletMaxWidth = 900.0;
  static const double desktopMaxWidth = 1150.0;

  // Responsive Helpers
  static bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < mobileMaxWidth;
  static bool isTablet(BuildContext context) => MediaQuery.of(context).size.width >= mobileMaxWidth && MediaQuery.of(context).size.width < tabletMaxWidth;
  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= tabletMaxWidth;
  static bool isWideDesktop(BuildContext context) => MediaQuery.of(context).size.width >= desktopMaxWidth;
}
