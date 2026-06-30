// Переиспользуемый бейдж «🔒 Premium» для пометки платных функций.
// Размещается рядом с заголовком или строкой, которая требует подписки.
// Пример использования:
//   Row(children: [Text('AI reschedule'), SizedBox(width: 8), PremiumLockBadge()])

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// Небольшой бейдж-таблетка «🔒 Premium».
///
/// [showLabel] — показывать текстовую метку рядом с иконкой (по умолчанию true).
/// false → только иконка замка, подходит для очень компактных мест.
class PremiumLockBadge extends StatelessWidget {
  const PremiumLockBadge({super.key, this.showLabel = true});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        // Мягкий accentTint-фон + hairline border (design-tokens: border 0.5)
        color: ext.accentTint.withValues(alpha: 0.45),
        border: Border.all(color: ext.border, width: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.lock(PhosphorIconsStyle.fill),
            size: 11,
            color: colorScheme.primary,
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              context.s('paywall.lock_badge_label'),
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
