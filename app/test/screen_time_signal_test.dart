// Виджет-тест сигнала экранного времени:
//   1) granted + данные → виджет виден (текст «Screen time:» в EN-локали)
//   2) denied → виджет скрыт (SizedBox.shrink)
//   3) granted + пустые данные (total==0) → виджет скрыт
//   4) нет overflow на 320px при textScale 1.5
//   5) unit: ключи EN+RU присутствуют в healthBStrings

import 'package:app/core/l10n/strings/health_b.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/health/screen_time_signal_widget.dart';
import 'package:app/features/health/screen_time_usage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Фейковый нотифайер — расширяет ScreenTimeUsageNotifier, чтобы удовлетворить
// тип StateNotifierProvider<ScreenTimeUsageNotifier, ScreenTimeUsageState>.
// Конструктор ScreenTimeUsageNotifier видит _isAndroid=false (в тестах Platform
// бросает, catch → false) и выставляет state=denied. Затем мы перезаписываем
// состояние нужным фейковым, переопределяя то, что выставил super.
class _FakeNotifier extends ScreenTimeUsageNotifier {
  _FakeNotifier(ScreenTimeUsageState fakeState) : super() {
    state = fakeState;
  }
}

// Granted + суммарно 90 мин (social 45 — лидер).
final _grantedState = ScreenTimeUsageState(
  permission: UsagePermissionStatus.granted,
  usedMinutes: const {
    'social': 45,
    'video': 30,
    'games': 0,
    'browsing': 10,
    'messaging': 5,
    'other': 0,
  },
);

// Denied — разрешение не выдано.
const _deniedState = ScreenTimeUsageState(
  permission: UsagePermissionStatus.denied,
);

// Granted, но все категории == 0 (нет данных за сегодня).
const _emptyGrantedState = ScreenTimeUsageState(
  permission: UsagePermissionStatus.granted,
);

Future<void> _pump(
  WidgetTester tester,
  ScreenTimeUsageState state, {
  double width = 360,
  double textScale = 1.0,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        screenTimeUsageProvider.overrideWith((ref) => _FakeNotifier(state)),
      ],
      child: MaterialApp(
        theme: AppTheme.focusTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: ScreenTimeSignalWidget(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ScreenTimeSignalWidget', () {
    testWidgets('granted + данные → сигнал виден', (tester) async {
      await _pump(tester, _grantedState);

      // EN-локаль по умолчанию → текст содержит «Screen time:»
      expect(find.textContaining('Screen time:'), findsOneWidget);
      // Ссылка «Details» видна
      expect(find.text('Details'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('denied → сигнал скрыт (SizedBox.shrink)', (tester) async {
      await _pump(tester, _deniedState);

      expect(find.textContaining('Screen time:'), findsNothing);
      expect(find.text('Details'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('granted + пустые данные → сигнал скрыт', (tester) async {
      await _pump(tester, _emptyGrantedState);

      expect(find.textContaining('Screen time:'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('нет overflow на 320px при textScale 1.5', (tester) async {
      await _pump(tester, _grantedState, width: 320, textScale: 1.5);
      expect(tester.takeException(), isNull);
    });
  });

  group('screenTimeTotal / screenTimeTopCategory', () {
    test('total суммирует все категории', () {
      expect(screenTimeTotal({'social': 45, 'video': 30, 'other': 5}), 80);
      expect(screenTimeTotal({}), 0);
      expect(screenTimeTotal({'social': 0, 'video': 0}), 0);
    });

    test('topCategory возвращает максимум', () {
      final top = screenTimeTopCategory({
        'social': 45,
        'video': 30,
        'games': 0,
        'browsing': 10,
      });
      expect(top?.key, 'social');
      expect(top?.value, 45);
    });

    test('topCategory возвращает null при пустой/нулевой карте', () {
      expect(screenTimeTopCategory({}), isNull);
      expect(screenTimeTopCategory({'social': 0, 'video': 0}), isNull);
    });
  });

  group('L10n: ключи EN+RU присутствуют в healthBStrings', () {
    const requiredKeys = [
      'screentime.signal_label',
      'screentime.signal_card_title',
      'screentime.signal_details',
      'screentime.fmt_h_min',
      'screentime.fmt_min',
      'screentime.cat_social',
      'screentime.cat_video',
      'screentime.cat_games',
      'screentime.cat_browsing',
      'screentime.cat_messaging',
      'screentime.cat_other',
    ];

    for (final key in requiredKeys) {
      test('$key → en + ru', () {
        expect(
          healthBStrings.containsKey(key),
          isTrue,
          reason: 'Ключ $key должен быть в healthBStrings',
        );
        expect(
          healthBStrings[key]!['en'],
          isNotNull,
          reason: '$key не имеет EN перевода',
        );
        expect(
          healthBStrings[key]!['ru'],
          isNotNull,
          reason: '$key не имеет RU перевода',
        );
      });
    }
  });
}
