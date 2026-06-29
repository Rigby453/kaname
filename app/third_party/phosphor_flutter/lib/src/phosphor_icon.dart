library phosphor_flutter;

import 'package:flutter/material.dart';

// PATCHED: icons are now plain `IconData` (see phosphor_icon_data.dart), so the
// dedicated duotone subtype no longer exists. PhosphorIcon stays a thin `Icon`
// subclass; the `duotoneSecondary*` parameters are kept for source-compatibility
// but are inert (the duotone two-layer render path was dropped — unused by the app).
class PhosphorIcon extends Icon {
  const PhosphorIcon(
    IconData icon, {
    Key? key,
    double? size,
    double? fill,
    double? weight,
    double? grade,
    double? opticalSize,
    Color? color,
    List<Shadow>? shadows,
    String? semanticLabel,
    TextDirection? textDirection,
    double duotoneSecondaryOpacity = 0.20,
    Color? duotoneSecondaryColor,
  }) : super(
          icon,
          color: color,
          fill: fill,
          grade: grade,
          key: key,
          opticalSize: opticalSize,
          semanticLabel: semanticLabel,
          shadows: shadows,
          size: size,
          textDirection: textDirection,
          weight: weight,
        );
}
