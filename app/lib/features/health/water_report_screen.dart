// Отчёт о воде — история, статистика.
// Redesign «Kaname» §4.2: Phosphor, hairline-divided rows (вместо card-per-entry),
// пустое состояние с KaiMascot, FittedBox для stat-значений на 320px.
// #22: переключатель периода День/Неделя/Месяц (как ленты в планере) + бар+линия
// чарт потребления во времени. Триаж water-weekly-headline-sum: крупный показатель
// для Недели/Месяца — среднее/день (не сумма за период), подписан «в среднем/день».
// Открывается из WaterFullscreenScreen или из кнопки отчёта в карточке Health.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/water_goal_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/date_navigator.dart';
import '../../core/widgets/kai_loader.dart';
import '../../core/widgets/period_switcher.dart';
import '../../core/widgets/trend_chart.dart';
import '../mascot/kai_mascot.dart';

/// Провайдер выбранной даты (water report). В режиме Week/Month — это «конец»
/// (anchor) скользящего окна включительно, как и в режиме Day.
final waterSelectedDateProvider = StateProvider.autoDispose<DateTime>((ref) {
  return DateTime.now();
});

/// Выбранный период отчёта (#22) — День/Неделя/Месяц.
final waterReportPeriodProvider =
    StateProvider.autoDispose<ReportPeriod>((ref) => ReportPeriod.day);

/// Все записи воды за выбранный день, реактивно. Режим Day.
final waterLogsForDateProvider =
    StreamProvider.autoDispose<List<WaterLogsTableData>>((ref) {
      final date = ref.watch(waterSelectedDateProvider);
      return ref.watch(waterDaoProvider).watchWaterForDate(date);
    });

/// Сумма выпитого за выбранный день, реактивно. Режим Day.
final waterTotalForDateProvider = StreamProvider.autoDispose<int>((ref) {
  final date = ref.watch(waterSelectedDateProvider);
  return ref.watch(waterDaoProvider).watchTotalForDate(date);
});

/// Суммы по дням за выбранное окно (Week=7/Month=30 дней), индекс 0 — самый
/// старый день, последний — anchor-дата. Режим Week/Month.
final waterPeriodTotalsProvider = StreamProvider.autoDispose<List<int>>((ref) {
  final period = ref.watch(waterReportPeriodProvider);
  final anchor = ref.watch(waterSelectedDateProvider);
  return ref.watch(waterDaoProvider).watchDailyTotals(anchor, period.days);
});

// ---------------------------------------------------------------------------
// Чистые хелперы (без BuildContext) — бакетинг для внутридневного графика.
// Вынесены на верхний уровень, чтобы их можно было юнит-тестировать напрямую.
// ---------------------------------------------------------------------------

/// Бакетит записи воды за день по часам для графика режима Day.
/// [bucketHours] — ширина бакета в часах (по умолчанию 4 → 6 бакетов/сутки).
List<int> waterHourlyBuckets(
  List<WaterLogsTableData> logs, {
  int bucketHours = 4,
}) {
  final n = (24 / bucketHours).ceil();
  final out = List<int>.filled(n, 0);
  for (final log in logs) {
    final idx = (log.loggedAt.hour ~/ bucketHours).clamp(0, n - 1);
    out[idx] += log.amountMl;
  }
  return out;
}

/// Подписи бакетов — час начала бакета («00», «04», …). Только цифры —
/// l10n не нужен (как HH:mm в _WaterLogRow).
List<String> waterHourlyLabels({int bucketHours = 4}) {
  final n = (24 / bucketHours).ceil();
  return List.generate(n, (i) => (i * bucketHours).toString().padLeft(2, '0'));
}

