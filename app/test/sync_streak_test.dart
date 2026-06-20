// Тесты синхронизации заморозок стрика (ADR-044).
//
// Проверяем:
//   1. Тело POST /sync содержит streak-блок с freeze_count и last_freeze_accrual_at.
//   2. Если нет локальных данных о заморозках — streak-блок не добавляется.
//   3. Ответ сервера с freeze_count записывается в Drift (StreakTable).
//   4. Ответ сервера с last_freeze_accrual_at записывается в SharedPreferences.
//   5. Null-курсор в ответе сервера не затирает локальные данные.
//   6. Если ответ не содержит ключа streak — локальные данные не тронуты.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/streak_dao.dart';
import 'package:app/services/api/api_client.dart';
import 'package:app/services/streak/freeze_accrual_service.dart'
    show kLastFreezeAccrualKey;
import 'package:app/services/sync/sync_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Стаб ApiClient: перехватывает sync(), возвращает настраиваемый ответ.
// ---------------------------------------------------------------------------

class _FakeApiClient extends ApiClient {
  _FakeApiClient(super.prefs);

  /// Последний переданный streak-блок.
  Map<String, dynamic>? capturedStreak;

  /// Настраиваемый ответ на sync().
  Map<String, dynamic> fakeResponse = {};

  @override
  String? get token => 'fake-token';

  @override
  String get lastSyncAt => '1970-01-01T00:00:00.000Z';

  @override
  Future<void> saveLastSyncAt(String isoString) async {}

  @override
  Future<Map<String, dynamic>> sync(
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> waterLogs,
    String lastSyncAt, {
    List<String> deletedItemIds = const [],
    List<Map<String, dynamic>> dayLogs = const [],
    List<Map<String, dynamic>> foodLogs = const [],
    Map<String, dynamic>? streak,
  }) async {
    capturedStreak = streak;
    return fakeResponse;
  }
}

// ---------------------------------------------------------------------------
// Хелпер: создать SyncService с in-memory Drift + fake ApiClient.
// ---------------------------------------------------------------------------

typedef _Harness = ({
  AppDatabase db,
  StreakDao streakDao,
  SharedPreferences prefs,
  _FakeApiClient apiClient,
  SyncService service,
});

