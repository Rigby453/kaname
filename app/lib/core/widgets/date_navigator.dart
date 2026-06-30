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
//
// Иконки: Phosphor caretLeft / caretRight (20dp), calendarBlank (16dp).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_theme.dart';

class DateNavigator extends StatelessWidget {
  const DateNavigator({
    super.key,
    required this.date,
    required this.onChanged,
    this.firstDate,
    this.stepDays = 1,
    this.label,
  });

  /// Текущая выбранная дата (для week/month — конец окна, включительно).
  final DateTime date;

  /// Вызывается при выборе новой даты (через стрелки или DatePicker).
  final ValueChanged<DateTime> onChanged;

  /// Нижняя граница DatePicker. По умолчанию DateTime(2020).
  final DateTime? firstDate;

  /// Шаг навигации стрелками в днях: 1 — день (по умолчанию), 7 — неделя,
  /// 30 — месяц (см. ReportPeriod в core/widgets/period_switcher.dart).
  final int stepDays;

  /// Переопределяет авто-подпись `DateFormat.yMMMMd(date)` — нужно для
  /// week/month, где подпись это диапазон, а не одна дата.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(date.year, date.month, date.day);
    // Шаг можно сделать только пока окно ещё не доходит до сегодня —
    // следующий клик всегда clamp'ится до todayDate (не уезжает в будущее).
    final canGoForward = selectedDate.isBefore(todayDate);

    return Row(
      children: [
        // Предыдущий период — Phosphor caretLeft (20dp)
        IconButton(
          icon: PhosphorIcon(
            PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
            size: 20,
          ),
          onPressed: () =>
              onChanged(date.subtract(Duration(days: stepDays))),
        ),

        // Тапаемая подпись даты/диапазона → открывает DatePicker
        Expanded(
          child: GestureDetector(
            onTap: () => _showPicker(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label ?? DateFormat.yMMMMd().format(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Phosphor calendarBlank (16dp, caption size)
                PhosphorIcon(
                  PhosphorIcons.calendarBlank(PhosphorIconsStyle.regular),
                  size: 16,
                  color: ext.textMuted,
                ),
              ],
            ),
          ),
        ),

        // Следующий период — отключён, если окно уже у сегодня — Phosphor caretRight (20dp)
        IconButton(
          icon: PhosphorIcon(
            PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
            size: 20,
          ),
          onPressed: canGoForward
              ? () {
                  final next = date.add(Duration(days: stepDays));
                  onChanged(next.isAfter(todayDate) ? todayDate : next);
                }
              : null,
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
      lastDate: now,
    );
    if (picked != null) {
      onChanged(picked);
    }
  }
}