class WaterReportScreen extends ConsumerWidget {
  const WaterReportScreen({super.key, this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Устанавливаем начальную дату, если передана
    ref.listen(waterSelectedDateProvider, (_, next) {});
    if (date != null) {
      ref.read(waterSelectedDateProvider.notifier).state = date!;
    }

    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final period = ref.watch(waterReportPeriodProvider);
    final selectedDate = ref.watch(waterSelectedDateProvider);
    final waterGoal = ref.watch(waterGoalProvider);

    return Scaffold(
      appBar: AppBar(
        // Phosphor: arrowLeft вместо Material arrow_back
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft()),
          onPressed: () => context.pop(),
        ),
        title: Text(context.s('water.report_title')),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Переключатель периода (#22) — день/неделя/месяц, как ленты в Plan.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: PeriodSwitcher(
              period: period,
              onChanged: (p) =>
                  ref.read(waterReportPeriodProvider.notifier).state = p,
            ),
          ),

          // DateNavigator — для Week/Month степ навигации = длине периода,
          // подпись = диапазон дат вместо одного дня.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ext.border, width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: DateNavigator(
                date: selectedDate,
                stepDays: period.days,
                label: period.rangeLabel(selectedDate),
                onChanged: (d) =>
                    ref.read(waterSelectedDateProvider.notifier).state = d,
              ),
            ),
          ),

          Expanded(
            child: period == ReportPeriod.day
                ? _DayBody(waterGoal: waterGoal)
                : _PeriodBody(period: period, waterGoal: waterGoal),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DayBody — режим «День»: три статкарточки, внутридневной чарт (если есть
// записи), список записей (время + объём), как было раньше.
// ---------------------------------------------------------------------------

class _DayBody extends ConsumerWidget {
  const _DayBody({required this.waterGoal});

  final int waterGoal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final waterLogs = ref.watch(waterLogsForDateProvider);
    final waterTotal = ref.watch(waterTotalForDateProvider);

    return waterLogs.when(
      data: (logs) => SingleChildScrollView(
        // 24dp горизонтальные поля — spec §1
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Три мини-карточки статистики
            waterTotal.when(
              data: (total) => _buildStatsSection(
                context,
                total,
                waterGoal,
                textTheme,
                ext,
                colorScheme,
              ),
              loading: () => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: KaiLoader(label: context.s('loading.generic')),
                ),
              ),
              error: (err, _) =>
                  Text(context.s('error.generic').replaceFirst('{err}', '$err')),
            ),

            // Внутридневной бар+линия чарт («потребления во времени», #22) —
            // только когда есть хотя бы одна запись за день.
            if (logs.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(context.s('water.chart_section'), style: textTheme.titleMedium),
              const SizedBox(height: 12),
              BarLineChart(
                values:
                    waterHourlyBuckets(logs).map((v) => v.toDouble()).toList(),
                labels: waterHourlyLabels(),
                height: 96,
              ),
            ],
            const SizedBox(height: 24),

            // Заголовок секции записей — titleMedium
            Text(
              context.s('water.logs_section'),
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // Пустое состояние — §4.2: Kai (neutral 64) + подпись + verb button
            if (logs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      const KaiMascot(
                        size: 64,
                        emotion: KaiEmotion.neutral,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.s('water.no_logs'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: ext.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // Verb button — возврат для записи воды
                      OutlinedButton(
                        onPressed: () => context.pop(),
                        child: Text(context.s('water.log_water_btn')),
                      ),
                    ],
                  ),
                ),
              )
            else
              // §4.2 hairline-divided rows — один контейнер вместо card-per-row
              _buildLogsList(context, logs, colorScheme, ext),
          ],
        ),
      ),
      // KaiLoader вместо CircularProgressIndicator
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: KaiLoader(label: context.s('loading.water')),
        ),
      ),
      error: (err, _) => Center(
        child: Text(
          context.s('error.generic').replaceFirst('{err}', '$err'),
        ),
      ),
    );
  }

  /// Три мини-карточки: всего / цель / статус. §4.2 stat cards с FittedBox.
  Widget _buildStatsSection(
    BuildContext context,
    int total,
    int waterGoal,
    TextTheme textTheme,
    FocusThemeExtension ext,
    ColorScheme colorScheme,
  ) {
    final percentage = waterGoal > 0 ? (total / waterGoal * 100).round() : 0;
    final status =
        percentage >= 100 ? context.s('water.goal_met') : '$percentage%';

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: context.s('water.stat_total'),
            value: '${(total / 1000).toStringAsFixed(1)}L',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: context.s('water.stat_goal'),
            value: '${(waterGoal / 1000).toStringAsFixed(1)}L',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: context.s('water.stat_status'),
            value: status,
          ),
        ),
      ],
    );
  }

  /// §4.2 hairline-divided rows — единый контейнер вместо card-per-row.
  Widget _buildLogsList(
    BuildContext context,
    List<WaterLogsTableData> logs,
    ColorScheme colorScheme,
    FocusThemeExtension ext,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < logs.length; i++) ...[
            _WaterLogRow(log: logs[i]),
            if (i < logs.length - 1)
              Divider(height: 1, thickness: 0.5, color: ext.border),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PeriodBody — режим «Неделя»/«Месяц»: headline = среднее/день (фикс
// триажа water-weekly-headline-sum), бар+линия чарт по дням периода, список
// суточных итогов (только дни с записями).
// ---------------------------------------------------------------------------

class _PeriodBody extends ConsumerWidget {
  const _PeriodBody({required this.period, required this.waterGoal});

  final ReportPeriod period;
  final int waterGoal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final totalsAsync = ref.watch(waterPeriodTotalsProvider);
    final anchor = ref.watch(waterSelectedDateProvider);

    return totalsAsync.when(
      data: (totals) {
        final days = period.days;
        if (totals.length != days) return const SizedBox.shrink();

        // totals[0] — самый старый день окна, totals[last] — anchor-дата.
        final anchorDay = DateTime(anchor.year, anchor.month, anchor.day);
        final dates = List.generate(
          days,
          (i) => anchorDay.subtract(Duration(days: days - 1 - i)),
        );

        final sumMl = totals.fold<int>(0, (a, b) => a + b);
        // БАГ-фикс (water-weekly-headline-sum): headline = среднее/день, НЕ
        // сумма за период — денежная единица периода всегда days (как в
        // wrapped_screen.dart avgWaterMl), а не «дни с записями».
        final avgMl = days > 0 ? (sumMl / days).round() : 0;
        final daysMet =
            waterGoal > 0 ? totals.where((t) => t >= waterGoal).length : 0;
        final hasAnyData = totals.any((t) => t > 0);

        final locale = Localizations.localeOf(context).toString();
        final labels = period == ReportPeriod.week
            ? [for (final d in dates) DateFormat('EEEEE', locale).format(d)]
            : sparseMonthLabels(dates);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPeriodStatsSection(
                context,
                avgMl,
                waterGoal,
                daysMet,
                days,
                textTheme,
                ext,
              ),
              const SizedBox(height: 24),

              // Бар+линия чарт — столбцы по дням периода + ломаная кривая тренда.
              Text(context.s('water.chart_section'), style: textTheme.titleMedium),
              const SizedBox(height: 12),
              BarLineChart(
                values: totals.map((t) => t.toDouble()).toList(),
                labels: labels,
                goalLine: waterGoal.toDouble(),
                height: 120,
                highlightIndex: days - 1,
              ),
              const SizedBox(height: 24),

              Text(
                context.s('water.daily_totals_section'),
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              if (!hasAnyData)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        const KaiMascot(size: 64, emotion: KaiEmotion.neutral),
                        const SizedBox(height: 16),
                        Text(
                          context.s('water.no_data_period'),
                          style: textTheme.bodyMedium?.copyWith(
                            color: ext.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                _buildDailyTotalsList(context, dates, totals, colorScheme, ext),
            ],
          ),
        );
      },
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: KaiLoader(label: context.s('loading.water')),
        ),
      ),
      error: (err, _) => Center(
        child: Text(context.s('error.generic').replaceFirst('{err}', '$err')),
      ),
    );
  }

  /// Headline = среднее/день, цель/день, кол-во дней с выполненной нормой.
  Widget _buildPeriodStatsSection(
    BuildContext context,
    int avgMl,
    int waterGoal,
    int daysMet,
    int totalDays,
    TextTheme textTheme,
    FocusThemeExtension ext,
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: context.s('water.stat_avg_day'),
            value: '${(avgMl / 1000).toStringAsFixed(1)}L',
            isSuccess: waterGoal > 0 && avgMl >= waterGoal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: context.s('water.stat_goal'),
            value: '${(waterGoal / 1000).toStringAsFixed(1)}L',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: context.s('water.stat_days_met'),
            value: '$daysMet/$totalDays',
          ),
        ),
      ],
    );
  }

  /// §4.2 hairline-divided rows — суточные итоги (только дни с записями),
  /// свежие сверху.
  Widget _buildDailyTotalsList(
    BuildContext context,
    List<DateTime> dates,
    List<int> totals,
    ColorScheme colorScheme,
    FocusThemeExtension ext,
  ) {
    final entries = <(DateTime, int)>[
      for (var i = 0; i < dates.length; i++)
        if (totals[i] > 0) (dates[i], totals[i]),
    ].reversed.toList();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            _DailyTotalRow(date: entries[i].$1, totalMl: entries[i].$2),
            if (i < entries.length - 1)
              Divider(height: 1, thickness: 0.5, color: ext.border),
          ],
        ],
      ),
    );
  }
}

