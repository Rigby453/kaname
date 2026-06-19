// Провайдеры экрана Plan: режим вида (День/Неделя/Месяц) и реактивный
// диапазон задач для месячного календаря.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';

/// Режим отображения плана.
enum PlanView { day, week, month }

/// Текущий выбранный режим вида. По умолчанию — День (текущее поведение).
final planViewProvider = StateProvider<PlanView>((ref) => PlanView.day);

/// Задачи в диапазоне [from, to) реактивно. Ключ — запись (from, to)
/// (записи в Dart 3 имеют value-equality, поэтому годятся как family-ключ).
final rangeItemsProvider = StreamProvider.autoDispose
    .family<List<ItemsTableData>, (DateTime, DateTime)>((ref, range) {
  return ref.watch(itemsDaoProvider).watchItemsInRange(range.$1, range.$2);
});

/// Видимость строки поиска на экране Plan.
final planSearchVisibleProvider = StateProvider<bool>((ref) => false);

/// Текущий поисковый запрос на экране Plan.
final planSearchQueryProvider = StateProvider<String>((ref) => '');

/// Ближайший будущий экзамен или дедлайн (закреплённая карточка Plan).
/// Реактивно смотрит задачи на [сегодня, сегодня + 365 дней).
/// Возвращает null, если нет ни одного предстоящего exam/deadline.
final nearestExamDeadlineProvider =
    StreamProvider.autoDispose<ItemsTableData?>((ref) {
  final now = DateTime.now();
  // Ищем от начала сегодняшнего дня, чтобы «сегодня» тоже показывалось.
  final from = DateTime.utc(now.year, now.month, now.day);
  final to = from.add(const Duration(days: 365));
  return ref
      .watch(itemsDaoProvider)
      .watchItemsInRange(from, to)
      .map((items) {
    // Отбираем только exam/deadline, ближайший по scheduledAt.
    final urgent = items
        .where((i) => i.type == 'exam' || i.type == 'deadline')
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return urgent.isEmpty ? null : urgent.first;
  });
});
