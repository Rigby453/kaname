// Регресс-тест: showPremiumUpsell(context, featureName) должен получать
// ЛОКАЛИЗОВАННОЕ имя фичи (context.s('...')), а не хардкод на английском —
// иначе тост "Premium-функция — открой за {feature}" наполовину остаётся
// на английском даже на RU-устройстве (шаблон локализован, а сама фича — нет).
//
// Покрывает 4 call site из задачи:
//   - food/ai_menu_sheet.dart        → food.ai_menu_feature_name
//   - diary/diary_screen.dart        → diary.ai_insights_feature_name
//   - today/*_review_card.dart (x2)  → today.ai_plans (общий ключ)
//
// НЕ ЗАПУСКАТЬ НАПРЯМУЮ: запуск управляется оркестратором (flutter test).

import 'package:app/core/l10n/app_strings.dart';
import 'package:app/features/paywall/paywall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Хелпер: рендерит кнопку, которая вызывает showPremiumUpsell с локализованным
// именем фичи по переданному ключу, тапает по ней и даёт снэкбару появиться.
// ---------------------------------------------------------------------------

Future<void> _pumpAndTrigger(WidgetTester tester, String featureKey) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      // Без supportedLocales Flutter's basicLocaleListResolution не находит
      // 'ru' среди дефолтного [Locale('en', 'US')] и молча откатывается на
      // en — тогда Localizations.localeOf(context) возвращает en, и
      // context.s() отдаёт английские строки (RU-ассерты находят 0 виджетов).
      // См. app/test/locale_gallery_test.dart — тот же паттерн.
      supportedLocales: const [Locale('en'), Locale('ru')],
      // Глобальные делегаты локализации: без них MaterialApp бросает
      // FlutterError "locale ru is not supported by all of its localization
      // delegates" — это и валит тест (см. locale_gallery_test.dart).
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  showPremiumUpsell(context, context.s(featureKey)),
              child: const Text('trigger'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('trigger'));
  await tester.pump(); // старт анимации снэкбара
  await tester.pump(const Duration(milliseconds: 300)); // дать ему появиться
}

void main() {
  testWidgets(
      'showPremiumUpsell: AI menu builder (food) localized on RU, no English leak',
      (tester) async {
    await _pumpAndTrigger(tester, 'food.ai_menu_feature_name');

    expect(find.textContaining('ИИ-конструктор меню'), findsOneWidget);
    expect(find.textContaining('AI menu builder'), findsNothing);
  });

  testWidgets(
      'showPremiumUpsell: AI insights (diary) localized on RU, no English leak',
      (tester) async {
    await _pumpAndTrigger(tester, 'diary.ai_insights_feature_name');

    expect(find.textContaining('ИИ-инсайты'), findsOneWidget);
    expect(find.textContaining('AI insights'), findsNothing);
  });

  testWidgets(
      'showPremiumUpsell: AI plans (today review cards, shared key) localized on RU, no English leak',
      (tester) async {
    await _pumpAndTrigger(tester, 'today.ai_plans');

    expect(find.textContaining('AI-варианты'), findsOneWidget);
    // Английский литерал 'AI plans' (точная фраза, использовавшаяся до фикса)
    // не должен фигурировать как самостоятельный текстовый узел.
    expect(find.text('AI plans'), findsNothing);
  });
}
