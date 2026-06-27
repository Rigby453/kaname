// Карточка одного варианта раскладки (free или AI) с кнопкой Apply.
// Общая для утреннего и вечернего разборов.
//
// Два режима рендеринга:
//   - AI-вариант (variant.moves != null): развёрнутая карточка с детальным
//     списком перестановок (<название> → HH:MM) и полным reason без обрезания.
//   - Rule-based вариант (variant.moves == null): компактный ListTile
//     (метка + ключ обоснования + Apply), как прежде.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import 'review_engine.dart';

class ReviewVariantCard extends StatelessWidget {
  const ReviewVariantCard({
    required this.variant,
    required this.onApply,
    super.key,
  });

  final PlanVariant variant;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final moves = variant.moves;
    if (moves != null) {
      // AI-вариант: развёрнутая карточка с перестановками.
      return _AiVariantCard(variant: variant, moves: moves, onApply: onApply);
    }
    // Rule-based: компактный ListTile. Разрешаем ключ локализации;
    // если ключа нет (AI-вариант без moves) — context.s вернёт строку как fallback.
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(context.s(variant.label)),
        subtitle: variant.reason.isEmpty
            ? null
            : Text(context.s(variant.reason)),
        trailing: TextButton(
          onPressed: onApply,
          child: Text(context.s('today.apply_btn')),
        ),
      ),
    );
  }
}

/// Развёрнутая карточка AI-варианта: метка + список перестановок + reason + Apply.
/// reason выводится без ограничения строк — пусть переносится, не обрезается.
class _AiVariantCard extends StatelessWidget {
  const _AiVariantCard({
    required this.variant,
    required this.moves,
    required this.onApply,
  });

  final PlanVariant variant;
  final List<PlanMove> moves;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Метка AI-плана — жирная, как «заголовок предложения».
            Text(
              variant.label,
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            // Список конкретных перестановок: <название> → HH:MM.
            ...moves.map(
              (m) => _MoveLine(
                move: m,
                ext: ext,
                colorScheme: colorScheme,
              ),
            ),
            if (variant.reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              // reason — полный текст AI, мягкий цвет, без ограничения строк.
              Text(
                variant.reason,
                style: textTheme.bodySmall?.copyWith(
                  color: ext?.textMuted ?? colorScheme.onSurfaceVariant,
                ),
                // softWrap=true по умолчанию; maxLines не задаём — пусть переносится.
              ),
            ],
            // Apply — прижат вправо.
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onApply,
                child: Text(context.s('today.apply_btn')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Одна строка перестановки: [●] <название> → HH:MM.
/// Overflow-safe на 320px + textScale 1.5: название завёрнуто в Flexible с ellipsis.
/// Если title пуст (старый бэкенд) — показываем только → HH:MM.
class _MoveLine extends StatelessWidget {
  const _MoveLine({
    required this.move,
    required this.ext,
    required this.colorScheme,
  });

  final PlanMove move;
  final FocusThemeExtension? ext;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Цвет dot зависит от приоритета (main → accent/primary, high → ember/error).
    final dotColor = switch (move.priority) {
      'main' => colorScheme.primary,
      'high' => ext?.ember ?? colorScheme.error,
      _ => Colors.transparent,
    };
    final showDot = move.priority == 'main' || move.priority == 'high';

    // DateFormat.Hm() → 24-часовой формат (09:00, 14:30); locale задана глобально.
    final timeStr = DateFormat.Hm().format(move.at);
    final hasTitle = move.title.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Dot: 6dp круг-индикатор приоритета; занимает фиксированные 12dp.
          SizedBox(
            width: 12,
            child: showDot
                ? Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          if (hasTitle) ...[
            // Название — сжимается с ellipsis чтобы не уходить за правый край.
            Flexible(
              child: Text(
                move.title,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium,
              ),
            ),
            // Стрелка и время — короткий суффикс, всегда видимый.
            Text(
              ' → $timeStr',
              style: textTheme.bodyMedium,
            ),
          ] else
            // Старый бэкенд без title: только время.
            Text('→ $timeStr', style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
