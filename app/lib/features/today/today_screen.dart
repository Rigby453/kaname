// FL-TODAY-01: Экран Today — собирает кольцо прогресса, строку streak,
// список задач и FAB добавления. AppBar даёт общая оболочка ScaffoldWithNavBar,
// поэтому здесь вложенный Scaffold без AppBar (нужен только ради FAB),
// а приветствие и дата вынесены в шапку тела.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../services/widget/widget_service.dart';
import 'widgets/add_task_sheet.dart';
import 'widgets/morning_review_card.dart';
import 'widgets/progress_ring.dart';
import 'widgets/streak_row.dart';
import 'widgets/task_list.dart';

/// Все задачи на сегодня (реактивно из Drift)
final todayItemsProvider =
    StreamProvider.autoDispose<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchTodayItems(DateTime.now());
});

/// Только main-задачи на сегодня — для кольца прогресса
final todayMainItemsProvider =
    StreamProvider.autoDispose<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchMainItems(DateTime.now());
});

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final itemsAsync = ref.watch(todayItemsProvider);
    final mainItems = ref.watch(todayMainItemsProvider).valueOrNull ??
        const <ItemsTableData>[];

    // При изменении main-задач обновляем домашний виджет (Android)
    ref.listen(todayMainItemsProvider, (_, _) {
      refreshHomeWidget(
        itemsDao: ref.read(itemsDaoProvider),
        streakDao: ref.read(streakDaoProvider),
      );
    });

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddTaskSheet(context, day: now),
        child: const Icon(Icons.add),
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load tasks: $err')),
        data: (items) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), // место под FAB
            children: [
              _Header(now: now),
              const SizedBox(height: 16),
              const MorningReviewCard(),
              const SizedBox(height: 8),
              Center(child: ProgressRing(items: mainItems)),
              const SizedBox(height: 24),
              const StreakRow(),
              const SizedBox(height: 24),
              TaskList(items: items, day: now),
            ],
          );
        },
      ),
    );
  }
}

/// Приветствие, зависящее от времени суток, + сегодняшняя дата
class _Header extends StatelessWidget {
  const _Header({required this.now});

  final DateTime now;

  String get _greeting {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_greeting, style: textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          DateFormat.yMMMMEEEEd().format(now),
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }
}
