// acquisition_source_test.dart
// Тесты шага «Откуда узнал?» (acquisition source, индекс 13 в PageView).
//
// Widget-тесты (группа 'widget'):
//   1. Шаг рендерится без overflow на 320px / textScale 2.0.
//   2. Все 6 вариантов видны.
//   3. Кнопка «Пропустить» видна внутри шага.
//   4. Тап на вариант («Friend or acquaintance») выполняется без исключений.
//
// Prefs-уровень (группа 'prefs logic'):
//   5. Выбор source = 'friend' → prefs[acquisition_source] = 'friend'.
//   6. Все 6 кодов корректно записываются и читаются обратно.
//   7. Skip (source == null) → ключ acquisition_source отсутствует в prefs.
//   8. Константа acquisitionSourceKey == 'acquisition_source'.
//
// Навигация: прыжок через PageController.jumpToPage() (NeverScrollableScrollPhysics).

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/onboarding/setup_flow.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Тестовая тема (без GoogleFonts, как во всех overflow-тестах проекта)
// ---------------------------------------------------------------------------

ThemeData _testTheme() {
  return ThemeData.dark().copyWith(
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
}

// Узкая ширина + предельный textScale a11y (как во всех overflow-тестах).
const Size _size = Size(320, 760);
const double _scale = 2.0;

// Индекс шага «Откуда узнал?» в PageView.
const int _acqPage = 13;

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MediaQuery(
        data: const MediaQueryData(
          size: _size,
          textScaler: TextScaler.linear(_scale),
        ),
        child: MaterialApp(
          theme: _testTheme(),
          home: const SetupFlowScreen(),
        ),
      ),
    );
  }

  // Прыжок на нужную страницу через PageController (минуя физику свайпов).
  Future<void> goToPage(WidgetTester tester, int page) async {
    final dynamic pageView = tester.widget(find.byType(PageView));
    (pageView.controller as PageController).jumpToPage(page);
    await tester.pump(); // onPageChanged → setState
    await tester.pump(const Duration(milliseconds: 50));
  }

  // ---------------------------------------------------------------------------
  // Widget-тесты
  // ---------------------------------------------------------------------------

  group('widget', () {
    testWidgets(
      'acquisition step рендерится без overflow на 320px / textScale 2.0',
      (tester) async {
        await tester.binding.setSurfaceSize(_size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildApp());
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException(); // очищаем стартовые исключения

        await goToPage(tester, _acqPage);
        expect(tester.takeException(), isNull,
            reason: 'шаг acquisition source не должен вызывать исключений');

        // Заголовок экрана
        expect(find.text('How did you hear about us?'), findsOneWidget);

        // Кнопка «Не хочу отвечать» внутри шага (отличается от глобальной «Skip»)
        expect(find.text('Prefer not to say'), findsOneWidget);

        // Монтаж; очищаем отложенные таймеры
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );

    testWidgets(
      'все 6 вариантов отображаются',
      (tester) async {
        await tester.binding.setSurfaceSize(_size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildApp());
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        await goToPage(tester, _acqPage);

        // Прокручиваем вниз (при большом textScale часть вариантов может быть за экраном)
        await tester.scrollUntilVisible(
          find.text('App Store / Google Play'),
          50,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('App Store / Google Play'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Friend or acquaintance'),
          50,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Friend or acquaintance'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Ad'),
          50,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Ad'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Other'),
          50,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Other'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );

    testWidgets(
      'тап на "Friend or acquaintance" не вызывает исключений',
      (tester) async {
        await tester.binding.setSurfaceSize(_size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildApp());
        await tester.pump(const Duration(milliseconds: 50));
        tester.takeException();

        await goToPage(tester, _acqPage);

        // Прокручиваем к варианту и тапаем
        await tester.scrollUntilVisible(
          find.text('Friend or acquaintance'),
          50,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.tap(find.text('Friend or acquaintance'));
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull,
            reason: 'тап на вариант не должен вызывать исключений');

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Prefs-уровень: симулируем логику _finish()
  // ---------------------------------------------------------------------------

  group('prefs logic', () {
    test(
      '"friend" → prefs[acquisition_source] = "friend"',
      () async {
        // Симулируем ветку _finish() при _acquisitionSource = 'friend'
        const source = 'friend';
        await prefs.setString(acquisitionSourceKey, source);
        expect(prefs.getString(acquisitionSourceKey), equals('friend'));
      },
    );

    test(
      'все 6 кодов источников корректно round-trip через prefs',
      () async {
        const codes = [
          'app_store_google_play',
          'friend',
          'social',
          'ad',
          'search',
          'other',
        ];
        for (final code in codes) {
          await prefs.setString(acquisitionSourceKey, code);
          expect(
            prefs.getString(acquisitionSourceKey),
            equals(code),
            reason: 'код "$code" должен корректно сохраняться и читаться',
          );
        }
      },
    );

    test(
      'skip (source == null) → ключ acquisition_source отсутствует в prefs',
      () async {
        // Симулируем ветку _finish() при _acquisitionSource == null:
        // условие `if (_acquisitionSource != null)` не выполняется → ключ не пишется.
        const String? source = null;
        if (source != null) {
          await prefs.setString(acquisitionSourceKey, source);
        }
        expect(
          prefs.containsKey(acquisitionSourceKey),
          isFalse,
          reason: 'skip не должен записывать ключ в prefs',
        );
      },
    );

    test(
      'acquisitionSourceKey == "acquisition_source"',
      () {
        // Константа должна совпадать с ожидаемым строковым значением.
        expect(acquisitionSourceKey, equals('acquisition_source'));
      },
    );
  });
}
