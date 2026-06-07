// FL-PLAN: Экран Plan — недельная полоса + таймлайн выбранного дня.
// AppBar даёт общая оболочка ScaffoldWithNavBar; здесь вложенный Scaffold
// нужен только ради FAB. Добавление задачи переиспользует showAddTaskSheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../import/import_sheet.dart';
import '../today/widgets/add_task_sheet.dart';
import 'widgets/day_timeline.dart';
import 'widgets/week_strip.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddTaskSheet(context, day: selectedDay),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: TextButton.icon(
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('Import'),
                onPressed: () => showImportSheet(context, day: selectedDay),
              ),
            ),
          ),
          const WeekStrip(),
          const Divider(height: 1),
          const Expanded(child: DayTimeline()),
        ],
      ),
    );
  }
}
