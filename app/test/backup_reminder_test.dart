// backup_reminder_test.dart
// G2: Тесты карточки «Напоминание о резервном копировании» (backup_reminder_card.dart).
//
// Покрытие:
//   1. Чистая функция shouldShowBackupReminder — все 4 комбинации.
//   2. Виджет BackupReminderCard — показ/скрытие по условиям.
//   3. Виджет — dismiss записывает флаг и скрывает карточку.
//   4. Нет overflow на 320px при textScale 2.0.
//
// Без pumpAndSettle (deadlock guard).
// Prefs — через SharedPreferences.setMockInitialValues.
// Гость/аккаунт — мок isGuestModeProvider.overrideWithValue.

import 'package:app/core/settings/app_usage.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/today/widgets/backup_reminder_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Вспомогательная тема — минимальная FocusThemeExtension
// ---------------------------------------------------------------------------

ThemeData _testTheme() => ThemeData.light().copyWith(
      extensions: const [
        FocusThemeExtension(
          textMuted: Color(0xFF8E8A85),
          ember: Color(0xFFFF6A3D),
          border: Color(0xFFE6E4DE),
          surfaceElevated: Color(0xFFFCFBF9),
          textFaint: Color(0xFFB9B5B0),
          accentMuted: Color(0xFFECEDFA),
          success: Color(0xFF4BAF6F),
          borderStrong: Color(0xFFD8D5CE),
          // textSecondary, accentTint, accentInk, danger — опциональны, используют defaults
        ),
      ],
    );

// ---------------------------------------------------------------------------
// Вспомогательный метод: оборачивает виджет в тестовое дерево
// ---------------------------------------------------------------------------

Widget _wrap(
  Widget child,
  SharedPreferences prefs, {
  required bool isGuest,
  required int launchCount,
  bool isDismissed = false,
  double width = 390,
  double textScale = 1.0,
}) {
  // Создаём AppUsage с нужным launchCount через prefs
  final usage = AppUsage(prefs);

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Мокаем гостевой режим напрямую — не зависит от API клиента в тестах
      isGuestModeProvider.overrideWithValue(isGuest),
      // appUsageProvider возвращает usage с launchCount из мокнутых prefs
      appUsageProvider.overrideWithValue(usage),
      // Флаг «закрыто» из prefs (StateProvider инициализируется через overrideWith)
      backupReminderDismissedProvider.overrideWith((ref) => isDismissed),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        size: Size(width, 800),
      ),
      child: MaterialApp(
        theme: _testTheme(),
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Минимальный settle без pumpAndSettle
// ---------------------------------------------------------------------------

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
}

// ---------------------------------------------------------------------------
// Вспомогательная инициализация prefs с нужным launchCount
// ---------------------------------------------------------------------------

