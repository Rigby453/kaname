// Тест: Health screen корректно отображает 4 тематические группы
// (Nutrition / Sleep / Mind / Movement) без overflow.
//
// Проверяем:
//   1. Все 4 заголовка секций рендерятся на 320px (высота достаточная).
//   2. Нет RenderFlex overflow ни на 320x2500px, ни при textScale 1.5 на 360x2500px.
//   3. По умолчанию (все флаги=false) 4 модульных Switch присутствует в дереве.
//
// Примечание о высоте: ListView lazy-строит только видимые элементы.
// Используем высоту 2500px, чтобы все элементы были в дереве. Ширина 320px
// тестирует горизонтальный overflow (основной риск) — вертикальный scroll не ошибка.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/health/health_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Тестовая тема — минимальная, содержит FocusThemeExtension
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

// ---------------------------------------------------------------------------
// Вспомогательные константы
// ---------------------------------------------------------------------------

/// 320px ширина (узкий телефон) + большая высота, чтобы все ListView-элементы
/// попали в дерево (ListView lazy-билдит только видимые). Overflow-тест — по ширине.
const Size _narrowTallSize = Size(320, 2500);

/// Обычная ширина + большая высота + крупный текст (1.5x а11y).
const Size _normalTallSize = Size(360, 2500);

const double _largeTextScale = 1.5;

// ---------------------------------------------------------------------------
// Вспомогательный harness
// ---------------------------------------------------------------------------

Widget _buildHarness(
  AppDatabase db,
  SharedPreferences prefs,
  Widget screen, {
  double textScale = 1.0,
  Size size = _narrowTallSize,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        size: size,
      ),
      child: MaterialApp(
        theme: _testTheme(),
        // Без GoRouter — навигация не тестируется, только рендер
        home: Scaffold(body: screen),
      ),
    ),
  );
}

/// Прокачивает виджет и ждёт Drift-стримы.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

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

  group('HealthScreen — taxonomy grouping', () {
    testWidgets(
        '320px width: все 4 тематические секции присутствуют, нет overflow',
        (tester) async {
      // Высота 2500px чтобы все lazy-ListView элементы попали в дерево;
      // ширина 320px для проверки горизонтального overflow.
      await _setSize(tester, _narrowTallSize);
      await tester.pumpWidget(
        _buildHarness(db, prefs, const HealthScreen()),
      );
      await _settle(tester);

      // Все 4 заголовка секций должны быть найдены в дереве
      expect(find.text('Nutrition'), findsWidgets);
      expect(find.text('Sleep'), findsWidgets);
      expect(find.text('Mind'), findsWidgets);
      expect(find.text('Movement'), findsWidgets);

      // Нет исключений (overflow и др.)
      expect(tester.takeException(), isNull);

      await _unmount(tester);
    });

    testWidgets(
        'textScale 1.5: все 4 тематические секции присутствуют, нет overflow',
        (tester) async {
      await _setSize(tester, _normalTallSize);
      await tester.pumpWidget(
        _buildHarness(
          db,
          prefs,
          const HealthScreen(),
          textScale: _largeTextScale,
          size: _normalTallSize,
        ),
      );
      await _settle(tester);

      expect(find.text('Nutrition'), findsWidgets);
      expect(find.text('Sleep'), findsWidgets);
      expect(find.text('Mind'), findsWidgets);
      expect(find.text('Movement'), findsWidgets);

      expect(tester.takeException(), isNull);

      await _unmount(tester);
    });

    testWidgets(
        'default state (все флаги=false): 4 модульных Switch в дереве',
        (tester) async {
      await _setSize(tester, _narrowTallSize);
      // Все флаги = false (дефолт — пустой prefs)
      await tester.pumpWidget(
        _buildHarness(db, prefs, const HealthScreen()),
      );
      await _settle(tester);

      // В default-состоянии все 4 опциональных модуля показывают Switch(false).
      // Switch.adaptive может рендериться как Switch или CupertinoSwitch в зависимости
      // от платформы; ищем оба типа вместе.
      final switchWidgets =
          find.byWidgetPredicate((w) => w is Switch || w is CupertinoSwitch);
      // Ожидаем минимум 4 — по одному на Food / Meditation / Breathing / Workouts
      // Плюс Water reminders Switch в карточке воды = 5 итого.
      expect(switchWidgets, findsAtLeast(4));

      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  });
}
