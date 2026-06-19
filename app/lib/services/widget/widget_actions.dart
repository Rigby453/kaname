// Обработчик deep-link действий из домашнего виджета.
//
// Два пути доставки:
//   COLD START  → Flutter вызывает getLaunchAction() при старте приложения и
//                 получает Map? {action, date?} от нативной стороны.
//   WARM START  → нативная сторона зовёт invokeMethod("onWidgetAction", map),
//                 обработчик уже зарегистрирован через setMethodCallHandler.
//
// Действия (widget_action):
//   open_today — перейти на /today.
//   open_day   — перейти на /plan и выставить выбранный день = date.
//   add_task   — открыть AddTaskSheet поверх текущего экрана.
//
// Вызов initWidgetActions() — из main.dart, после построения MaterialApp.router
// (точнее — из initState KaizenApp, после того как роутер готов).
//
// ВАЖНО: навигация возможна только когда роутер успел обработать redirect-цепочку
// (онбординг/auth). Поэтому для cold start мы добавляем post-frame callback.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../features/plan/widgets/week_strip.dart' show selectedDayProvider;
import '../../features/today/widgets/add_task_sheet.dart';

const _channel = MethodChannel('kaizen/widget');

/// Инициализирует обработку deep-link действий из домашнего виджета.
///
/// Вызывать один раз в initState KaizenApp после готовности роутера.
/// [ref] нужен для чтения/записи Riverpod-провайдеров (selectedDayProvider).
/// [navigatorKey] опционален — если роутер создан с globalKey, передаём его.
void initWidgetActions(WidgetRef ref) {
  // Warm start: нативная сторона зовёт "onWidgetAction" когда приложение уже открыто.
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'onWidgetAction') {
      final map = call.arguments as Map?;
      if (map != null) {
        _handleAction(ref, map['action'] as String?, map['date'] as String?);
      }
    }
  });

  // Cold start: один раз запрашиваем pending action из launch-интента виджета.
  // Post-frame callback даёт роутеру время завершить redirect-цепочку.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getLaunchAction');
      if (result != null) {
        final action = result['action'] as String?;
        final date = result['date'] as String?;
        // Ещё один frame — роутер мог ещё не завершить redirect на этом кадре
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleAction(ref, action, date);
        });
      }
    } catch (_) {
      // getLaunchAction недоступен (web/desktop/iOS без native реализации) — игнорируем.
    }
  });
}

/// Выполняет навигацию по действию виджета.
/// Ничего не делает если приложение ещё на онбординге/авторизации (роутер перенаправит).
void _handleAction(WidgetRef ref, String? action, String? date) {
  if (action == null) return;

  // Получаем контекст через navigatorKey, который go_router регистрирует внутри.
  // GoRouter.of(context) недоступен вне виджетного дерева, поэтому используем
  // провайдер роутера напрямую через ref.
  final router = ref.read(routerProvider);
  final context = router.routerDelegate.navigatorKey.currentContext;
  if (context == null) return;

  switch (action) {
    case 'open_today':
      // Навигируем на /today (первый таб).
      router.go('/today');

    case 'open_day':
      // Навигируем на /plan и выставляем выбранный день.
      final parsedDate = _parseDate(date);
      final targetDay = parsedDate ?? _today();
      ref.read(selectedDayProvider.notifier).state = targetDay;
      router.go('/plan');

    case 'add_task':
      // Открываем AddTaskSheet поверх текущего экрана.
      // Используем rootNavigator context из go_router.
      showAddTaskSheet(context, day: _today());
  }
}

/// Парсит ISO-дату "yyyy-MM-dd" в DateTime (нормализованную до полуночи).
/// Возвращает null при ошибке.
DateTime? _parseDate(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return null;
  try {
    final parts = isoDate.split('-');
    if (parts.length != 3) return null;
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  } catch (_) {
    return null;
  }
}

/// Сегодняшняя дата, нормализованная до полуночи локального времени.
DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
