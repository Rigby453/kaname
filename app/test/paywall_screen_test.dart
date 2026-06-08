// Виджет-дымовой тест пейвола: рендерится без рантайм-ошибок, показывает
// преимущества/цену/кнопку. Первый widget-тест (harness с ProviderScope-оверрайдами).

import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/auth/auth_controller.dart' show isPremiumProvider;
import 'package:app/features/paywall/paywall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('PaywallScreen renders benefits, price and Subscribe', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // Не ходим в сеть за /me — фиксируем free.
          isPremiumProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(home: PaywallScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Kaizen Premium'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);
    expect(find.textContaining('/ month'), findsOneWidget);
    // Ключевые преимущества присутствуют.
    expect(find.text('Smarter plans'), findsOneWidget);
    expect(find.text('No ads'), findsOneWidget);
  });
}
