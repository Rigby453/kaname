// Экран Health — хаб здоровья.
// Рабочий модуль: трекер воды (Phase 1: анимированный бар §4.2 + график
// 7 дней). Остальное (тренировки/сон/дыхание/осанка) — Phase 2, плитки «скоро».

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/app_toast.dart';
import '../../core/animations/constants.dart';
import '../../core/database/database_providers.dart';
import '../../core/settings/water_goal_provider.dart';

/// Сумма выпитого за сегодня (реактивно).
final todayWaterProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(waterDaoProvider).watchTodayTotalMl(DateTime.now());
});

/// Суммы по дням за последние 7 дней (индекс 6 — сегодня), реактивно.
final weekWaterProvider = StreamProvider.autoDispose<List<int>>((ref) {
  return ref.watch(waterDaoProvider).watchDailyTotals(DateTime.now(), 7);
});

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  static const _comingSoon = [
    (Icons.fitness_center, 'Workouts'),
    (Icons.bedtime_outlined, 'Sleep'),
    (Icons.air, 'Breathing'),
    (Icons.self_improvement, 'Posture'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final total = ref.watch(todayWaterProvider).valueOrNull ?? 0;
    // Норма из настроек (онбординг-шаг «нормы»; по умолчанию 2000 мл)
    final waterGoalMl = ref.watch(waterGoalProvider);
    final progress = (total / waterGoalMl).clamp(0.0, 1.0);
    final dao = ref.read(waterDaoProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Health', style: textTheme.headlineMedium),
        const SizedBox(height: 16),

        // --- Трекер воды ---
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.water_drop, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Water', style: textTheme.titleMedium),
                    const Spacer(),
                    Text('$total / $waterGoalMl ml', style: textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                _AnimatedWaterBar(progress: progress),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.local_drink, size: 18),
                        label: const Text('+250 ml'),
                        onPressed: () => dao.addWater(250),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.sports_bar, size: 18),
                        label: const Text('+500 ml'),
                        onPressed: () => dao.addWater(500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Undo',
                      icon: const Icon(Icons.undo),
                      onPressed: () => dao.undoLast(DateTime.now()),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // График: последние 7 дней относительно нормы
                _WeekWaterChart(goalMl: waterGoalMl),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // --- Еда ---
        Card(
          child: ListTile(
            leading: Icon(Icons.restaurant_outlined, color: colorScheme.primary),
            title: const Text('Food'),
            subtitle: const Text('Log meals · KБЖУ from Open Food Facts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/food'),
          ),
        ),
        const SizedBox(height: 16),

        // --- Фокус-сессии ---
        Card(
          child: ListTile(
            leading: Icon(Icons.timer_outlined, color: colorScheme.primary),
            title: const Text('Focus session'),
            subtitle: const Text('25/5 · 50/10 · 67/15 and more'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/focus'),
          ),
        ),
        const SizedBox(height: 24),

        // --- Скоро ---
        Text('More coming soon', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._comingSoon.map((e) {
          final (icon, label) = e;
          return Card(
            child: ListTile(
              leading: Icon(
                icon,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              title: Text(label),
              trailing: Text('soon', style: textTheme.bodySmall),
              enabled: false,
            ),
          );
        }),
      ],
    );
  }
}

/// Прогресс-бар воды — ANIMATIONS.md §4.2: полоса плавно растёт до нового %
/// за 500 мс (easeOutCubic); при достижении 100% через 600 мс — тост.
class _AnimatedWaterBar extends StatefulWidget {
  const _AnimatedWaterBar({required this.progress});

  final double progress;

  @override
  State<_AnimatedWaterBar> createState() => _AnimatedWaterBarState();
}

class _AnimatedWaterBarState extends State<_AnimatedWaterBar> {
  double _prev = 0;

  @override
  void didUpdateWidget(_AnimatedWaterBar old) {
    super.didUpdateWidget(old);
    if (old.progress == widget.progress) return;
    _prev = old.progress;
    // §4.2: норма достигнута → задержка 600 мс → тост
    if (old.progress < 1.0 && widget.progress >= 1.0) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          showAppToast(
            context,
            variant: AppToastVariant.done,
            message: 'Water goal reached 💧',
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 500 мс — точное значение §4.2 (между kDurationSlow и kDurationNormal)
    final duration =
        effectiveDuration(context, const Duration(milliseconds: 500));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _prev, end: widget.progress),
      duration: duration,
      curve: kCurveLift,
      builder: (context, value, _) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 10,
          backgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}

/// Мини-график воды за последние 7 дней (высота столбца — доля от нормы).
class _WeekWaterChart extends ConsumerWidget {
  const _WeekWaterChart({required this.goalMl});

  final int goalMl;

  static const _chartHeight = 56.0;
  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(weekWaterProvider).valueOrNull;
    if (totals == null || totals.length != 7) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final today = DateTime.now();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final day = today.subtract(Duration(days: 6 - i));
        final frac =
            goalMl <= 0 ? 0.0 : (totals[i] / goalMl).clamp(0.0, 1.0);
        final isToday = i == 6;
        final reached = totals[i] >= goalMl && goalMl > 0;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: (_chartHeight * frac).clamp(3.0, _chartHeight),
                  decoration: BoxDecoration(
                    color: reached
                        ? colorScheme.primary
                        : colorScheme.primary.withValues(
                            alpha: isToday ? 0.8 : 0.35,
                          ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _letters[day.weekday - 1],
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isToday
                        ? colorScheme.onSurface
                        : colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
