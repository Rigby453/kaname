// Виджет-тест ScreenTimeScreen — регрессия overflow в карточке использования
// БЕЗ установленного лимита (#7) И с установленным лимитом / limit-badge (#2b).
//
// До фикса #7: в _UsageTile (screen_time_screen.dart) подпись «Used today:
// N min/day» (длиннее, чем компактный формат «N / M min/day» для категорий
// С лимитом) делила строку с Expanded(categoryName) 50/50 по flex и
// обрезалась многоточием посередине слова («Использовано сего…ю»), хотя у
// карточки в целом было достаточно ширины. Фикс: без лимита подпись
// переносится на отдельную полноширинную строку под названием категории.
//
// #2b: лимит должен быть виден отдельной заметной таблеткой (_LimitBadge) и
// в Section 1 (настройка лимитов), и в Section 2 (использование) — в т.ч. при
// превышении лимита (ember). Проверяем, что таблетка не переполняет строку
// на 320px / textScale 2.0.
//
// #8 (неверный «Всего сегодня») покрыт юнит-тестами агрегации
// (filterTrackedPackages) в screen_time_categories_test.dart — не дублируется
// здесь, так как требует только чистых функций без виджетов.

import 'dart:convert';

import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart'
    show sharedPreferencesProvider;
import 'package:app/features/health/screen_time_screen.dart';
import 'package:app/features/health/screen_time_usage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Фейковый нотифайер с фиксированным granted-состоянием.
/// refresh() переопределён в no-op: реальный ScreenTimeUsageNotifier.refresh()
/// на не-Android платформе (тесты) сбрасывает state в denied/пусто — экран
/// вызывает refresh() из addPostFrameCallback в initState(), что иначе сразу
/// затирает наше фейковое состояние после первого кадра.
class _FakeUsageNotifier extends ScreenTimeUsageNotifier {
  _FakeUsageNotifier(ScreenTimeUsageState fakeState) : super() {
    state = fakeState;
  }

  @override
  Future<void> refresh() async {}
}

/// Использование без установленных лимитов по всем 6 категориям — провоцирует
/// длинную подпись «Used today: N min/day» в каждой плитке секции Usage Data.
const _grantedNoLimitState = ScreenTimeUsageState(
  permission: UsagePermissionStatus.granted,
  usedMinutes: {
    'social': 65,
    'video': 40,
    'games': 12,
    'browsing': 8,
    'messaging': 5,
    'other': 3,
  },
  perPackageMinutes: {
    'com.instagram.android': 65,
    'com.google.android.youtube': 40,
  },
  perPackageCategories: {
    'com.instagram.android': 'social',
    'com.google.android.youtube': 'video',
  },
);

/// Использование с лимитами по всем категориям: 'social' — над лимитом
/// (ember badge), 'video' — под лимитом (обычная badge), остальные тоже с
/// лимитом, чтобы проверить badge во всех плитках сразу.
const _grantedWithLimitState = ScreenTimeUsageState(
  permission: UsagePermissionStatus.granted,
  usedMinutes: {
    'social': 90, // over limit (лимит 60 ниже)
    'video': 20,
    'games': 12,
    'browsing': 8,
    'messaging': 5,
    'other': 3,
  },
  perPackageMinutes: {
    'com.instagram.android': 90,
    'com.google.android.youtube': 20,
  },
  perPackageCategories: {
    'com.instagram.android': 'social',
    'com.google.android.youtube': 'video',
  },
);

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double textScale,
  Map<String, int>? limits,
  ScreenTimeUsageState usageState = _grantedNoLimitState,
}) async {
  SharedPreferences.setMockInitialValues(
    limits == null
        ? {} // нет сохранённых лимитов → 0 = no limit
        : {'screen_time_limits': jsonEncode(limits)},
  );
  final prefs = await SharedPreferences.getInstance();

  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        screenTimeUsageProvider
            .overrideWith((ref) => _FakeUsageNotifier(usageState)),
      ],
      child: MaterialApp(
        theme: AppTheme.focusTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const ScreenTimeScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('ScreenTimeScreen — Usage Data без лимита (#7 overflow regression)', () {
    testWidgets('320px, textScale 1.0: нет overflow', (tester) async {
      await _pump(tester, width: 320, textScale: 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('360px, textScale 1.5: нет overflow', (tester) async {
      await _pump(tester, width: 360, textScale: 1.5);
      expect(tester.takeException(), isNull);
    });

    testWidgets('320px, textScale 1.5 (худший случай): нет overflow',
        (tester) async {
      await _pump(tester, width: 320, textScale: 1.5);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'подпись «Used today: N min/day» рендерится полностью, не обрезана',
        (tester) async {
      await _pump(tester, width: 320, textScale: 1.0);
      // social: 65 мин, лимита нет → полная подпись на отдельной строке,
      // НЕ "Used today: 65 min/d…" / "Used today: сего…ю" и т.п.
      expect(find.text('Used today: 65 min/day'), findsOneWidget);
      expect(find.text('Used today: 40 min/day'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ScreenTimeScreen — limit badge visible (#2b regression)', () {
    final limits = {
      'social': 60,
      'video': 45,
      'games': 30,
      'browsing': 30,
      'messaging': 30,
    };

    testWidgets('320px, textScale 1.0: лимит-badge виден, нет overflow',
        (tester) async {
      await _pump(
        tester,
        width: 320,
        textScale: 1.0,
        limits: limits,
        usageState: _grantedWithLimitState,
      );
      // Section 2 (Usage data): «used / limit min/day» видна для over-limit
      // (social) и под-лимитом (video) категорий.
      expect(find.text('90 / 60 min/day'), findsOneWidget);
      expect(find.text('20 / 45 min/day'), findsOneWidget);
      // Section 1 (Set daily limits): лимит виден до данных использования —
      // используем тот же локализованный формат длительности, что и badge.
      expect(find.text('1h'), findsOneWidget); // 60 min → social limit (fmt_h_only)
      expect(tester.takeException(), isNull);
    });

    testWidgets('320px, textScale 2.0 (максимум по §A): нет overflow',
        (tester) async {
      await _pump(
        tester,
        width: 320,
        textScale: 2.0,
        limits: limits,
        usageState: _grantedWithLimitState,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('360px, textScale 1.5: нет overflow', (tester) async {
      await _pump(
        tester,
        width: 360,
        textScale: 1.5,
        limits: limits,
        usageState: _grantedWithLimitState,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