Future<SharedPreferences> _prefsWithLaunchCount(int count) async {
  SharedPreferences.setMockInitialValues({
    kLaunchCountKey: count,
  });
  return SharedPreferences.getInstance();
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. Чистая функция — shouldShowBackupReminder
  // ═══════════════════════════════════════════════════════════════════════════

  group('shouldShowBackupReminder (чистая функция)', () {
    test('гость + launchCount >= 3 + не закрыто → true', () {
      expect(
        shouldShowBackupReminder(
          isGuest: true,
          launchCount: 3,
          isDismissed: false,
        ),
        isTrue,
      );
    });

    test('гость + launchCount > 3 + не закрыто → true (сохраняется при большем кол-ве запусков)',
        () {
      expect(
        shouldShowBackupReminder(
          isGuest: true,
          launchCount: 10,
          isDismissed: false,
        ),
        isTrue,
      );
    });

    test('гость + launchCount < 3 → false (слишком мало запусков)', () {
      expect(
        shouldShowBackupReminder(
          isGuest: true,
          launchCount: 2,
          isDismissed: false,
        ),
        isFalse,
      );
    });

    test('гость + launchCount == 0 → false', () {
      expect(
        shouldShowBackupReminder(
          isGuest: true,
          launchCount: 0,
          isDismissed: false,
        ),
        isFalse,
      );
    });

    test('не гость (есть аккаунт) + launchCount >= 3 → false', () {
      expect(
        shouldShowBackupReminder(
          isGuest: false,
          launchCount: 5,
          isDismissed: false,
        ),
        isFalse,
      );
    });

    test('гость + launchCount >= 3 + закрыто → false', () {
      expect(
        shouldShowBackupReminder(
          isGuest: true,
          launchCount: 5,
          isDismissed: true,
        ),
        isFalse,
      );
    });

    test('не гость + закрыто + launchCount >= 3 → false', () {
      expect(
        shouldShowBackupReminder(
          isGuest: false,
          launchCount: 10,
          isDismissed: true,
        ),
        isFalse,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. BackupReminderCard — показ/скрытие по условиям
  // ═══════════════════════════════════════════════════════════════════════════

  group('BackupReminderCard (виджет)', () {
    testWidgets('показывается для гостя при launchCount >= 3',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefs = await _prefsWithLaunchCount(3);
      await tester.pumpWidget(
        _wrap(
          const BackupReminderCard(),
          prefs,
          isGuest: true,
          launchCount: 3,
        ),
      );
      await _settle(tester);

      // Карточка видна: заголовок + кнопка «Войти»
      expect(find.text('Your data is local only'), findsOneWidget);
      expect(find.text('Sign in / enable sync'), findsOneWidget);
    });

    testWidgets('скрыта для гостя при launchCount < 3', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefs = await _prefsWithLaunchCount(2);
      await tester.pumpWidget(
        _wrap(
          const BackupReminderCard(),
          prefs,
          isGuest: true,
          launchCount: 2,
        ),
      );
      await _settle(tester);

      // SizedBox.shrink — ничего пользовательского не видно
      expect(find.text('Your data is local only'), findsNothing);
      expect(find.text('Sign in / enable sync'), findsNothing);
    });

    testWidgets('скрыта при launchCount == 0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefs = await _prefsWithLaunchCount(0);
      await tester.pumpWidget(
        _wrap(
          const BackupReminderCard(),
          prefs,
          isGuest: true,
          launchCount: 0,
        ),
      );
      await _settle(tester);

      expect(find.text('Your data is local only'), findsNothing);
    });

    testWidgets('скрыта для авторизованного пользователя (не гость)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefs = await _prefsWithLaunchCount(10);
      await tester.pumpWidget(
        _wrap(
          const BackupReminderCard(),
          prefs,
          isGuest: false, // ← есть аккаунт
          launchCount: 10,
        ),
      );
      await _settle(tester);

      expect(find.text('Your data is local only'), findsNothing);
    });

    testWidgets('скрыта если пользователь уже закрыл (isDismissed=true)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefs = await _prefsWithLaunchCount(5);
      await tester.pumpWidget(
        _wrap(
          const BackupReminderCard(),
          prefs,
          isGuest: true,
          launchCount: 5,
          isDismissed: true, // ← уже закрыто
        ),
      );
      await _settle(tester);

      expect(find.text('Your data is local only'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. Dismiss — записывает prefs-флаг и скрывает карточку
  // ═══════════════════════════════════════════════════════════════════════════

  group('BackupReminderCard — dismiss', () {
    testWidgets('нажатие крестика скрывает карточку и ставит флаг в prefs',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefs = await _prefsWithLaunchCount(4);
      await tester.pumpWidget(
        _wrap(
          const BackupReminderCard(),
          prefs,
          isGuest: true,
          launchCount: 4,
          isDismissed: false,
        ),
      );
      await _settle(tester);

      // Карточка видна
      expect(find.text('Your data is local only'), findsOneWidget);

      // Нажимаем крестик (Dismiss)
      await tester.tap(find.byTooltip('Dismiss'));
      // Callback асинхронный — даём два pump-прохода для завершения microtask-а
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      // Карточка скрыта — StateProvider обновился → showBackupReminderProvider=false
      expect(find.text('Your data is local only'), findsNothing);

      // Prefs-флаг выставлен
      expect(prefs.getBool(kBackupReminderDismissedKey), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. Overflow: 320px + textScale 2.0
  // ═══════════════════════════════════════════════════════════════════════════

  group('BackupReminderCard — overflow safety', () {
    testWidgets('нет overflow на 320px при textScale 2.0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefs = await _prefsWithLaunchCount(5);
      await tester.pumpWidget(
        _wrap(
          const BackupReminderCard(),
          prefs,
          isGuest: true,
          launchCount: 5,
          isDismissed: false,
          width: 320,
          textScale: 2.0,
        ),
      );
      await _settle(tester);

      // Карточка видна — убеждаемся, что нет исключений (overflow)
      expect(tester.takeException(), isNull);
      expect(find.text('Your data is local only'), findsOneWidget);
    });

    testWidgets('нет overflow на 320px при textScale 1.5', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefs = await _prefsWithLaunchCount(3);
      await tester.pumpWidget(
        _wrap(
          const BackupReminderCard(),
          prefs,
          isGuest: true,
          launchCount: 3,
          isDismissed: false,
          width: 320,
          textScale: 1.5,
        ),
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
    });
  });
}
