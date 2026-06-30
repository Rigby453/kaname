// Сервис миграции гостевых (offline) данных на аккаунт при первом login / register.
//
// Проблема (аудит C2): пользователь работал в гостевом режиме (guest_mode=true,
// данные пишутся в Drift с userId='local', синхронизация не выполнялась).
// При последующем login() токен получен, но без явного сброса курсора delta-sync'а
// записи с updatedAt < lastSyncAt (от прошлых сессий) могут быть пропущены.
//
// Решение:
//   1. Сбросить lastSyncAt до эпохи — гарантирует, что ВСЕ локальные
//      записи попадут в первый sync-payload (where updatedAt > epoch).
//   2. Запустить syncNow() с уже активным токеном — данные уходят на сервер.
//
// Безопасность (offline-first):
//   - migration = upload only; локальные данные не удаляются.
//   - Ошибки сети поглощаются внутри syncNow(): курсор уже сброшен, следующий
//     auto-sync при восстановлении сети повторит выгрузку (идемпотентно).
//   - userId='local' в payload: сервер игнорирует клиентский user_id и
//     подставляет своего из JWT (комментарий в _itemToSnakeCase).
//
// Идемпотентность: _clearGuest() снимает флаг guest_mode; повторный login()
// не видит флага → миграция не вызывается снова.

// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../api/api_client.dart';
import 'sync_service.dart';

/// Маркер эпохи — используется для полного сброса курсора delta-sync.
const kSyncEpoch = '1970-01-01T00:00:00.000Z';

class GuestMigrationService {
  GuestMigrationService({
    required AppDatabase db,
    required ApiClient apiClient,
    required SyncService syncService,
  })  : _db = db,
        _apiClient = apiClient,
        _syncService = syncService;

  final AppDatabase _db;
  final ApiClient _apiClient;
  final SyncService _syncService;

  // ---------------------------------------------------------------------------
  // Публичный API
  // ---------------------------------------------------------------------------

  /// Проверяет наличие хоть каких-то локальных пользовательских данных.
  /// Проверяем три ключевые таблицы: задачи, вода, дневник.
  Future<bool> hasLocalData() async {
    final item =
        await (_db.select(_db.itemsTable)..limit(1)).getSingleOrNull();
    if (item != null) return true;
    final water =
        await (_db.select(_db.waterLogsTable)..limit(1)).getSingleOrNull();
    if (water != null) return true;
    final dayLog =
        await (_db.select(_db.dayLogsTable)..limit(1)).getSingleOrNull();
    return dayLog != null;
  }

  /// Мигрирует гостевые данные на сервер после получения токена.
  ///
  /// Алгоритм:
  ///   1. Если локальных данных нет — early return (no-op, sync не вызывается).
  ///   2. Сбрасывает lastSyncAt → эпоха: delta-sync захватит ВСЕ локальные
  ///      записи (where updatedAt > epoch = все строки).
  ///   3. Вызывает syncNow() — данные уходят на сервер. syncNow() поглощает
  ///      ошибки сети, не бросает в UI. После успешного ответа lastSyncAt
  ///      обновляется до текущего момента (внутри syncNow()).
  ///
  /// Вызывать ПОСЛЕ сохранения токена в ApiClient, ДО _clearGuest().
  Future<void> migrateIfNeeded() async {
    if (!await hasLocalData()) {
      debugPrint('[GuestMigration] Нет локальных данных — миграция не нужна');
      return;
    }

    // Сбрасываем курсор: следующий delta-sync захватит абсолютно все записи.
    await _apiClient.saveLastSyncAt(kSyncEpoch);
    debugPrint(
      '[GuestMigration] Курсор сброшен до эпохи — выгружаем гостевые данные…',
    );

    // syncNow() уже видит токен (сохранён после login/register) и поглощает
    // ошибки: локальные данные остаются в Drift для повторной попытки.
    await _syncService.syncNow();
    debugPrint('[GuestMigration] Выгрузка завершена (или отложена до сети)');
  }
}

// ---------------------------------------------------------------------------
// Riverpod провайдер (C2)
// ---------------------------------------------------------------------------

/// Провайдер сервиса миграции гостевых данных на аккаунт (feature C2).
final guestMigrationServiceProvider = Provider<GuestMigrationService>((ref) {
  return GuestMigrationService(
    db: ref.read(appDatabaseProvider),
    apiClient: ref.read(apiClientProvider),
    syncService: ref.read(syncServiceProvider),
  );
});
