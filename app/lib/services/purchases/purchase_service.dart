// ---------------------------------------------------------------------------
// Слой покупок — срез для интеграции RevenueCat
// ---------------------------------------------------------------------------
// Сейчас работает заглушка (StubPurchaseService):
//   • в debug-сборке buyPremium зовёт /subscription/dev-upgrade на бэкенде;
//   • в release-сборке — возвращает unavailable (платежи ещё не запущены).
//
// При реальной интеграции RevenueCat:
//   1. Добавить пакет purchases_flutter в pubspec.yaml.
//   2. Написать RevenueCatPurchaseService implements PurchaseService.
//   3. В purchaseServiceProvider вернуть RevenueCatPurchaseService вместо Stub.
//   4. UI не меняется — он знает только PurchaseOutcome.
// ---------------------------------------------------------------------------

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

// ---------------------------------------------------------------------------
// Результат покупки / восстановления
// ---------------------------------------------------------------------------

enum PurchaseOutcome {
  /// Покупка/восстановление прошли успешно.
  success,

  /// Пользователь закрыл диалог покупки без оплаты.
  cancelled,

  /// Платежи ещё не запущены (release-заглушка) или store недоступен.
  unavailable,

  /// Сетевая/серверная ошибка; сообщение — в исключении выше по стеку.
  error,
}

// ---------------------------------------------------------------------------
// Абстрактный интерфейс
// ---------------------------------------------------------------------------

abstract class PurchaseService {
  /// Инициирует покупку подписки Premium.
  Future<PurchaseOutcome> buyPremium();

  /// Восстанавливает предыдущие покупки (для RevenueCat).
  Future<PurchaseOutcome> restorePurchases();
}

// ---------------------------------------------------------------------------
// Заглушка (используется до появления RevenueCat)
// ---------------------------------------------------------------------------

class StubPurchaseService implements PurchaseService {
  StubPurchaseService(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<PurchaseOutcome> buyPremium() async {
    // Если токена нет — нельзя обновить тариф ни в debug, ни тем более в release.
    // Возвращаем error, чтобы пейволл показал «Sign in first».
    if (_apiClient.token == null) return PurchaseOutcome.error;

    if (kDebugMode) {
      // В debug зовём dev-апгрейд на бэкенде — удобно тестировать AI-фичи.
      try {
        await _apiClient.devUpgrade(tier: 'premium');
        return PurchaseOutcome.success;
      } on ApiException {
        return PurchaseOutcome.error;
      }
    }

    // В release-сборке платежи ещё не подключены.
    return PurchaseOutcome.unavailable;
  }

  @override
  Future<PurchaseOutcome> restorePurchases() async {
    // Заглушка: настоящее восстановление появится вместе с RevenueCat.
    return PurchaseOutcome.unavailable;
  }
}

// ---------------------------------------------------------------------------
// Riverpod-провайдер
// ---------------------------------------------------------------------------

/// Провайдер сервиса покупок.
/// Чтобы переключиться на RevenueCat — поменяй тут StubPurchaseService
/// на RevenueCatPurchaseService; UI не трогай.
final purchaseServiceProvider = Provider<PurchaseService>(
  (ref) => StubPurchaseService(ref.read(apiClientProvider)),
);
