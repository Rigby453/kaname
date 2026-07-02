// SwipeToDelete — переиспользуемая обёртка над Dismissible для безопасного удаления.
//
// КОНТРАКТ ДЛЯ СЛЕДУЮЩИХ АГЕНТОВ:
// ---------------------------------------------------------------------------
// SwipeToDelete(
//   key: ValueKey(item.id),          // обязательно уникальный
//   onDelete: () async {
//     await dao.removeItem(item.id);  // собственно удаление из БД
//     if (context.mounted) {
//       showAppToast(context, variant: AppToastVariant.removed,
//         message: '"${item.name}" removed');
//     }
//   },
//   child: MyItemTile(item: item),
// )
//
// Фон свайпа: ember (0.15 alpha) + Phosphor trash (ember-цвет).
// direction: endToStart (свайп влево = удалить).
// Reduce-motion: Dismissible сам корректно работает с disableAnimations.
//
// УДАЛЕНИЕ БЕЗ UNDO (2026-07): кнопки Undo в приложении больше нет (см.
// docs/decisions.md). Для «дешёвого»/частого контента (food log, shopping
// list, задачи Today) удаление остаётся немедленным — confirmMessage не
// передаём. Для «дорогого» пользовательского контента (рецепты, тренировки,
// привычки, цели, пресеты медитации/дыхания, шаги рецепта/тренировки/цели)
// передаём confirmMessage — тогда перед удалением показывается блокирующий
// confirm-диалог (см. [showDeleteConfirmDialog]), отмена возвращает свайп
// на место.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// Общий confirm-диалог перед необратимым удалением «дорогого» контента.
/// Переиспользуется [SwipeToDelete.confirmMessage] (жест свайпа) И одиночными
/// кнопками-корзинами в карточках (тот же путь удаления — без дублирования
/// диалога, см. вызовы `_confirmDelete*` в feature-экранах).
/// Возвращает true, если пользователь подтвердил удаление (нажал btn.delete).
Future<bool> showDeleteConfirmDialog(
  BuildContext context, {
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.s('dialog.delete_confirm_title')),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(ctx.s('btn.cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(ctx.s('btn.delete')),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Обёртка над [Dismissible] — свайп влево вызывает [onDelete].
///
/// Если [confirmMessage] != null — перед удалением показывает блокирующий
/// confirm-диалог ([showDeleteConfirmDialog]); отмена снимает свайп на место.
/// Если null — немедленное удаление, как раньше (без диалога).
class SwipeToDelete extends StatelessWidget {
  const SwipeToDelete({
    required super.key,
    required this.onDelete,
    required this.child,
    this.confirmMessage,
  });

  /// Удаление. Вызывается после завершения свайпа (и, если задан
  /// [confirmMessage], после подтверждения в диалоге).
  final VoidCallback onDelete;

  final Widget child;

  /// Текст confirm-диалога (обычно `'"${item.name}"'`) для «дорогого»
  /// контента. null = без диалога (немедленное удаление).
  final String? confirmMessage;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    // ember — деструктивное действие (design-tokens.json §status)
    final emberColor = ext?.ember ?? Theme.of(context).colorScheme.error;

    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      confirmDismiss: confirmMessage == null
          ? null
          : (_) => showDeleteConfirmDialog(context, message: confirmMessage!),
      // Фон: ember-тинт + Phosphor trash (ember-цвет)
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: emberColor.withValues(alpha: 0.15),
        ),
        child: PhosphorIcon(
          PhosphorIcons.trash(PhosphorIconsStyle.regular),
          size: 20,
          color: emberColor,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: child,
    );
  }
}
