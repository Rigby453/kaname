// Единый виджет навигации по датам (chevron ‹ дата ›).
// Используется на: sleep_report, water_report, diary_history.
//
// Правила:
// - Дата форматируется locale-aware через intl (DateFormat.yMMMMd,
//   Intl.defaultLocale установлен в main через applyIntlLocale).
// - showDatePicker не форсирует локаль — берёт её из MaterialApp
//   (GlobalMaterialLocalizations.delegate).
// - Кнопка «›» отключена, если date == сегодня (нельзя смотреть в будущее).
// - Нет своих анимаций — уважает reduce-motion (MediaQuery.disableAnimations).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

class DateNavigator extends StatelessWidget {
  const DateNavigator({
    super.key,
    required this.date,
    required this.onChanged,
    this.firstDate,
  });

  /// Текущая выбранная дата.
  final DateTime date;

  /// Вызывается при выборе новой даты (через стрелки или DatePicker).
  final ValueChanged<DateTime> onChanged;

  /// Нижняя граница DatePicker. По умолчанию DateTime(2020).
  final DateTime? firstDate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    // Нормализуем до полуночи, чтобы сравнивать только дату, а не время
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(date.year, date.month, date.day);
    final isToday = selectedDate == todayDate;

    return Row(
      children: [
        // Предыдущий день
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(date.subtract(const Duration(days: 1))),
        ),

        // Тапаемая подпись даты → открывает DatePicker
        Expanded(
          child: GestureDetector(
            onTap: () => _showPicker(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    // DateFormat.yMMMMd() использует Intl.defaultLocale
                    DateFormat.yMMMMd().format(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  // textMuted — вторичная иконка, не CTA
                  color: ext.textMuted,
                ),
              ],
            ),
          ),
        ),

        // Следующий день (отключён, если уже стоит сегодня)
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: isToday
              ? null
              : () => onChanged(date.add(const Duration(days: 1))),
        ),
      ],
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: firstDate ?? DateTime(2020),
      // lastDate = сегодня — нельзя выбрать будущую дату
      lastDate: now,
      // locale не задаётся — используем локаль из MaterialApp
    );
    if (picked != null) {
      onChanged(picked);
    }
  }
}
