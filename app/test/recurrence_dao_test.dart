// Юнит-тесты DAO-операций повторов: materializeOccurrence / stopSeries и того,
// что concrete-запросы исключают якоря серий. In-memory Drift, чистый Dart.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/items_dao.dart';
import 'package:app/core/database/daos/subtasks_dao.dart';
import 'package:app/features/plan/recurrence.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ItemsDao dao;
  late SubtasksDao subtasksDao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ItemsDao(db);
    subtasksDao = SubtasksDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> insertAnchor({
    required DateTime scheduledAt,
    required String rule,
    String title = 'Standup',
  }) async {
    final id = 'anchor-${scheduledAt.millisecondsSinceEpoch}';
    final now = DateTime.now();
    await dao.insertItem(ItemsTableCompanion(
      id: Value(id),
      userId: const Value('local'),
      title: Value(title),
      type: const Value('task'),
      priority: const Value('medium'),
      status: const Value('pending'),
      scheduledAt: Value(scheduledAt),
      durationMinutes: const Value(30),
      isProtected: const Value(false),
      recurrenceRule: Value(rule),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    return id;
  }

  test('watchTodayItems excludes anchor rows; watchSeriesAnchors returns them',
      () async {
    // Якорь на полдень сегодня (UTC-окно watchTodayItems).
    final today = DateTime.now();
    final at = DateTime.utc(today.year, today.month, today.day, 12);
    await insertAnchor(scheduledAt: at, rule: 'FREQ=DAILY');

    final concrete = await dao.watchTodayItems(today).first;
    expect(concrete, isEmpty, reason: 'anchor must not show as a concrete task');

    final anchors = await dao.watchSeriesAnchors().first;
    expect(anchors.length, 1);
  });

  test('materializeOccurrence inserts concrete row and adds EXDATE', () async {
    final anchorId = await insertAnchor(
      scheduledAt: DateTime(2026, 6, 22, 9, 0),
      rule: 'FREQ=DAILY',
    );
    final day = DateTime(2026, 6, 23);

    final newId =
        await dao.materializeOccurrence(anchorId, day, status: 'done');
    expect(newId, isNotNull);

    // Concrete-строка создана, не серия, status=done, время-суток из якоря.
    final concrete = await dao.getItemById(newId!);
    expect(concrete, isNotNull);
    expect(concrete!.recurrenceRule, isNull);
    expect(concrete.status, 'done');
    expect(concrete.scheduledAt, DateTime(2026, 6, 23, 9, 0));

    // Якорь получил EXDATE на эту дату.
    final anchor = await dao.getItemById(anchorId);
    final rule = RecurrenceRule.parse(anchor!.recurrenceRule)!;
    expect(rule.exDates.contains(DateTime(2026, 6, 23)), isTrue);
    // occursOn на этот день теперь false (день материализован).
    expect(occursOn(rule, anchor.scheduledAt, day), isFalse);
  });

  test('materializeOccurrence applies field overrides', () async {
    final anchorId = await insertAnchor(
      scheduledAt: DateTime(2026, 6, 22, 9, 0),
      rule: 'FREQ=DAILY',
    );
    final newId = await dao.materializeOccurrence(
      anchorId,
      DateTime(2026, 6, 24),
      title: 'Edited',
      durationMinutes: 90,
      scheduledAt: DateTime(2026, 6, 24, 15, 30),
    );
    final row = await dao.getItemById(newId!);
    expect(row!.title, 'Edited');
    expect(row.durationMinutes, 90);
    expect(row.scheduledAt, DateTime(2026, 6, 24, 15, 30));
  });

  test('materializeOccurrence returns null for non-series id', () async {
    // Обычная задача (без правила) — не серия.
    final now = DateTime.now();
    await dao.insertItem(ItemsTableCompanion(
      id: const Value('plain'),
      userId: const Value('local'),
      title: const Value('x'),
      type: const Value('task'),
      priority: const Value('medium'),
      status: const Value('pending'),
      scheduledAt: Value(now),
      durationMinutes: const Value(30),
      isProtected: const Value(false),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    final res = await dao.materializeOccurrence('plain', now);
    expect(res, isNull);
  });

  test(
      'materializeOccurrence копирует подзадачи-шаблон якоря в новый день; '
      'копии независимы от якоря и сохраняют done шаблона', () async {
    final anchorId = await insertAnchor(
      scheduledAt: DateTime(2026, 6, 22, 9, 0),
      rule: 'FREQ=DAILY',
    );
    // Шаблон серии: две подзадачи на якоре.
    final tplA = await subtasksDao.addSubtask(anchorId, 'Warm up');
    await subtasksDao.addSubtask(anchorId, 'Cool down');
    // Помечаем одну в шаблоне done — материализация ДОЛЖНА сохранить done
    // шаблона (баг 7), чтобы превью прогресса дня не расходилось с реальностью.
    await subtasksDao.setDone(tplA, true);

    final newId = await dao.materializeOccurrence(
      anchorId,
      DateTime(2026, 6, 23),
    );
    expect(newId, isNotNull);

    // У concrete-строки своя копия: те же тексты/порядок, новые id, done из шаблона.
    final copied = await subtasksDao.getSubtasks(newId!);
    expect(copied.map((s) => s.title).toList(), ['Warm up', 'Cool down']);
    expect(copied.firstWhere((s) => s.title == 'Warm up').done, isTrue,
        reason: 'done шаблона сохраняется при материализации (превью не врёт)');
    expect(copied.firstWhere((s) => s.title == 'Cool down').done, isFalse,
        reason: 'не-выполненная подзадача шаблона остаётся не-выполненной');
    final anchorSubs = await subtasksDao.getSubtasks(anchorId);
    final anchorIds = anchorSubs.map((s) => s.id).toSet();
    for (final c in copied) {
      expect(anchorIds.contains(c.id), isFalse,
          reason: 'копия должна иметь новый uuid, не совпадающий с шаблоном');
      expect(c.itemId, newId, reason: 'itemId копии = id concrete-строки');
    }

    // Переопределение дня не влияет на шаблон якоря и наоборот.
    await subtasksDao.setDone(copied.first.id, true);
    await subtasksDao.removeSubtask(copied.last.id);

    final anchorAfter = await subtasksDao.getSubtasks(anchorId);
    expect(anchorAfter, hasLength(2),
        reason: 'шаблон якоря не изменился после правки дня');
    expect(anchorAfter.firstWhere((s) => s.id == tplA).done, isTrue,
        reason: 'done якоря не затронут');
  });

  test(
      'materializeOccurrence идемпотентна по (anchorId, date): повторный вызов '
      'не создаёт второй concrete-строки, а применяет статус к существующей',
      () async {
    final anchorId = await insertAnchor(
      scheduledAt: DateTime(2026, 6, 22, 9, 0),
      rule: 'FREQ=DAILY',
    );
    final day = DateTime(2026, 6, 23);

    // Первый свайп: материализуем день как pending (как snooze/skip/done путь).
    final firstId = await dao.materializeOccurrence(anchorId, day);
    expect(firstId, isNotNull);

    // Второй (быстрый повторный) свайп на ту же дату — теперь со статусом done.
    final secondId =
        await dao.materializeOccurrence(anchorId, day, status: 'done');

    // Вернулся id ТОЙ ЖЕ строки (не создана вторая concrete-строка).
    expect(secondId, firstId);

    // В БД ровно одна concrete-строка на этот день, и её статус обновлён.
    final dayStart = DateTime(2026, 6, 23);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final concrete = await dao.itemsInRange(dayStart, dayEnd);
    expect(concrete, hasLength(1),
        reason: 'повторная материализация не должна плодить дубли');
    expect(concrete.single.status, 'done');
  });

  test(
      'materializeOccurrence: если день в EXDATE, но concrete-строка удалена — '
      'не материализуем заново (день осознанно исключён)', () async {
    final anchorId = await insertAnchor(
      scheduledAt: DateTime(2026, 6, 22, 9, 0),
      rule: 'FREQ=DAILY',
    );
    final day = DateTime(2026, 6, 23);
    final firstId = await dao.materializeOccurrence(anchorId, day);
    await dao.deleteItem(firstId!);

    // Повторный вызов на исключённую дату без живой concrete-строки → null.
    final res = await dao.materializeOccurrence(anchorId, day, status: 'done');
    expect(res, isNull);
  });

  test('cloneWeekEvents НЕ дублирует серию (исключает якоря recurrenceRule!=null)',
      () async {
    // Неделя: понедельник 2026-06-22 .. 2026-06-29 (UTC-полночь как в DAO).
    final weekStart = DateTime.utc(2026, 6, 22);
    // Якорь серии внутри недели.
    await insertAnchor(
      scheduledAt: DateTime.utc(2026, 6, 23, 9, 0),
      rule: 'FREQ=DAILY',
      title: 'Series anchor',
    );
    // Обычная (не-серийная) задача внутри недели.
    final now = DateTime.now();
    await dao.insertItem(ItemsTableCompanion(
      id: const Value('plain-1'),
      userId: const Value('local'),
      title: const Value('Plain task'),
      type: const Value('task'),
      priority: const Value('medium'),
      status: const Value('pending'),
      scheduledAt: Value(DateTime.utc(2026, 6, 24, 10, 0)),
      durationMinutes: const Value(30),
      isProtected: const Value(false),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    final cloned = await dao.cloneWeekEvents(weekStart);
    // Клонируется только обычная задача; якорь серии пропущен.
    expect(cloned, 1, reason: 'якорь серии не клонируется (иначе дубль серии)');

    // Проверяем: на следующей неделе нет второй серии (anchors всё ещё один).
    final anchors = await dao.watchSeriesAnchors().first;
    expect(anchors, hasLength(1),
        reason: 'клонирование недели не должно создавать вторую серию');
  });

  test(
      'watchOverduePending показывает только type=task; '
      'event/deadline/exam исключаются', () async {
    // Просрочка: раньше начала сегодняшнего дня (локальная полночь), pending.
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final overdueAt = todayStart.subtract(const Duration(hours: 3));

    Future<void> insertOverdue(String id, String type) {
      return dao.insertItem(ItemsTableCompanion(
        id: Value(id),
        userId: const Value('local'),
        title: Value(type),
        type: Value(type),
        priority: const Value('medium'),
        status: const Value('pending'),
        scheduledAt: Value(overdueAt),
        durationMinutes: const Value(30),
        isProtected: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));
    }

    await insertOverdue('o-task', 'task');
    await insertOverdue('o-event', 'event');
    await insertOverdue('o-deadline', 'deadline');
    await insertOverdue('o-exam', 'exam');

    final overdue = await dao.watchOverduePending(DateTime.now()).first;
    expect(overdue.map((i) => i.id).toList(), ['o-task'],
        reason: 'только незавершённую ЗАДАЧУ предлагаем к переносу; '
            'событие/дедлайн/экзамен привязаны ко времени и исключены');
  });

  test('stopSeries sets UNTIL to day before given day', () async {
    final anchorId = await insertAnchor(
      scheduledAt: DateTime(2026, 6, 1, 9, 0),
      rule: 'FREQ=DAILY',
    );
    final ok = await dao.stopSeries(anchorId, DateTime(2026, 6, 22));
    expect(ok, isTrue);

    final anchor = await dao.getItemById(anchorId);
    final rule = RecurrenceRule.parse(anchor!.recurrenceRule)!;
    expect(rule.until, DateTime(2026, 6, 21));
    // Сегодня и далее — повторов нет; прошлое (до 21-го включительно) — есть.
    expect(occursOn(rule, anchor.scheduledAt, DateTime(2026, 6, 21)), isTrue);
    expect(occursOn(rule, anchor.scheduledAt, DateTime(2026, 6, 22)), isFalse);
  });
}
