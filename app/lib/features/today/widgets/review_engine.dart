// Общая логика разбора (carry-over + варианты раскладки), используется и
// утренним (перенос вчерашнего на сегодня), и вечерним (план на завтра)
// разборами. Чистые функции + помощники записи в Drift. AI-варианты приходят
// с бэкенда (/ai/redistribute) и маппятся в тот же PlanVariant.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';

/// Вариант раскладки: подпись, обоснование и карта itemId → новое время.
class PlanVariant {
  const PlanVariant(this.label, this.reason, this.assign);
  final String label;
  final String reason;
  final Map<String, DateTime> assign;
}

int priorityWeight(String p) => switch (p) {
      'main' => 4,
      'high' => 3,
      'medium' => 2,
      _ => 1,
    };

String slotKey(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${(t.minute < 30 ? 0 : 30).toString().padLeft(2, '0')}';

/// Свободные 30-минутные слоты дня [day] (08:00–22:00), кроме занятых.
List<DateTime> freeSlots(DateTime day, Set<String> occupied) {
  final slots = <DateTime>[];
  for (var h = 8; h < 22; h++) {
    for (final m in [0, 30]) {
      final key =
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      if (!occupied.contains(key)) {
        slots.add(DateTime(day.year, day.month, day.day, h, m));
      }
    }
  }
  return slots;
}

PlanVariant? _assign(
  String label,
  String reason,
  List<ItemsTableData> movable,
  List<DateTime> slots,
) {
  if (slots.isEmpty) return null;
  final map = <String, DateTime>{};
  for (var i = 0; i < movable.length && i < slots.length; i++) {
    map[movable[i].id] = slots[i];
  }
  if (map.isEmpty) return null;
  return PlanVariant(label, reason, map);
}

/// 2–3 варианта раскладки [candidates] в свободные слоты дня [day].
/// [dayItems] — уже запланированное на [day] (для вычисления занятых слотов).
/// Защищённые (is_protected) задачи не двигаются.
List<PlanVariant> buildVariants(
  List<ItemsTableData> candidates,
  List<ItemsTableData> dayItems,
  DateTime day,
) {
  final movable = candidates.where((i) => !i.isProtected).toList()
    ..sort((a, b) => priorityWeight(b.priority) - priorityWeight(a.priority));
  if (movable.isEmpty) return [];

  final occupied = dayItems.map((i) => slotKey(i.scheduledAt)).toSet();
  final free = freeSlots(day, occupied);
  if (free.isEmpty) return [];

  // Метки и обоснования — ключи локализации; разрешаются в ReviewVariantCard.
  final variants = <PlanVariant?>[
    _assign(
        'variant.frontloaded', 'variant.frontloaded_reason', movable, free),
    _assign('variant.spread_out', 'variant.spread_out_reason', movable,
        [for (var i = 0; i < free.length; i += 2) free[i]]),
    _assign('variant.afternoon_start', 'variant.afternoon_start_reason',
        movable, free.where((s) => s.hour >= 14).toList()),
  ];
  return variants.whereType<PlanVariant>().toList();
}

/// Перенести задачу на день [day], сохранив время суток.
Future<void> moveToDay(WidgetRef ref, ItemsTableData item, DateTime day) async {
  final now = DateTime.now();
  final newAt = DateTime(
    day.year,
    day.month,
    day.day,
    item.scheduledAt.hour,
    item.scheduledAt.minute,
  );
  await ref.read(itemsDaoProvider).updateItem(
        item.id,
        ItemsTableCompanion(
          scheduledAt: Value(newAt),
          updatedAt: Value(now),
        ),
      );
}

/// Считаем, что у задачи «есть своё время суток», если оно не совпадает с
/// началом дня (полночь). Задачи без времени создаются на 00:00 локально —
/// если перенести их «сохранив время суток», все они сольются в одну точку.
bool _hasTimeOfDay(DateTime t) => t.hour != 0 || t.minute != 0;

/// Чистая раскладка пачки [items] на день [day] так, чтобы их scheduledAt НЕ
/// накладывались в одну точку. Возвращает карту itemId → новое время.
///
/// Правила:
/// - Защищённые (is_protected) и main-задачи со своим временем суток —
///   сохраняем их час:минуту, меняем только дату; такие слоты «забронированы»
///   и не переиспользуются другими задачами.
/// - Остальные задачи со своим временем суток встают на это же время, если
///   слот ещё свободен; иначе — в следующий свободный слот сетки.
/// - Задачи без времени (00:00) распределяются по последовательным свободным
///   30-минутным слотам дня (08:00–22:00), начиная с первого свободного.
/// [dayItems] — уже запланированное на [day] (для занятых слотов).
Map<String, DateTime> distributeToDay(
  List<ItemsTableData> items,
  DateTime day,
  List<ItemsTableData> dayItems,
) {
  final assign = <String, DateTime>{};
  // Занятые слоты: то, что уже стоит на дне, плюс то, что назначаем по ходу.
  final occupied = dayItems.map((i) => slotKey(i.scheduledAt)).toSet();

  DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);

  // 1) Сначала закрепляем «якорные» задачи (protected/main) с собственным
  //    временем суток — их слоты приоритетны и не уступаются.
  final flexible = <ItemsTableData>[];
  for (final item in items) {
    final keepTime = (item.isProtected || item.priority == 'main') &&
        _hasTimeOfDay(item.scheduledAt);
    if (keepTime) {
      final newAt = at(item.scheduledAt.hour, item.scheduledAt.minute);
      assign[item.id] = newAt;
      occupied.add(slotKey(newAt));
    } else {
      flexible.add(item);
    }
  }

  // 2) Гибкие задачи. Со своим временем — пробуем сохранить его; без времени
  //    или при коллизии — следующий свободный слот сетки. Сортируем по
  //    приоритету, чтобы более важные занимали более ранние слоты при сливе.
  flexible.sort(
    (a, b) => priorityWeight(b.priority) - priorityWeight(a.priority),
  );
  final slots = freeSlots(day, occupied); // свободные 30-мин слоты по порядку
  var nextSlot = 0;

  DateTime takeNextFreeSlot() {
    while (nextSlot < slots.length && occupied.contains(slotKey(slots[nextSlot]))) {
      nextSlot++;
    }
    if (nextSlot < slots.length) {
      final s = slots[nextSlot];
      nextSlot++;
      occupied.add(slotKey(s));
      return s;
    }
    // Слоты дня закончились — кладём в конец дня с шагом 30 мин после 22:00,
    // чтобы задачи всё равно не наложились друг на друга.
    final overflow = at(22, 0).add(Duration(minutes: 30 * (assign.length)));
    occupied.add(slotKey(overflow));
    return overflow;
  }

  for (final item in flexible) {
    if (_hasTimeOfDay(item.scheduledAt)) {
      final desired = at(item.scheduledAt.hour, item.scheduledAt.minute);
      if (!occupied.contains(slotKey(desired))) {
        assign[item.id] = desired;
        occupied.add(slotKey(desired));
        continue;
      }
    }
    assign[item.id] = takeNextFreeSlot();
  }

  return assign;
}

