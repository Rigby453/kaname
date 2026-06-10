// Виджет-дымовой тест пейвола: рендерится без рантайм-ошибок, показывает
// преимущества/цену/кнопки Subscribe и Restore purchases.
// Dev: unlock premium удалён — теперь Subscribe сам делает dev-апгрейд в debug.

import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/auth/auth_controller.dart' show isPremiumProvider;
import 'package:app/features/paywall/paywall_screen.dart';
import 'package:app/services/purchases/purchase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Заглушка PurchaseService для тестов — не ходит в сеть.
class _FakePurchaseService implements PurchaseService {
  @override
  Future<PurchaseOutcome> buyPremium() async => PurchaseOutcome.unavailable;

  @override
  Future<PurchaseOutcome> restorePurchases() async =>
      PurchaseOutcome.unavailable;
}

void main() {
  testWidgets(
      'PaywallScreen renders benefits, price, Subscribe and Restore purchases',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // Не ходим в сеть за /me — фиксируем free.
          isPremiumProvider.overrideWith((ref) async => false),
          // Изолируем от сети: подставляем фейковый PurchaseService.
          purchaseServiceProvider
              .overrideWithValue(_FakePurchaseService()),
        ],
        child: const MaterialApp(home: PaywallScreen()),
      ),
    );
    await tester.pump();

    // Верх списка (виден сразу).
    expect(find.text('Kaizen Premium'), findsOneWidget);
    expect(find.text('Smarter plans'), findsOneWidget);

    // Низ ListView ленивый — доскролливаем до кнопки Restore purchases.
    await tester.scrollUntilVisible(
      find.text('Restore purchases'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);
    expect(find.textContaining('/ month'), findsOneWidget);
    expect(find.text('No ads'), findsOneWidget);
    // Кнопки Dev: unlock premium больше нет.
    expect(find.text('Dev: unlock premium'), findsNothing);
  });
}
