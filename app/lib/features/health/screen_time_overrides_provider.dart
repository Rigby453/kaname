// Пользовательские переопределения категорий экранного времени.
//
// Хранит карту packageName → ourCategory в SharedPreferences.
// Ключ: 'screen_time_overrides', формат JSON {"com.example.pkg": "games"}.
//
// Приоритет в aggregation: userOverride > whitelist > androidCategory > 'other'.
// Изменения применяются немедленно к отображению категории в per-app списке
// и на следующем refresh() провайдера screenTimeUsageProvider (к агрегированным итогам).

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/theme_provider.dart'; // sharedPreferencesProvider

const _kPrefsKey = 'screen_time_overrides';

/// Провайдер пользовательских переопределений: packageName → ourCategory.
class ScreenTimeOverridesNotifier
    extends StateNotifier<Map<String, String>> {
  ScreenTimeOverridesNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static Map<String, String> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return const {};
    }
  }

  /// Сохраняет пользовательский оверрайд для пакета.
  Future<void> setOverride(String packageName, String category) async {
    final updated = Map<String, String>.from(state)..[packageName] = category;
    state = updated;
    await _prefs.setString(_kPrefsKey, jsonEncode(updated));
  }

  /// Удаляет пользовательский оверрайд — приложение вернётся к автоопределению.
  Future<void> removeOverride(String packageName) async {
    final updated = Map<String, String>.from(state)..remove(packageName);
    state = updated;
    await _prefs.setString(_kPrefsKey, jsonEncode(updated));
  }
}

final screenTimeOverridesProvider =
    StateNotifierProvider<ScreenTimeOverridesNotifier, Map<String, String>>(
  (ref) {
    final prefs = ref.read(sharedPreferencesProvider);
    return ScreenTimeOverridesNotifier(prefs);
  },
);
