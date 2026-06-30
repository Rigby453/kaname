// FL-RECUR-SCOPE: Диалог выбора области редактирования повторяющейся задачи.
// Показывается из add_task_sheet._save() когда пользователь изменил время
// повторяющегося экземпляра (виртуального повтора серии).
//
// Стандарт Google Calendar: «Только это событие» / «Это и последующие» / «Все».
// Возвращает RecurrenceEditScope? (null = отмена, не сохранять).
//
// Стиль Kaname: surface / hairline 0.5 / R20, Phosphor-иконки (regular),
// акцент = colorScheme.primary. Overflow-safe на 320px + textScale 2.0.

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/animations/app_sheet.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';

/// Область применения изменения повторяющейся задачи.
enum RecurrenceEditScope {
  /// Только эта конкретная дата серии (материализовать один день).
  onlyThis,

  /// Эта дата и все последующие (разрезать серию с новым временем).
  thisAndFuture,

  /// Весь ряд — изменить время на якоре и всех конкретных экземплярах.
  wholeSeries,
}

/// Показывает нижний лист выбора области редактирования повторяющейся задачи.
///
/// Возвращает выбранную [RecurrenceEditScope] или null, если пользователь
/// закрыл лист (отмена / свайп). null означает «не сохранять, вернуться в форму».
///
/// Стиль: нижний лист Kaname (R20, surface background, hairline-разделители).
Future<RecurrenceEditScope?> showRecurrenceScopeDialog(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return showAppSheet<RecurrenceEditScope>(
    context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (sheetCtx) => Material(
      color: cs.surface,
      surfaceTintColor: Colors.transparent,
      child: RecurrenceScopeSheetContent(
        onSelected: (scope) => Navigator.of(sheetCtx).pop(scope),
        onCancel: () => Navigator.of(sheetCtx).pop(null),
      ),
    ),
  );
}

/// Содержимое нижнего листа выбора области. Stateless — всё состояние
/// управляется вызывающим кодом через колбэки [onSelected] / [onCancel].
class RecurrenceScopeSheetContent extends StatelessWidget {
  const RecurrenceScopeSheetContent({
    super.key,
    required this.onSelected,
    required this.onCancel,
  });

  final ValueChanged<RecurrenceEditScope> onSelected;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FocusThemeExtension>();
    final cs = theme.colorScheme;
    final textMuted = ext?.textMuted ?? cs.onSurface.withValues(alpha: 0.55);
    final borderColor = ext?.border ?? cs.outline.withValues(alpha: 0.3);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ручка-индикатор (drag handle) — стандарт §4.3 REDESIGN-KANAME.md
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Заголовок — обрезается с ellipsis на узком экране
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
            child: Text(
              context.s('today.recur_scope_title'),
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),

          // Горизонтальный разделитель перед первой опцией
          Divider(height: 1, thickness: 0.5, color: borderColor),

          // --- Три опции ---
          _ScopeOption(
            icon: PhosphorIcons.calendarBlank(PhosphorIconsStyle.regular),
            label: context.s('today.recur_scope_only_this'),
            accent: cs.primary,
            onTap: () => onSelected(RecurrenceEditScope.onlyThis),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 56,
            endIndent: 0,
            color: borderColor,
          ),
          _ScopeOption(
            icon: PhosphorIcons.arrowRight(PhosphorIconsStyle.regular),
            label: context.s('today.recur_scope_this_future'),
            accent: cs.primary,
            onTap: () => onSelected(RecurrenceEditScope.thisAndFuture),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 56,
            endIndent: 0,
            color: borderColor,
          ),
          _ScopeOption(
            icon: PhosphorIcons.repeat(PhosphorIconsStyle.regular),
            label: context.s('today.recur_scope_all'),
            accent: cs.primary,
            onTap: () => onSelected(RecurrenceEditScope.wholeSeries),
          ),

          // Горизонтальный разделитель после последней опции
          Divider(height: 1, thickness: 0.5, color: borderColor),

          // Кнопка «Отмена»
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
            child: OutlinedButton(
              onPressed: onCancel,
              child: Text(context.s('btn.cancel')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Одна строка-опция в листе выбора области.
/// [icon] — Phosphor-иконка (size 20, цвет accent).
/// [label] — локализованная подпись (Expanded + ellipsis → overflow-safe).
class _ScopeOption extends StatelessWidget {
  const _ScopeOption({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: accent),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
