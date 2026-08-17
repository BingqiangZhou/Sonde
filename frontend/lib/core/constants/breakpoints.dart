import 'package:material_ui/material_ui.dart';

/// Responsive breakpoints for adaptive layouts
class Breakpoints {
  const Breakpoints._();

  static const double mini = 420;
  static const double medium = 600;
  static const double compact = 700;
  static const double mediumLarge = 840;
  static const double wideLayout = 1040;
  static const double large = 1200;

  static bool isMobile(double width) => width < medium;
  static bool isMini(double width) => width < mini;
}

extension BreakpointsExtension on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isMobile => Breakpoints.isMobile(screenWidth);
  bool get isLandscape => MediaQuery.of(this).orientation == Orientation.landscape;
  bool get isPortrait => MediaQuery.of(this).orientation == Orientation.portrait;
}
