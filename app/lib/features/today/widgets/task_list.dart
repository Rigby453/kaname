// FL-TODAY-04: Список задач дня с двумя секциями.
// - "Main today": задачи priority=main со значком щита.
// - "Later": остальные задачи, по времени.
// Свайп вправо = done (зелёный), свайп влево = skip (серый).
// Тап по задаче открывает лист редактирования.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import 'add_task_sheet.dart';

class TaskList extends ConsumerWidget {
  const TaskList({
    required this.items,
    required this.day,
    super.key,
  });

  /// Все задачи дня (из watchTodayItems), отсортированы по scheduledAt
  final List<ItemsTableData> items;

  /// День, в контексте которого открывается лист редактирования
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'Nothing planned yet.\nTap + to add your first task.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final mainItems = items.where((i) => i.priority == 'main').toList();
    final laterItems = items.where((i) => i.priority != 'main').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mainItems.isNotEmpty) ...[
          _SectionHeader(title: 'Main today'),
          ...mainItems.map((i) => _buildRow(context, ref, i)),
          const SizedBox(height: 16),
        ],
        if (laterItems.isNotEmpty) ...[
          _SectionHeader(title: 'Later'),
          ...laterItems.map((i) => _buildRow(context, ref, i)),
        ],
      ],
    );
  }

  Widget _buildRow(BuildContext context, WidgetRef ref, ItemsTableData item) {
    // Завершённые/пропущенные показываем статичной строкой (без свайпа)
    if (item.status != 'pending') {
      return _TaskCard(item: item, day: day);
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(item.id),
      // Свайп вправо = done
      background: _swipeBg(
        color: Colors.green.withAlpha(40),
        icon: Icons.check,
        iconColor: Colors.green,
        alignment: Alignment.centerLeft,
      ),
      // Свайп влево = skip
      secondaryBackground: _swipeBg(
        color: colorScheme.onSurface.withAlpha(20),
        icon: Icons.remove_circle_outline,
        iconColor: colorScheme.onSurface.withAlpha(140),
        alignment: Alignment.centerRight,
      ),
      // Выполняем действие и возвращаем false: строка не удаляется,
      // а перерисуется с новым статусом из реактивного стрима.
      confirmDismiss: (direction) async {
        final dao = ref.read(itemsDaoProvider);
        if (direction == DismissDirection.startToEnd) {
          await dao.markDone(item.id);
        } else {
          await dao.markSkipped(item.id);
        }
        return false;
      },
      child: _TaskCard(item: item, day: day),
    );
  }

  Widget _swipeBg({
    required Color color,
    required IconData icon,
    required Color iconColor,
    required Alignment alignment,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16), // radius.md
      ),
      child: Icon(icon, color: iconColor),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.item, required this.day});

  final ItemsTableData item;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDone = item.status == 'done';
    final isSkipped = item.status == 'skipped';
    final isCompleted = isDone || isSkipped;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => showAddTaskSheet(context, day: day, existing: item),
        leading: Text(
          DateFormat.Hm().format(item.scheduledAt),
          style: textTheme.labelMedium,
        ),
        title: Text(
          item.title,
          style: textTheme.bodyLarge?.copyWith(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted
                ? colorScheme.onSurface.withAlpha(120)
                : colorScheme.onSurface,
          ),
        ),
        subtitle: Text(item.type, style: textTheme.bodySmall),
        trailing: _trailing(context, colorScheme),
      ),
    );
  }

  Widget? _trailing(BuildContext context, ColorScheme colorScheme) {
    if (item.status == 'done') {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    if (item.status == 'skipped') {
      return Icon(Icons.remove_circle_outline,
          color: colorScheme.onSurface.withAlpha(120));
    }
    // Значок щита для защищённых main-задач
    if (item.priority == 'main') {
      return Icon(Icons.shield_outlined, color: colorScheme.primary, size: 20);
    }
    return null;
  }
}
