// Провайдер лимитов экранного времени — хранит Map<String,int> в SharedPreferences.
// Ключ: 'screen_time_limits', значение JSON {"social":60,"video":45,...}
// 0 = без лимита.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/theme_provider.dart'; // sharedPreferencesProvider

const _kPrefsKey = 'screen_time_limits';

/// Категории экранного времени с ключами, совпадающими с JSON-схемой.
/// Категория 'other' — информационная, без лимита (только показывает сумму).
const screenTimeCategories = <String, String>{
  'social': 'Social Media',
  'video': 'Video & Shorts',
  'games': 'Games',
  'browsing': 'Browsing',
  'messaging': 'Messaging',
  'other': 'Other',
};

/// Значения по умолчанию (0 = без лимита).
const _kDefaults = <String, int>{
  'social': 0,
  'video': 0,
  'games': 0,
  'browsing': 0,
  'messaging': 0,
  'other': 0,
};

class ScreenTimeLimitsNotifier extends StateNotifier<Map<String, int>> {
  ScreenTimeLimitsNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  /// Читаем из SharedPreferences при инициализации.
  static Map<String, int> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null) return Map.of(_kDefaults);
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = Map.of(_kDefaults);
      for (final key in result.keys) {
        if (decoded.containsKey(key)) {
          result[key] = (decoded[key] as num).toInt();
        }
      }
      return result;
    } catch (_) {
      return Map.of(_kDefaults);
    }
  }

  /// Устанавливаем лимит для категории и сразу сохраняем.
  Future<void> setLimit(String category, int minutes) async {
    final updated = Map.of(state)..[category] = minutes;
    state = updated;
    await _prefs.setString(_kPrefsKey, jsonEncode(updated));
  }
}

final screenTimeLimitsProvider =
    StateNotifierProvider<ScreenTimeLimitsNotifier, Map<String, int>>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return ScreenTimeLimitsNotifier(prefs);
});
