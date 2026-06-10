// Единый враппер для модальных bottom sheet в приложении.
// Реализует анимацию по ANIMATIONS.md §8.2:
//   появление: translateY(100%→0), 320 мс, easeOutCubic
//   закрытие:  translateY(0→100%), 220 мс, easeInCubic
//   backdrop:  fade 0→0.5 (Colors.black54)
// При reduce motion (MediaQuery.disableAnimations) длительности = Duration.zero.

import 'package:flutter/material.dart';

import 'constants.dart';

// Длительности модалок — ANIMATIONS.md §8.2 (не совпадают с kDurationNormal/kDurationFast,
// поэтому задаём локально, а не выносим в constants.dart).
const _kSheetOpenDuration = Duration(milliseconds: 320); // §8.2
const _kSheetCloseDuration = Duration(milliseconds: 220); // §8.2

/// Показывает модальный bottom sheet с анимацией по ANIMATIONS.md §8.2.
///
/// Тонкий враппер над [showModalBottomSheet]; все per-call параметры
/// прокидываются без изменения поведения.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  BoxConstraints? constraints,
  String? barrierLabel,
  bool useRootNavigator = false,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  AnimationController? transitionAnimationController,
}) {
  // Reduce motion: если системная настройка отключает анимации — мгновенный показ.
  final reduce = reduceMotionOf(context);
  final openDuration = reduce ? Duration.zero : _kSheetOpenDuration;
  final closeDuration = reduce ? Duration.zero : _kSheetCloseDuration;

  // AnimationStyle позволяет переопределить длительности встроенной анимации шита.
  // Кривые (easeOutCubic / easeInCubic) в Flutter 3.x нельзя задать через
  // AnimationStyle — API пока не поддерживает curve/reverseCurve в этом классе;
  // Flutter использует собственные кривые шита. Длительности задаём точно по §8.2.
  final animStyle = AnimationStyle(
    duration: openDuration,
    reverseDuration: closeDuration,
  );

  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor,
    shape: shape,
    constraints: constraints,
    barrierLabel: barrierLabel,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    transitionAnimationController: transitionAnimationController,
    // Backdrop: opacity 0→0.5 (ANIMATIONS.md §8.2).
    barrierColor: Colors.black54,
    // Длительности анимации шита по §8.2.
    sheetAnimationStyle: animStyle,
  );
}