Future<_Harness> _makeHarness({
  Map<String, Object> prefsValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(Map<String, Object>.from(prefsValues));
  final prefs = await SharedPreferences.getInstance();

  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final streakDao = StreakDao(db);
  final apiClient = _FakeApiClient(prefs);

  final service = SyncService(
    apiClient: apiClient,
    db: db,
    streakDao: streakDao,
    prefs: prefs,
  );

  return (
    db: db,
    streakDao: streakDao,
    prefs: prefs,
    apiClient: apiClient,
    service: service,
  );
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  tearDown(() async {
    // SharedPreferences.setMockInitialValues сбрасывает состояние между тестами.
  });

  // ---- Отправка ----

  group('SyncService.syncNow — отправка streak-блока', () {
    test(
      'когда есть запись в StreakTable + курсор в prefs — streak-блок включается в запрос',
      () async {
        final h = await _makeHarness(
          prefsValues: {kLastFreezeAccrualKey: '2026-01-15T00:00:00.000Z'},
        );

        // Создаём строку в StreakTable и устанавливаем 5 заморозок.
        await h.streakDao.getOrCreate();
        await h.streakDao.updateStreak(
          const StreakTableCompanion(freezeCount: Value(5)),
        );

        await h.service.syncNow();

        expect(h.apiClient.capturedStreak, isNotNull);
        expect(h.apiClient.capturedStreak!['freeze_count'], 5);
        expect(
          h.apiClient.capturedStreak!['last_freeze_accrual_at'],
          '2026-01-15T00:00:00.000Z',
        );

        await h.db.close();
      },
    );

    test(
      'когда нет записи в StreakTable и нет курсора — streak-блок не добавляется',
      () async {
        // Пустые prefs, пустая база.
        final h = await _makeHarness();

        await h.service.syncNow();

        // StreakTable пуста → getStreak() вернёт null; prefs без курсора →
        // streakBlock == null → в запрос не включается.
        expect(h.apiClient.capturedStreak, isNull);

        await h.db.close();
      },
    );

    test(
      'когда есть только курсор в prefs (без StreakTable) — streak-блок включается',
      () async {
        final h = await _makeHarness(
          prefsValues: {kLastFreezeAccrualKey: '2026-03-01T00:00:00.000Z'},
        );
        // Streak-таблица пуста — getStreak() вернёт null → freeze_count = 0.

        await h.service.syncNow();

        expect(h.apiClient.capturedStreak, isNotNull);
        expect(h.apiClient.capturedStreak!['freeze_count'], 0);
        expect(
          h.apiClient.capturedStreak!['last_freeze_accrual_at'],
          '2026-03-01T00:00:00.000Z',
        );

        await h.db.close();
      },
    );
  });

  // ---- Приём (LWW) ----

  group('SyncService.syncNow — адопт ответа сервера', () {
    test(
      'сервер вернул freeze_count=10 → пишется в Drift StreakTable',
      () async {
        final h = await _makeHarness(
          prefsValues: {kLastFreezeAccrualKey: '2026-01-01T00:00:00.000Z'},
        );

        // Локально 3 заморозки.
        await h.streakDao.getOrCreate();
        await h.streakDao.updateStreak(
          const StreakTableCompanion(freezeCount: Value(3)),
        );

        h.apiClient.fakeResponse = {
          'streak': {
            'current': 5,
            'longest': 10,
            'last_completed_date': null,
            'freeze_count': 10,
            'last_freeze_accrual_at': '2026-02-01T00:00:00.000Z',
          },
        };

        await h.service.syncNow();

        final row = await h.streakDao.getStreak();
        // Сервер выиграл LWW → freeze_count стал 10.
        expect(row?.freezeCount, 10);

        await h.db.close();
      },
    );

    test(
      'сервер вернул last_freeze_accrual_at → пишется в SharedPreferences',
      () async {
        final h = await _makeHarness(
          prefsValues: {kLastFreezeAccrualKey: '2026-01-01T00:00:00.000Z'},
        );

        await h.streakDao.getOrCreate();
        await h.streakDao.updateStreak(
          const StreakTableCompanion(freezeCount: Value(3)),
        );

        const serverCursor = '2026-02-01T00:00:00.000Z';
        h.apiClient.fakeResponse = {
          'streak': {
            'freeze_count': 7,
            'last_freeze_accrual_at': serverCursor,
          },
        };

        await h.service.syncNow();

        expect(h.prefs.getString(kLastFreezeAccrualKey), serverCursor);

        await h.db.close();
      },
    );

    test(
      'сервер вернул null last_freeze_accrual_at → локальный курсор сохраняется',
      () async {
        const localCursor = '2026-01-15T00:00:00.000Z';
        final h = await _makeHarness(
          prefsValues: {kLastFreezeAccrualKey: localCursor},
        );

        await h.streakDao.getOrCreate();
        await h.streakDao.updateStreak(
          const StreakTableCompanion(freezeCount: Value(4)),
        );

        // Сервер вернул null last_freeze_accrual_at.
        h.apiClient.fakeResponse = {
          'streak': {
            'freeze_count': 10,
            'last_freeze_accrual_at': null,
          },
        };

        await h.service.syncNow();

        // Курсор не должен быть затёрт.
        expect(h.prefs.getString(kLastFreezeAccrualKey), localCursor);
        // freeze_count тоже не должен быть затёрт (раз null-курсор — пропускаем блок целиком).
        final row = await h.streakDao.getStreak();
        expect(row?.freezeCount, 4);

        await h.db.close();
      },
    );

    test(
      'ответ не содержит ключа streak — ни Drift, ни prefs не меняются',
      () async {
        const localCursor = '2026-01-15T00:00:00.000Z';
        final h = await _makeHarness(
          prefsValues: {kLastFreezeAccrualKey: localCursor},
        );

        await h.streakDao.getOrCreate();
        await h.streakDao.updateStreak(
          const StreakTableCompanion(freezeCount: Value(3)),
        );

        // Ответ без ключа streak.
        h.apiClient.fakeResponse = {'updated_items': []};

        await h.service.syncNow();

        expect(h.prefs.getString(kLastFreezeAccrualKey), localCursor);
        final row = await h.streakDao.getStreak();
        expect(row?.freezeCount, 3);

        await h.db.close();
      },
    );

    test(
      'сервер вернул current/longest → обновляются в Drift рядом с freeze_count',
      () async {
        final h = await _makeHarness(
          prefsValues: {kLastFreezeAccrualKey: '2026-01-01T00:00:00.000Z'},
        );

        await h.streakDao.getOrCreate();
        await h.streakDao.updateStreak(
          const StreakTableCompanion(
            current: Value(2),
            longest: Value(5),
            freezeCount: Value(3),
          ),
        );

        h.apiClient.fakeResponse = {
          'streak': {
            'current': 7,
            'longest': 12,
            'last_completed_date': '2026-06-20T00:00:00.000Z',
            'freeze_count': 8,
            'last_freeze_accrual_at': '2026-06-01T00:00:00.000Z',
          },
        };

        await h.service.syncNow();

        final row = await h.streakDao.getStreak();
        expect(row?.current, 7);
        expect(row?.longest, 12);
        expect(row?.freezeCount, 8);

        await h.db.close();
      },
    );
  });

  // ---- Нет двойного счёта ----

  group('Нет двойного счёта заморозок', () {
    test(
      'после адопта серверного курсора accrueIfNeeded работает от нового курсора',
      () async {
        // После syncNow курсор в prefs = серверный.
        // Следующий вызов computeAccrual будет использовать этот обновлённый курсор.
        // Проверяем через SharedPreferences напрямую.
        const serverCursor = '2026-06-01T00:00:00.000Z';
        final h = await _makeHarness(
          prefsValues: {kLastFreezeAccrualKey: '2026-01-01T00:00:00.000Z'},
        );

        await h.streakDao.getOrCreate();
        await h.streakDao.updateStreak(
          const StreakTableCompanion(freezeCount: Value(3)),
        );

        h.apiClient.fakeResponse = {
          'streak': {
            'freeze_count': 5,
            'last_freeze_accrual_at': serverCursor,
          },
        };

        await h.service.syncNow();

        // После sync prefs содержит серверный курсор.
        expect(h.prefs.getString(kLastFreezeAccrualKey), serverCursor);

        // Следующий accrueIfNeeded получит lastAccrual=2026-06-01,
        // а не старый 2026-01-01 — нет дублирования накопленных заморозок.
        // (Проверяем только prefs; полный accrueIfNeeded требует Flutter env.)

        await h.db.close();
      },
    );
  });
}
