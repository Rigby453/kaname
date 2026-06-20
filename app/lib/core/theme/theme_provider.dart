// Riverpod провайдер темы — хранит выбранный ключ в SharedPreferences
// Значение по умолчанию: focus (согласно design-tokens.json "default": true)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'custom_theme_provider.dart';
import '../mood/mood_provider.dart';

const _kThemePrefsKey = 'app_theme_key';

/// Провайдер SharedPreferences — инициализируется в main перед ProviderScope
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'SharedPreferences must be overridden in ProviderScope',
  ),
);

/// Нотифер: хранит и переключает тему, персистируя ключ в SharedPreferences
class ThemeNotifier extends Notifier<AppThemeKey> {
  @override
  AppThemeKey build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(_kThemePrefsKey);
    if (saved == null) {
      // Тема ещё не выбрана → по умолчанию следуем системной яркости:
      // светлая система → White, тёмная → Black. В онбординге/профиле
      // пользователь может выбрать другую (Focus/Calm/Contrast/свою) — выбор
      // сохраняется и дальше имеет приоритет над системой.
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark
          ? AppThemeKey.black
          : AppThemeKey.white;
    }

    return AppThemeKey.values.firstWhere(
      (k) => k.prefsKey == saved,
      orElse: () => AppThemeKey.focus,
    );
  }

  /// Переключить тему и сохранить в SharedPreferences
  Future<void> setTheme(AppThemeKey key) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kThemePrefsKey, key.prefsKey);
    state = key;
  }
}

/// Провайдер ключа темы
final themeNotifierProvider =
    NotifierProvider<ThemeNotifier, AppThemeKey>(ThemeNotifier.new);

/// Удобный провайдер ThemeData — используется в MaterialApp.router.
/// Поддерживает custom-тему и реактивное настроение (mood harshness).
/// При дефолтных настройках harshness=0.0 → цвета без изменений.
final themeDataProvider = Provider<ThemeData>((ref) {
  final key = ref.watch(themeNotifierProvider);
  final customConfig = ref.watch(customThemeNotifierProvider);
  // Наблюдаем за harshness из effectiveMoodProvider.
  // При дефолте (intensity=off, tone=gentle) harshness=0 → тема не меняется.
  final mood = ref.watch(effectiveMoodProvider);
  return AppTheme.forKeyWithCustom(key, customConfig, harshness: mood.harshness);
});
