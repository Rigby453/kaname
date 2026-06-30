// Общий enum + переключатель периода (День/Неделя/Месяц) для полных отчётов
// здоровья (вода/сон) — аналог переключателя «лент» (day/week/month) в Plan.
// Переиспользует уже готовые ключи `plan.view_day/week/month` (plan_diary.dart):
// смысл идентичен, новых строк под сам переключатель заводить не нужно.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';

/// Период отчёта. [days] — длина скользящего окна, заканчивающегося на
/// выбранной (anchor) дате включительно.
enum ReportPeriod { day, week, month }

extension ReportPeriodX on ReportPeriod {
  /// Длина окна в днях (день=1, неделя=7, месяц=30).
  int get days => switch (this) {
        ReportPeriod.day => 1,
        ReportPeriod.week => 7,
        ReportPeriod.month => 30,
      };

  /// Подпись диапазона над навигатором дат: для дня — полная дата
  /// (как раньше), для недели/месяца — диапазон «{start} – {end}».
  /// Locale-aware через intl (Intl.defaultLocale выставлен в main()).
  String rangeLabel(DateTime anchor) {
    if (this == ReportPeriod.day) {
      return DateFormat.yMMMMd().format(anchor);
    }
    final start = anchor.subtract(Duration(days: days - 1));
    final sameYear = start.year == anchor.year;
    final startFmt = sameYear ? DateFormat.MMMd() : DateFormat.yMMMd();
    return '${startFmt.format(start)} – ${DateFormat.yMMMd().format(anchor)}';
  }
}

/// Подписи для плотных месячных бар-чартов (30 точек) — подписывается
/// каждый [step]-й день + последний, чтобы подписи не налезали друг на
/// друга на узких экранах (320px). Используется водой и сном.
List<String> sparseMonthLabels(List<DateTime> dates, {int step = 5}) {
  return [
    for (var i = 0; i < dates.length; i++)
      if (i % step == 0 || i == dates.length - 1)
        DateFormat.d().format(dates[i])
      else
        '',
  ];
}

/// Переключатель День/Неделя/Месяц — обёрнут в горизонтальный скролл как
/// страховка от overflow на 320px + крупный текст (анти-регрессия gate B):
/// сам SegmentedButton не сжимается, а при длинных переводах/textScale 1.5
/// его суммарная ширина может превысить экран.
class PeriodSwitcher extends StatelessWidget {
  const PeriodSwitcher({
    super.key,
    required this.period,
    required this.onChanged,
  });

  final ReportPeriod period;
  final ValueChanged<ReportPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final segmented = SegmentedButton<ReportPeriod>(
      segments: [
        ButtonSegment(
          value: ReportPeriod.day,
          label: Text(
            context.s('plan.view_day'),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ButtonSegment(
          value: ReportPeriod.week,
          label: Text(
            context.s('plan.view_week'),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ButtonSegment(
          value: ReportPeriod.month,
          label: Text(
            context.s('plan.view_month'),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
      selected: {period},
      showSelectedIcon: false,
      onSelectionChanged: (sel) => onChanged(sel.first),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: segmented,
    );
  }
}
