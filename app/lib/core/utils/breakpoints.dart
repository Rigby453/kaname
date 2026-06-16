import 'package:flutter/material.dart';

class Breakpoints {
  static const double tablet = 600;
  static const double desktop = 900;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;
}
