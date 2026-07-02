// theme_accent_test.dart
// Safety-net для батча «темы 4->2, акценты 6->11» (2026-07, см. ADR в
// /docs/decisions.md). app_theme.dart — единственный источник цветов, но
// несколько мест ДУБЛИРУЮТ его данные (UI-пикеры, l10n, design-tokens.json).
// Этот тест ловит рассинхрон:
//   - забыт AccentKey в _AccentPicker (profile_screen.dart);
//   - забыт AccentKey в _kAccentKeyColors (custom_theme_editor_screen.dart);
//   - забыт accent.<name> в l10n (core/l10n/strings/profile_paywall.dart);
//   - акцент не проходит WCAG-контраст (CR(on, accent) >= 4.5) на day/night;
//   - AppThemeKey.black/calm воскресли или миграция сломана.
//
// Чистый (pure) тест: проверки контраста/покрытия не требуют pump/pumpWidget.
// Единственное, что трогает Riverpod/SharedPreferences — миграция ключа темы
// (ThemeNotifier._migrateKey приватен, поэтому проверяем его публичным путём
// через themeNotifierProvider, без построения виджетов).

import 'dart:io' show File;
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/l10n/app_strings.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart'
    show sharedPreferencesProvider, themeNotifierProvider;
import 'package:app/features/profile/custom_theme_editor_screen.dart'
    show kAccentEditorColorsForTest;
import 'package:app/features/profile/profile_screen.dart'
    show kAccentPickerColorsForTest;

// ---------------------------------------------------------------------------
// WCAG 2.1 §1.4.3 — та же формула, что и CustomThemePalette._contrastRatio
// (private в app_theme.dart, часть библиотеки, недоступна извне). Стандартная
// математика, не бизнес-логика — дублирование тут безопасно и намеренно.
// ---------------------------------------------------------------------------

