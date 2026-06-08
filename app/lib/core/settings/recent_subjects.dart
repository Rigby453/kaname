// Недавние предметы/названия (для быстрого добавления занятий и экзаменов, C4).
// Хранится список последних названий событий/экзаменов в SharedPreferences —
// без отдельной модели Subject и без миграции БД.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

const _kRecentSubjectsKey = 'recent_subjects';
const int kRecentSubjectsCap = 8;

/// Чистая функция: добавляет [title] в начало списка, убирает дубликаты
/// (без учёта регистра) и обрезает до [cap]. Пустые строки игнорируются.
List<String> mergeRecent(
  List<String> current,
  String title, {
  int cap = kRecentSubjectsCap,
}) {
  final t = title.trim();
  if (t.isEmpty) return List<String>.from(current);
  final rest = current.where((e) => e.toLowerCase() != t.toLowerCase());
  return [t, ...rest].take(cap).toList();
}

class RecentSubjects {
  RecentSubjects(this._prefs);
  final SharedPreferences _prefs;

  List<String> get all =>
      _prefs.getStringList(_kRecentSubjectsKey) ?? const <String>[];

  Future<void> add(String title) async {
    final merged = mergeRecent(all, title);
    if (merged.isEmpty) return;
    await _prefs.setStringList(_kRecentSubjectsKey, merged);
  }
}

final recentSubjectsProvider = Provider<RecentSubjects>((ref) {
  return RecentSubjects(ref.read(sharedPreferencesProvider));
});
