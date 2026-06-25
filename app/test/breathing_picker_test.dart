// Виджет-тест интеграции пользовательских техник в пикер дыхания.
// Подменяем customTechniquesProvider тестовыми данными (без Drift) и проверяем,
// что пользовательская техника появляется рядом со встроенными пресетами и
// экран остаётся без overflow на 320px при textScale 1.5.

import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/health/breathing_custom_providers.dart';
import 'package:app/features/health/breathing_engine.dart';
import 'package:app/features/health/breathing_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _testTechnique = CustomTechnique(
  id: 'tech-1',
  name: 'My Box Breathing',
  phases: [
    BreathPhase(label: 'Inhale', duration: Duration(seconds: 4), expand: true),
    BreathPhase(label: 'Exhale', duration: Duration(seconds: 4), expand: false),
  ],
  cycles: 4,
);

Future<void> _pumpPicker(
  WidgetTester tester, {
  required double width,
  required double textScale,
  List<CustomTechnique> techniques = const [_testTechnique],
}) async {
  await tester.binding.setSurfaceSize(Size(width, 720));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customTechniquesProvider
            .overrideWith((ref) => Stream.value(techniques)),
      ],
      child: MaterialApp(
        theme: AppTheme.focusTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const BreathingScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('пользовательская техника видна рядом со встроенными пресетами',
      (tester) async {
    await _pumpPicker(tester, width: 360, textScale: 1.0);

    // Встроенный пресет (локализованное имя) и пользовательская техника.
    expect(find.text('Box 4-4-4-4'), findsOneWidget);
    expect(find.text('My Box Breathing'), findsOneWidget);
    // Кнопка создания новой техники присутствует.
    expect(find.text('New technique'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('пользовательскую технику можно выбрать', (tester) async {
    await _pumpPicker(tester, width: 360, textScale: 1.0);
    await tester.tap(find.text('My Box Breathing'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('пикер без overflow на 320px при textScale 1.5', (tester) async {
    await _pumpPicker(tester, width: 320, textScale: 1.5);
    expect(find.text('My Box Breathing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
