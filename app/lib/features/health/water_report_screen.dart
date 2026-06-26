// Полный отчёт воды — история, графики, статистика
// Открывается из Health → мини-карточка воды

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/water_goal_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/date_navigator.dart';
import '../../core/widgets/kai_loader.dart';

/// Провайдер для выбранной даты (water report)
final waterSelectedDateProvider = StateProvider.autoDispose<DateTime>((ref) {
  return DateTime.now();
});

/// Все записи воды за выбранный день
final waterLogsForDateProvider =
    StreamProvider.autoDispose<List<WaterLogsTableData>>((ref) {
      final date = ref.watch(waterSelectedDateProvider);
      return ref.watch(waterDaoProvider).watchWaterForDate(date);
    });

/// Сумма выпитого за выбранный день
final waterTotalForDateProvider = StreamProvider.autoDispose<int>((ref) {
  final date = ref.watch(waterSelectedDateProvider);
  return ref.watch(waterDaoProvider).watchTotalForDate(date);
});

class WaterReportScreen extends ConsumerWidget {
  const WaterReportScreen({super.key, this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Устанавливаем начальную дату
    ref.listen(waterSelectedDateProvider, (_, next) {});
    if (date != null) {
      ref.read(waterSelectedDateProvider.notifier).state = date!;
    }

    final textTheme = Theme.of(context).textTheme;
    // ThemeExtension для textMuted / border / success (без хардкода)
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final selectedDate = ref.watch(waterSelectedDateProvider);
    final waterLogs = ref.watch(waterLogsForDateProvider);
    final waterTotal = ref.watch(waterTotalForDateProvider);
    final waterGoal = ref.watch(waterGoalProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        // Заголовок — AppBarTheme уже задаёт нужный стиль; не переопределяем
        title: Text(context.s('water.report_title')),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Единый DateNavigator — chevron ‹ дата › (locale-aware, без хардкод-массивов)
          Card(
            margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: DateNavigator(
                date: selectedDate,
                onChanged: (d) =>
                    ref.read(waterSelectedDateProvider.notifier).state = d,
              ),
            ),
          ),

          Expanded(
            child: waterLogs.when(
              data: (logs) => SingleChildScrollView(
                // 24dp горизонтальные поля — §4.1
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Статистика
                      waterTotal.when(
                        data: (total) => _buildStatsSection(
                          context,
                          total,
                          waterGoal,
                          textTheme,
                          ext,
                        ),
                        // KaiLoader вместо пустого SizedBox (п. 6)
                        loading: () => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: KaiLoader(label: context.s('loading.generic')),
                          ),
                        ),
                        error: (err, st) => Text(
                          context.s('error.generic').replaceFirst('{err}', '$err'),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Заголовок секции записей
                      Text(
                        context.s('water.logs_section'),
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),

                      if (logs.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              context.s('water.no_logs'),
                              style: textTheme.bodyMedium?.copyWith(
                                color: ext.textMuted,
                              ),
                            ),
                          ),
                        )
                      else
                        ...logs.map(
                          (log) => _buildWaterLogCard(
                            context,
                            log,
                            textTheme,
                            ext,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // KaiLoader заменяет CircularProgressIndicator (п. 6)
              loading: () => Center(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: KaiLoader(label: context.s('loading.water')),
                ),
              ),
              error: (err, st) => Center(
                child: Text(context.s('error.generic').replaceFirst('{err}', '$err')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Три мини-карточки: всего / цель / статус.
  Widget _buildStatsSection(
    BuildContext context,
    int total,
    int waterGoal,
    TextTheme textTheme,
    FocusThemeExtension ext,
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

  /// Карточка одной записи воды (время + объём).
  Widget _buildWaterLogCard(
    BuildContext context,
    WaterLogsTableData log,
    TextTheme textTheme,
    FocusThemeExtension ext,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // surface — первый уровень подъёма; без хардкода
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ext.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Locale-aware короткая дата (MMMd: «Jun 24» / «24 июн.»)
              Text(
                DateFormat.MMMd().format(log.loggedAt),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              // Метаданные — bodySmall + textMuted
              Text(
                _formatTime(log.loggedAt),
                style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
              ),
            ],
          ),
          // Объём выпитого — titleMedium (не жирный bold, читается чётче)
          Text(
            '${log.amountMl} ml',
            style: textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Мини-карточка статистики — использует Card ThemeData вместо Container.
class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Метка — bodySmall + textMuted
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 8),
            // Hero-число — displaySmall (32sp, display font, w700)
            Text(
              value,
              style: textTheme.displaySmall,
            ),
          ],
        ),
      ),
    );
  }
}
