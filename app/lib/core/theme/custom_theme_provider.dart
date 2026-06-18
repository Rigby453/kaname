// Riverpod-провайдер пользовательской конфигурации темы.
// Хранит три входных параметра алгоритма вывода (05-custom-theme.md §4).
// Паттерн зеркалит mascot_provider.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_provider.dart'; // sharedPreferencesProvider

// --- Ключи SharedPreferences ---
const _kCustomThemeSet = 'custom_theme_set';
const _kCustomThemeMode = 'custom_theme_mode';
const _kCustomThemeAccentHex = 'custom_theme_accent_hex';
const _kCustomThemeBgHueDelta = 'custom_theme_bg_hue_delta';

/// Конфигурация пользовательской темы — только входные параметры.
/// Полная палитра каждый раз выводится заново из этих трёх значений.
class CustomThemeConfig {
  const CustomThemeConfig({
    required this.isDark,
    required this.accentColor,
    this.bgHueDelta = 0,
  });

  final bool isDark;
  final Color accentColor;
  final int bgHueDelta; // −30..+30

  @override
  bool operator ==(Object other) =>
      other is CustomThemeConfig &&
      other.isDark == isDark &&
      other.accentColor == accentColor &&
      other.bgHueDelta == bgHueDelta;

  @override
  int get hashCode => Object.hash(isDark, accentColor, bgHueDelta);
}

/// Нотифер пользовательской конфигурации темы.
/// Состояние null = конфигурация ещё не сохранена.
class CustomThemeNotifier extends Notifier<CustomThemeConfig?> {
  @override
  CustomThemeConfig? build() {
    final prefs = ref.read(sharedPreferencesProvider);
    // Синхронное чтение — безопасно при холодном старте (05-custom-theme.md §4)
    if (prefs.getBool(_kCustomThemeSet) != true) return null;

    final modeStr = prefs.getString(_kCustomThemeMode) ?? 'dark';
    final accentInt = prefs.getInt(_kCustomThemeAccentHex) ?? 0xFFD9F24B;
    final delta = prefs.getInt(_kCustomThemeBgHueDelta) ?? 0;

    return CustomThemeConfig(
      isDark: modeStr == 'dark',
      accentColor: Color(accentInt),
      bgHueDelta: delta.clamp(-30, 30),
    );
  }

  /// Сохраняет конфигурацию и обновляет состояние.
  Future<void> save(CustomThemeConfig config) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_kCustomThemeSet, true);
    await prefs.setString(
        _kCustomThemeMode, config.isDark ? 'dark' : 'light');
    await prefs.setInt(_kCustomThemeAccentHex, config.accentColor.toARGB32());
    await prefs.setInt(
        _kCustomThemeBgHueDelta, config.bgHueDelta.clamp(-30, 30));
    state = config;
  }

  /// Сбрасывает конфигурацию (custom_theme_set = false) → состояние = null.
  Future<void> reset() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_kCustomThemeSet, false);
    state = null;
  }
}

/// Провайдер конфигурации пользовательской темы.
/// null — конфигурация не задана.
final customThemeNotifierProvider =
    NotifierProvider<CustomThemeNotifier, CustomThemeConfig?>(
        CustomThemeNotifier.new);