/// Перенести ПАЧКУ задач на день [day], распределив по разным слотам
/// (не сваливая в одну точку). [dayItems] — уже запланированное на [day].
Future<void> moveAllToDay(
  WidgetRef ref,
  List<ItemsTableData> items,
  DateTime day,
  List<ItemsTableData> dayItems,
) async {
  final assign = distributeToDay(items, day, dayItems);
  final dao = ref.read(itemsDaoProvider);
  final now = DateTime.now();
  for (final entry in assign.entries) {
    await dao.updateItem(
      entry.key,
      ItemsTableCompanion(
        scheduledAt: Value(entry.value),
        updatedAt: Value(now),
      ),
    );
  }
}

/// Применить вариант: переносим задачи на назначенное время (локально, Drift).
Future<void> applyVariant(WidgetRef ref, PlanVariant variant) async {
  final dao = ref.read(itemsDaoProvider);
  final now = DateTime.now();
  for (final entry in variant.assign.entries) {
    await dao.updateItem(
      entry.key,
      ItemsTableCompanion(
        scheduledAt: Value(entry.value),
        updatedAt: Value(now),
      ),
    );
  }
}

/// Ответ /ai/redistribute (plans:[{label, reason, items:[{id, scheduled_at}]}])
/// → список PlanVariant. scheduled_at (ISO 8601) приводим к локальному времени.
List<PlanVariant> mapAiPlans(List<dynamic> raw) {
  final result = <PlanVariant>[];
  for (final p in raw) {
    if (p is! Map) continue;
    final assign = <String, DateTime>{};
    final items = p['items'];
    if (items is List) {
      for (final it in items) {
        if (it is! Map) continue;
        final id = it['id'] as String?;
        final at = it['scheduled_at'] as String?;
        if (id == null || at == null) continue;
        final dt = DateTime.tryParse(at);
        if (dt != null) assign[id] = dt.toLocal();
      }
    }
    if (assign.isEmpty) continue;
    result.add(PlanVariant(
      (p['label'] as String?) ?? 'AI plan',
      (p['reason'] as String?) ?? '',
      assign,
    ));
  }
  return result;
}
