// Галерея локализаций: рендерит ~12 ключевых строк на каждом из 12 языков
// и сохраняет PNG golden-файл. Цель — визуально убедиться, что переводы
// и шрифты (латиница/кириллица/деванагари/CJK) отображаются корректно.
//
// Запуск: flutter test --update-goldens test/locale_gallery_test.dart
// Результат: app/test/goldens/locale_<tag>.png (12 файлов)

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/l10n/app_strings.dart';
import 'package:app/core/l10n/locale_provider.dart';

// Ключи, существование которых проверено в strings/*.dart.
// Порядок: nav, today, btn, profile, paywall, food, health, auth.tagline.
const List<String> _keys = [
  'nav.today',        // common.dart — Today/Сегодня/Heute/...
  'nav.plan',         // common.dart — Plan
  'nav.health',       // common.dart — Health
  'today.main_tasks', // common.dart — Main today
  'today.greeting_morning', // common.dart — Good morning
  'btn.add',          // common.dart — Add
  'btn.cancel',       // common.dart — Cancel
  'btn.done',         // common.dart — Done
  'profile.title',    // common.dart — Profile
  'paywall.title',    // profile_paywall.dart — Kaizen Premium
  'health.water',     // common.dart — Water
  'auth.tagline',     // misc.dart — "The important stuff won't slip."
];

void main() {
  setUpAll(() async {
    // Загружаем базовый латино-кириллический шрифт из fixtures.
    // Покрывает: en, ru, de, fr, it, es, pt, id.
    final notoBase = File('test/fixtures/NotoSans.ttf').readAsBytesSync();
    final fontLoaderBase = FontLoader('NotoBase')
      ..addFont(Future.value(ByteData.sublistView(notoBase)));
    await fontLoaderBase.load();

    // Загружаем вшитые ассеты через rootBundle для деванагари / JP / KR.
    // rootBundle в тестах отдаёт ассеты, зарегистрированные в pubspec.yaml.
    final devanagariBytes =
        await rootBundle.load('assets/fonts/NotoSansDevanagari.ttf');
    final fontLoaderDev = FontLoader('Noto Sans Devanagari')
      ..addFont(Future.value(devanagariBytes));
    await fontLoaderDev.load();

    final jpBytes = await rootBundle.load('assets/fonts/NotoSansJP.ttf');
    final fontLoaderJP = FontLoader('Noto Sans JP')
      ..addFont(Future.value(jpBytes));
    await fontLoaderJP.load();

    final krBytes = await rootBundle.load('assets/fonts/NotoSansKR.ttf');
    final fontLoaderKR = FontLoader('Noto Sans KR')
      ..addFont(Future.value(krBytes));
    await fontLoaderKR.load();
  });

  for (final entry in localeEntries) {
    final locale = entry.locale;
    final tag = localeTag(locale);

    testWidgets('locale_gallery: $tag — ${entry.displayName}',
        (WidgetTester tester) async {
      // Устанавливаем размер экрана: 460 × 900 px (высокий кадр).
      await tester.binding.setSurfaceSize(const Size(460, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          home: DefaultTextStyle(
            // NotoBase покрывает латиницу и кириллицу;
            // fallback-семейства обрабатывают деванагари / японский / корейский.
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontFamily: 'NotoBase',
              fontFamilyFallback: [
                'Noto Sans Devanagari',
                'Noto Sans JP',
                'Noto Sans KR',
              ],
            ),
            child: Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Builder(
                    builder: (context) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Подпись языка: displayName крупно лаймовым.
                        Text(
                          entry.displayName,
                          style: const TextStyle(
                            color: Color(0xFFD9F24B), // lime accent
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'NotoBase',
                            fontFamilyFallback: [
                              'Noto Sans Devanagari',
                              'Noto Sans JP',
                              'Noto Sans KR',
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Строки переводов.
                        ..._keys.map(
                          (key) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: _LocaleRow(key: key),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/locale_$tag.png'),
      );
    });
  }
}

/// Виджет-строка: показывает сам ключ (серым) и его перевод (белым).
class _LocaleRow extends StatelessWidget {
  const _LocaleRow({required String key}) : _k = key;
  final String _k;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_k  ',
          style: const TextStyle(
            color: Color(0xFF9E9070),
            fontSize: 13,
            fontFamily: 'NotoBase',
          ),
        ),
        Expanded(
          child: Text(
            context.s(_k),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'NotoBase',
              fontFamilyFallback: [
                'Noto Sans Devanagari',
                'Noto Sans JP',
                'Noto Sans KR',
              ],
            ),
          ),
        ),
      ],
    );
  }
}