double _relativeLuminance(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

// ---------------------------------------------------------------------------
// ProviderContainer + SharedPreferences мок (копия паттерна из
// swipe_action_provider_test.dart) — без построения виджетов.
// ---------------------------------------------------------------------------

Future<ProviderContainer> _container(Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

// GoogleFonts в тестах: сеть отключена (flutter_test_config.dart:
// allowRuntimeFetching=false). AppTheme.build → GoogleFonts.hankenGroteskTextTheme
// пытается найти шрифт в ассетах и, не найдя, АСИНХРОННО бросает исключение
// (loadFontIfNecessary — fire-and-forget), которое раннер приписывает
// следующему тесту («failed after it had already completed»). Поэтому одиночный
// тест проходит, а весь файл — падает.
//
// Легитимный харнесс-фикс (скопирован из screens_smoke_all_test.dart): мокаем
// asset-бандл так, чтобы GoogleFonts нашёл шрифт в «ассетах». Ветка assetPath в
// loadFontIfNecessary не проверяет hash — подойдёт любой валидный TTF
// (локальный NotoSans.ttf под именами вариантов Fraunces/HankenGrotesk).
void _mockGoogleFontsAssets() {
  final fontBytes = File('test/fixtures/NotoSans.ttf').readAsBytesSync();
  final fontByteData = ByteData.sublistView(Uint8List.fromList(fontBytes));

  const fontAssetKeys = <String>[
    'assets/gf/Fraunces-Regular.ttf',
    'assets/gf/Fraunces-Bold.ttf',
    'assets/gf/Fraunces-Medium.ttf',
    'assets/gf/Fraunces-SemiBold.ttf',
    'assets/gf/HankenGrotesk-Regular.ttf',
    'assets/gf/HankenGrotesk-Bold.ttf',
    'assets/gf/HankenGrotesk-Medium.ttf',
    'assets/gf/HankenGrotesk-SemiBold.ttf',
    'assets/gf/AtkinsonHyperlegible-Regular.ttf',
    'assets/gf/AtkinsonHyperlegible-Bold.ttf',
  ];

  final manifest = <String, Object?>{
    for (final key in fontAssetKeys)
      key: <Object?>[
        <Object?, Object?>{'asset': key, 'dpr': null},
      ],
  };
  final manifestMessage = const StandardMessageCodec().encodeMessage(manifest)!;

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler('flutter/assets', (ByteData? message) async {
    final key = const StringCodec().decodeMessage(message);
    if (key == 'AssetManifest.bin') return manifestMessage;
    if (fontAssetKeys.contains(key)) return fontByteData;
    return null;
  });
}

void main() {
  setUpAll(() {
    // AppTheme.build обращается к GoogleFonts + ServicesBinding.instance —
    // в plain `test()` биндинг сам не поднимается (в отличие от testWidgets).
    TestWidgetsFlutterBinding.ensureInitialized();
    _mockGoogleFontsAssets();
  });

  group('AppThemeKey — сокращено до 2 тем (2026-07)', () {
    test('ровно {day, night} — Black/Calm убраны', () {
      expect(AppThemeKey.values.toSet(), {AppThemeKey.day, AppThemeKey.night});
    });

    test("старый prefs-ключ 'black' мигрирует на night", () async {
      final c = await _container({'app_theme_key': 'black'});
      expect(c.read(themeNotifierProvider), AppThemeKey.night);
    });

    test("старый prefs-ключ 'calm' мигрирует на day", () async {
      final c = await _container({'app_theme_key': 'calm'});
      expect(c.read(themeNotifierProvider), AppThemeKey.day);
    });

    test('прочие старые (v3) ключи по-прежнему мигрируют корректно', () async {
      final focus = await _container({'app_theme_key': 'focus'});
      expect(focus.read(themeNotifierProvider), AppThemeKey.night);

      final white = await _container({'app_theme_key': 'white'});
      expect(white.read(themeNotifierProvider), AppThemeKey.day);
    });

    test('неизвестный ключ безопасно откатывается на day', () async {
      final c = await _container({'app_theme_key': 'totally-unknown-key'});
      expect(c.read(themeNotifierProvider), AppThemeKey.day);
    });
  });

  group('AccentKey — расширено до 11 (2026-07)', () {
    test('минимум 11 кураторских акцентов, hard cap 22', () {
      expect(AccentKey.values.length, greaterThanOrEqualTo(11));
      expect(AccentKey.values.length, lessThanOrEqualTo(22));
    });

    for (final key in AccentKey.values) {
      test(
          '${key.name}: AppTheme.build не падает на day/night, '
          'CR(on, accent) >= 4.5 на обеих', () {
        for (final themeKey in AppThemeKey.values) {
          // Если key отсутствует в app_theme.dart _accentDefs, _accentFor
          // бросит null-check ошибку здесь (Map-lookup, а не exhaustive
          // switch) — это и есть "no fallback/crash" гарантия из ТЗ.
          final theme = AppTheme.build(theme: themeKey, accent: key);
          final cs = theme.colorScheme;
          final accent = cs.primary;
          final on = cs.onPrimary;
          final cr = _contrastRatio(on, accent);

          expect(
            cr,
            greaterThanOrEqualTo(4.5),
            reason: '${key.name} on $themeKey: CR(on=$on, accent=$accent) '
                '= ${cr.toStringAsFixed(2)} < 4.5',
          );
        }
      });
    }

    test('у каждого акцента есть непустое en+ru имя в S.all (accent.<name>)',
        () {
      for (final key in AccentKey.values) {
        final entry = S.all['accent.${key.name}'];
        expect(entry, isNotNull,
            reason: "отсутствует ключ l10n 'accent.${key.name}'");
        expect(entry!['en'], isNotNull,
            reason: "accent.${key.name} без 'en'");
        expect(entry['en']!.trim(), isNotEmpty,
            reason: "accent.${key.name}['en'] пустой");
        expect(entry['ru'], isNotNull,
            reason: "accent.${key.name} без 'ru'");
        expect(entry['ru']!.trim(), isNotEmpty,
            reason: "accent.${key.name}['ru'] пустой");
      }
    });

    test('каждый акцент присутствует в пикере профиля (_AccentPicker)', () {
      for (final key in AccentKey.values) {
        expect(kAccentPickerColorsForTest.containsKey(key), isTrue,
            reason:
                '${key.name} отсутствует в _AccentPicker._colors (profile_screen.dart)');
      }
      // Никаких лишних/устаревших ключей в пикере.
      expect(kAccentPickerColorsForTest.length, AccentKey.values.length);
    });

    test(
        'каждый акцент присутствует в редакторе custom-темы (_kAccentKeyColors)',
        () {
      for (final key in AccentKey.values) {
        expect(kAccentEditorColorsForTest.containsKey(key), isTrue,
            reason:
                '${key.name} отсутствует в _kAccentKeyColors (custom_theme_editor_screen.dart)');
      }
      expect(kAccentEditorColorsForTest.length, AccentKey.values.length);
    });
  });
}
