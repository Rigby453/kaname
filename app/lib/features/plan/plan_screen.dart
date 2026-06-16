// FL-PLAN: Экран Plan — переключатель День/Неделя/Месяц.
// - День: недельная полоса + таймлайн выбранного дня (исходное поведение).
// - Неделя: повестка из 7 дней.
// - Месяц: календарная сетка с точками на днях с задачами.
// AppBar даёт общая оболочка ScaffoldWithNavBar; здесь вложенный Scaffold
// нужен только ради FAB. Добавление задачи переиспользует showAddTaskSheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../import/import_sheet.dart';
import '../today/widgets/add_task_sheet.dart';
import 'widgets/day_timeline.dart';
import 'widgets/month_view.dart';
import 'widgets/plan_providers.dart';
import 'widgets/week_agenda.dart';
import 'widgets/week_strip.dart';

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  /// Форматирует выбранную дату: «Today», «Yesterday», или «15 Jun».
  String _formatSelectedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    // Год показываем только если не текущий
    if (date.year == now.year) return DateFormat('d MMM').format(date);
    return DateFormat('d MMM y').format(date);
  }

  /// Открывает DatePicker и переключает выбранный день.
  Future<void> _pickDate(DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
    );
    if (picked != null && mounted) {
      ref.read(selectedDayProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(selectedDayProvider);
    final view = ref.watch(planViewProvider);
    final searchVisible = ref.watch(planSearchVisibleProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddTaskSheet(context, day: selectedDay),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Переключатель вида + поиск + импорт
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SegmentedButton<PlanView>(
                  segments: const [
                    ButtonSegment(value: PlanView.day, label: Text('Day')),
                    ButtonSegment(value: PlanView.week, label: Text('Week')),
                    ButtonSegment(value: PlanView.month, label: Text('Month')),
                  ],
                  selected: {view},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      ref.read(planViewProvider.notifier).state = s.first,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Кнопка «Today» — видна только когда выбран не сегодня
                    Builder(builder: (ctx) {
                      final now = DateTime.now();
                      final today =
                          DateTime(now.year, now.month, now.day);
                      if (selectedDay != today) {
                        return TextButton(
                          onPressed: () {
                            ref.read(selectedDayProvider.notifier).state =
                                today;
                          },
                          child: const Text('Today'),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    // Тап на дату открывает DatePicker (быстрый переход к любой дате)
                    GestureDetector(
                      onTap: () => _pickDate(selectedDay),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatSelectedDate(selectedDay),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color:
                                  Theme.of(context).colorScheme.onSurface,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Иконка поиска (только в режиме Day)
                    if (view == PlanView.day)
                      IconButton(
                        icon: Icon(
                          searchVisible
                              ? Icons.search_off
                              : Icons.search,
                        ),
                        tooltip: 'Search tasks',
                        onPressed: () {
                          final notifier =
                              ref.read(planSearchVisibleProvider.notifier);
                          notifier.state = !notifier.state;
                          if (notifier.state == false) {
                            // Сбрасываем запрос при закрытии
                            ref.read(planSearchQueryProvider.notifier).state =
                                '';
                          }
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.flag_outlined),
                      tooltip: 'Long-term goals',
                      onPressed: () => context.push('/goals'),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.upload_file_outlined, size: 18),
                      label: const Text('Import'),
                      onPressed: () =>
                          showImportSheet(context, day: selectedDay),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Строка поиска (разворачивается при searchVisible в режиме Day)
          if (view == PlanView.day && searchVisible)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: _SearchField(
                onChanged: (v) =>
                    ref.read(planSearchQueryProvider.notifier).state = v,
              ),
            ),
          const Divider(height: 1),
          Expanded(child: _body(view)),
        ],
      ),
    );
  }

  Widget _body(PlanView view) {
    switch (view) {
      case PlanView.month:
        return const MonthView();
      case PlanView.week:
        return const Column(
          children: [
            WeekStrip(),
            Divider(height: 1),
            Expanded(child: WeekAgenda()),
          ],
        );
      case PlanView.day:
        return const Column(
          children: [
            WeekStrip(),
            Divider(height: 1),
            Expanded(child: DayTimeline()),
          ],
        );
    }
  }
}

/// Поле ввода поискового запроса с иконкой очистки.
class _SearchField extends StatefulWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search tasks…',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
              )
            : null,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onChanged: (v) {
        setState(() {}); // обновляем suffixIcon
        widget.onChanged(v);
      },
    );
  }
}