/// Одна строка записи воды в §4.2 стиле: время слева, объём справа.
/// Дата не показывается — день уже выбран в DateNavigator. Режим Day.
class _WaterLogRow extends StatelessWidget {
  const _WaterLogRow({required this.log});

  final WaterLogsTableData log;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    // Время в формате HH:mm
    final time =
        '${log.loggedAt.hour.toString().padLeft(2, '0')}:${log.loggedAt.minute.toString().padLeft(2, '0')}';
    // Объём — локаль-aware через шаблон (не хардкод 'ml')
    final amount = context
        .s('water.amt_ml_fmt')
        .replaceFirst('{ml}', '${log.amountMl}');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          // Phosphor drop — доменная иконка воды
          Icon(PhosphorIcons.drop(), size: 16, color: ext.textMuted),
          const SizedBox(width: 10),
          // Время — bodyMedium
          Text(time, style: textTheme.bodyMedium),
          const Spacer(),
          // Объём — titleSmall (w500, числа читаются чётче)
          Text(amount, style: textTheme.titleSmall),
        ],
      ),
    );
  }
}

/// Одна строка суточного итога: дата слева, объём справа. Режим Week/Month.
class _DailyTotalRow extends StatelessWidget {
  const _DailyTotalRow({required this.date, required this.totalMl});

  final DateTime date;
  final int totalMl;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final dateStr = DateFormat.MMMd().format(date);
    final amount =
        context.s('water.amt_ml_fmt').replaceFirst('{ml}', '$totalMl');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(PhosphorIcons.drop(), size: 16, color: ext.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              dateStr,
              style: textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(amount, style: textTheme.titleSmall),
        ],
      ),
    );
  }
}

/// Мини-карточка статистики (total / goal / status и avg/goal/days-met).
/// §4.2 flat card. FittedBox на значении защищает от overflow на 320px +
/// textScale 1.5. [isSuccess] — необязательная success-окраска значения
/// (null = нейтральный цвет, как и раньше).
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool? isSuccess;

  const _StatCard({
    required this.label,
    required this.value,
    this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final valueColor = isSuccess == true ? ext.success : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Метка — bodySmall + textMuted
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Значение — headlineMedium; FittedBox защищает от overflow
          // на 320px + textScale 1.5 (особенно «Goal Met!» длиннее «1.8L»)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: textTheme.headlineMedium?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
