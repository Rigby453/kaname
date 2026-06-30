// Виджет-тест ScreenTimeScreen — регрессия overflow в карточке использования
// БЕЗ установленного лимита (#7).
//
// До фикса: в _UsageTile (screen_time_screen.dart) подпись «Used today:
// N min/day» (длиннее, чем компактный формат «N / M min/day» для категорий
// С лимитом) делила строку с Expanded(categoryName) 50/50 по flex и
// обрезалась многоточием посередине слова («Использовано сего…ю»), хотя у
// карточки в целом было достаточно ширины. Фикс: без лимита подпись
// переносится на отдельную полноширинную строку под названием категории.
//
// #8 (неверный «Всего сегодня») покрыт юнит-тестами агрегации
// (filterTrackedPackages) в screen_time_categories_test.dart — не дублируется
// здесь, так как требует только чистых функций без виджетов.

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

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double textScale,
}) async {
  SharedPreferences.setMockInitialValues({}); // нет сохранённых лимитов → 0 = no limit
  final prefs = await SharedPreferences.getInstance();

  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        screenTimeUsageProvider
            .overrideWith((ref) => _FakeUsageNotifier(_grantedNoLimitState)),
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
}
