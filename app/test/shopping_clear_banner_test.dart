// Виджет-тест баннера «Убрать купленные (N)» в ShoppingListScreen (БАГ-4).
//
// Кейсы:
// 1. Нет отмеченных → баннер НЕ отображается.
// 2. Есть отмеченные → баннер виден, тап убирает позиции.
// 3. Все позиции непомечены → баннер скрыт.
// 4. Баннер скрывается после удаления отмеченных.
//
// ВАЖНО про async: экран подписан на Drift-стрим (dao.watchAll()). Поэтому
// seed/чтение БД делаем внутри tester.runAsync, а вместо pumpAndSettle —
// _settle() (pump + runAsync-delay + pump'ы): pumpAndSettle на непрерывном
// Drift-стриме под фейковыми часами зависает (дедлок). Паттерн скопирован из
// рабочего today_undo_test.dart / interaction_smoke_test.dart.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/database/daos/shopping_dao.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/food/shopping_list_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Тестовая тема (без GoogleFonts — ускоряет тесты)
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
// Тестовый стенд
// ---------------------------------------------------------------------------
Widget _harness(AppDatabase db, SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      theme: _testTheme(),
      locale: const Locale('en'),
      home: const ShoppingListScreen(),
    ),
  );
}

/// Settle без pumpAndSettle (избегаем дедлока с Drift-стримом).
/// Копия паттерна из today_undo_test.dart / interaction_smoke_test.dart.
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

const _banner = ValueKey('clear_checked_banner');
const _btn = ValueKey('clear_checked_btn');

void main() {
  late AppDatabase db;
  late ShoppingDao dao;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ShoppingDao(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  group('_ClearCheckedBanner visibility', () {
    testWidgets('нет отмеченных → баннер не отображается', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));

      await tester.runAsync(() async {
        await dao.insertItem(name: 'Milk');
      });

      await tester.pumpWidget(_harness(db, prefs));
      await _settle(tester);

      expect(find.byKey(_banner), findsNothing);

      await _unmount(tester);
    });

    testWidgets('есть отмеченный → баннер виден, тап убирает позицию',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));

      await tester.runAsync(() async {
        await dao.insertItem(name: 'Eggs');
        final all = await dao.watchAll().first;
        await dao.setChecked(all.first.id, true);
      });

      await tester.pumpWidget(_harness(db, prefs));
      await _settle(tester);

      // Баннер должен быть виден
      expect(find.byKey(_banner), findsOneWidget);

      // Тапаем кнопку внутри баннера
      await tester.tap(find.byKey(_btn));
      await _settle(tester);

      // Список покупок должен стать пустым
      final remaining = await tester.runAsync(() => dao.watchAll().first);
      expect(remaining, isEmpty);

      await _unmount(tester);
    });

    testWidgets('все позиции непомечены → баннер скрыт', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));

      await tester.runAsync(() async {
        await dao.insertItem(name: 'Apple');
        await dao.insertItem(name: 'Banana');
      });

      await tester.pumpWidget(_harness(db, prefs));
      await _settle(tester);

      expect(find.byKey(_banner), findsNothing);

      await _unmount(tester);
    });

    testWidgets('баннер скрывается после удаления отмеченных', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));

      await tester.runAsync(() async {
        await dao.insertItem(name: 'Carrot');
        await dao.insertItem(name: 'Potato');
        final items = await dao.watchAll().first;
        final carrotId = items.firstWhere((i) => i.name == 'Carrot').id;
        await dao.setChecked(carrotId, true);
      });

      await tester.pumpWidget(_harness(db, prefs));
      await _settle(tester);

      // Баннер виден — 1 отмеченный
      expect(find.byKey(_banner), findsOneWidget);

      // Тапаем кнопку очистки
      await tester.tap(find.byKey(_btn));
      await _settle(tester);

      // Баннер скрылся (остался только Potato — непомечен)
      expect(find.byKey(_banner), findsNothing);

      // Potato остался в списке
      final remaining = await tester.runAsync(() => dao.watchAll().first);
      expect(remaining!.length, 1);
      expect(remaining.first.name, 'Potato');

      await _unmount(tester);
    });
  });
}
