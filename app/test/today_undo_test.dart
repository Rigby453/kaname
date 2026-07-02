// today_undo_test.dart
// Было: регресс-тест Defect 1 «Undo после выполнения задачи не возвращает
// задачу в список». Кнопка Undo убрана из приложения целиком (2026-07, см.
// docs/decisions.md) — вместо неё для необратимого удаления «дорогого»
// контента используется confirm-диалог ДО удаления (см. test/undo_removal_test.dart).
//
// Этот файл теперь проверяет базовый happy-path свайпа (done/skip), который
// раньше был обёрнут в те же сценарии: свайп вправо → тост «done» БЕЗ кнопки
// Undo, статус в БД становится done — и остаётся done (отменить нечем).
//
// Паттерн свайпа и тайминга — точная копия interaction_smoke_test.dart
// (drag → pump → runAsync(100ms) → pump(300ms)).
// Прямая проверка DB через runAsync (stream-обновление в real-async зоне
// ненадёжно для UI-ассерта в fake-async тесте).
//
// Без pumpAndSettle (deadlock guard).

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/core/utils/id.dart';
import 'package:app/features/plan/widgets/recurrence_providers.dart'
    show expandedDayItemsProvider;
import 'package:app/features/today/widgets/task_list.dart';
import 'package:app/services/notifications/notification_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// No-op NotificationService для тестов
// ---------------------------------------------------------------------------

class _NoopNotificationService extends NotificationService {
  _NoopNotificationService() : super(FlutterLocalNotificationsPlugin());

  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<void> scheduleDailyReviews(
      {int morningHour = 8, int eveningHour = 20}) async {}
  @override
  Future<void> schedulePostureReminders() async {}
  @override
  Future<void> cancelPostureReminders() async {}
  @override
  Future<void> cancelAll() async {}
  @override
  Future<void> scheduleTaskReminder(
      String itemId, String title, DateTime fireAt) async {}
  @override
  Future<void> cancelTaskReminder(String itemId) async {}
  @override
  Future<void> refreshTimezone() async {}
}

// ---------------------------------------------------------------------------
// Реактивная обёртка TaskList: следит за expandedDayItemsProvider
// ---------------------------------------------------------------------------

class _ReactiveTaskList extends ConsumerWidget {
  const _ReactiveTaskList({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(expandedDayItemsProvider(day)).valueOrNull ?? const [];
    return TaskList(items: items, day: day);
  }
}

// ---------------------------------------------------------------------------
// Тестовая тема (FocusThemeExtension обязателен для TaskCard)
// ---------------------------------------------------------------------------

ThemeData _testTheme() => ThemeData.dark().copyWith(
      extensions: const [
        FocusThemeExtension(
          textMuted: Color(0xFF9E9070),
          ember: Color(0xFFFF6A3D),
          border: Color(0xFF3A3020),
          surfaceElevated: Color(0xFF2E2618),
          textFaint: Color(0xFF736850),
          accentMuted: Color(0xFF26290F),
          success: Color(0xFF4BAF6F),
          borderStrong: Color(0xFF524630),
        ),
      ],
    );

// ---------------------------------------------------------------------------
// Общий харнесс
// ---------------------------------------------------------------------------

class _Harness {
  _Harness({required this.db, required this.prefs, required this.notif});

  final AppDatabase db;
  final SharedPreferences prefs;
  final _NoopNotificationService notif;

  Widget wrap(Widget child, {double width = 390}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(notif),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: MaterialApp(
          theme: _testTheme(),
          localizationsDelegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Вспомогательные функции
// ---------------------------------------------------------------------------

Future<String> _insertPendingTask(
  WidgetTester tester,
  AppDatabase db, {
  String? id,
  required String title,
  String priority = 'medium',
  String? recurrenceRule,
  required DateTime scheduledAt,
}) async {
  final taskId = id ?? uuidV4();
  await tester.runAsync(() async {
    await db.into(db.itemsTable).insert(
          ItemsTableCompanion(
            id: Value(taskId),
            userId: const Value('local'),
            title: Value(title),
            type: const Value('task'),
            priority: Value(priority),
            status: const Value('pending'),
            scheduledAt: Value(scheduledAt),
            durationMinutes: const Value(30),
            isProtected: const Value(false),
            recurrenceRule: Value(recurrenceRule),
            createdAt: Value(scheduledAt),
            updatedAt: Value(scheduledAt),
          ),
        );
  });
  return taskId;
}

/// Settle без pumpAndSettle (избегаем дедлока с Drift-стримом).
/// Копия паттерна из interaction_smoke_test.dart.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 600));
}

/// Размонтирование для очистки Drift-таймеров после теста.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 10));
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late _Harness harness;
  late _NoopNotificationService notif;

  // Тестовый день: 26 июня 2026.
  final testDay = DateTime(2026, 6, 26);
  // scheduledAt: 09:00 того же дня — внутри окна watchTodayItems(testDay).
  final testAt = DateTime(2026, 6, 26, 9, 0);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({
      // seen_swipe_hint=true → TaskList не запускает nudge-анимацию.
      'seen_swipe_hint': true,
      // completion_sound_enabled=false → не пытаемся играть звук через
      // audioplayers platform channel (нет в headless-тестах).
      'completion_sound_enabled': false,
      // Дефолты свайпа: вправо = done (SwipeAction.done).
    });
    prefs = await SharedPreferences.getInstance();
    notif = _NoopNotificationService();
    harness = _Harness(db: db, prefs: prefs, notif: notif);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // A. Обычная задача: done → тост БЕЗ Undo → статус остаётся done
  // ─────────────────────────────────────────────────────────────────────────
  group('Swipe done — обычная задача (без Undo)', () {
    testWidgets(
        'после свайпа задача становится done, тост без кнопки Undo, статус не откатывается',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Вставляем pending задачу.
      await _insertPendingTask(tester, db,
          title: 'Regular Task', scheduledAt: testAt);

      // Pump реактивного списка.
      await tester.pumpWidget(
        harness.wrap(_ReactiveTaskList(day: testDay)),
      );
      await _settle(tester);

      // Задача видна в pending-секции.
      expect(find.text('Regular Task'), findsOneWidget);

      // Свайп вправо (startToEnd) → done.
      // Тайминг: паттерн interaction_smoke_test.dart §6.
      await tester.drag(find.text('Regular Task'), const Offset(500, 0));
      await tester.pump(); // ← обязательно: обрабатывает DragEnd → confirmDismiss
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));

      // Тост появляется, БЕЗ кнопки Undo (убрана — 2026-07).
      expect(find.text('Undo'), findsNothing);

      // DB: задача done (отменить нечем — Undo убран).
      final rows = await tester.runAsync(
          () async => db.select(db.itemsTable).get());
      final task = rows!.singleWhere((r) => r.title == 'Regular Task');
      expect(task.status, 'done');

      // Прокачиваем таймер автоскрытия тоста (3.5с).
      await tester.pump(const Duration(seconds: 4));

      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // B. Виртуальный повтор серии: done материализует concrete-строку
  // ─────────────────────────────────────────────────────────────────────────
  group('Swipe done — виртуальный повтор (без Undo)', () {
    testWidgets(
        'виртуальное вхождение материализуется в done, EXDATE не трогается (нет отката)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Вставляем якорь серии FREQ=DAILY, начало = testDay.
      final anchorId = await _insertPendingTask(
        tester,
        db,
        title: 'Daily Task',
        scheduledAt: testAt,
        recurrenceRule: 'FREQ=DAILY',
      );

      // Pump: expandedDayItemsProvider генерирует виртуальный повтор testDay.
      await tester.pumpWidget(
        harness.wrap(_ReactiveTaskList(day: testDay)),
      );
      await _settle(tester);

      // Виртуальный повтор виден.
      expect(find.text('Daily Task'), findsOneWidget);

      // Свайп вправо → materializeOccurrence(status: done).
      await tester.drag(find.text('Daily Task'), const Offset(500, 0));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));

      // Тост без кнопки Undo.
      expect(find.text('Undo'), findsNothing);

      // DB: якорь + материализованная done-строка (EXDATE проставлен, так как
      // материализация всегда ставит EXDATE — Undo, который бы его снимал,
      // больше не существует).
      final allRows = await tester.runAsync(
          () async => db.select(db.itemsTable).get());
      expect(allRows!.length, 2, reason: 'Якорь + материализованная строка');

      final anchor = allRows.singleWhere((r) => r.id == anchorId);
      expect(anchor.recurrenceRule, isNotNull);
      expect(anchor.recurrenceRule!.contains('EXDATE'), isTrue);

      final materialized = allRows.singleWhere((r) => r.id != anchorId);
      expect(materialized.status, 'done');

      // Прокачиваем таймер тоста.
      await tester.pump(const Duration(seconds: 4));

      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  });
}
