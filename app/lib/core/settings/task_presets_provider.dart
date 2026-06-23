// Настраиваемые пресеты для формы создания задачи:
//   - durationPresetsProvider  — быстрые варианты длительности (минуты);
//   - reminderPresetsProvider  — быстрые варианты «напомнить за N минут до».
//
// Оба хранятся в SharedPreferences как список int (через setStringList, чтобы
// не зависеть от отсутствующего setIntList). Паттерн — Notifier + NotifierProvider
// по образцу sound_provider / swipe_action_provider. UI редактирования — в Профиле
// (секция «Задачи по умолчанию»); форма создания задачи (другой агент) читает эти
// списки для чипов быстрого выбора.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

// ---------------------------------------------------------------------------
// Ключи SharedPreferences
// ---------------------------------------------------------------------------

/// Пресеты длительности задачи в минутах (string-list).
const String kDurationPresetsKey = 'duration_presets';

/// Пресеты напоминаний «за N минут до» (string-list; 0 = «в момент»).
const String kReminderPresetsKey = 'reminder_presets';

// ---------------------------------------------------------------------------
// Дефолты
// ---------------------------------------------------------------------------

const List<int> kDefaultDurationPresets = [15, 30, 45, 60, 90];
const List<int> kDefaultReminderPresets = [0, 10, 30, 60, 1440];

/// Максимум пресетов в списке (чтобы UI не разрастался).
const int _kMaxPresets = 8;

// ---------------------------------------------------------------------------
// Хелперы валидации
// ---------------------------------------------------------------------------

/// Нормализует список пресетов длительности: оставляет 1..1440, делает уникальными,
/// сортирует по возрастанию и ограничивает [_kMaxPresets]. Если результат пуст —
/// возвращает [fallback].
List<int> _normalizeDuration(List<int> input, List<int> fallback) {
  final cleaned = input.where((m) => m >= 1 && m <= 1440).toSet().toList()
    ..sort();
  if (cleaned.isEmpty) return List<int>.from(fallback);
  return cleaned.take(_kMaxPresets).toList();
}

/// Нормализует список пресетов напоминаний: оставляет 0..1440 (0 = «в момент»),
/// уникальные, сортирует, ограничивает [_kMaxPresets].
List<int> _normalizeReminder(List<int> input, List<int> fallback) {
  final cleaned = input.where((m) => m >= 0 && m <= 1440).toSet().toList()
    ..sort();
  if (cleaned.isEmpty) return List<int>.from(fallback);
  return cleaned.take(_kMaxPresets).toList();
}

/// Читает список int, сохранённый как list of strings. Невалидные элементы
/// отбрасываются. Если ключ отсутствует — возвращает null.
List<int>? _readIntList(List<String>? raw) {
  if (raw == null) return null;
  final parsed = <int>[];
  for (final s in raw) {
    final v = int.tryParse(s);
    if (v != null) parsed.add(v);
  }
  return parsed;
}

// ---------------------------------------------------------------------------
// Duration presets
// ---------------------------------------------------------------------------

class DurationPresetsNotifier extends Notifier<List<int>> {
  @override
  List<int> build() {
    final raw =
        ref.read(sharedPreferencesProvider).getStringList(kDurationPresetsKey);
    final stored = _readIntList(raw);
    if (stored == null) return List<int>.from(kDefaultDurationPresets);
    return _normalizeDuration(stored, kDefaultDurationPresets);
  }

  /// Задать новый набор пресетов длительности (валидируется/нормализуется).
  Future<void> setPresets(List<int> presets) async {
    final normalized = _normalizeDuration(presets, kDefaultDurationPresets);
    await ref.read(sharedPreferencesProvider).setStringList(
          kDurationPresetsKey,
          normalized.map((e) => e.toString()).toList(),
        );
    state = normalized;
  }
}

/// Пресеты длительности задачи (минуты). Читается формой создания задачи.
final durationPresetsProvider =
    NotifierProvider<DurationPresetsNotifier, List<int>>(
  DurationPresetsNotifier.new,
);

// ---------------------------------------------------------------------------
// Reminder presets
// ---------------------------------------------------------------------------

class ReminderPresetsNotifier extends Notifier<List<int>> {
  @override
  List<int> build() {
    final raw =
        ref.read(sharedPreferencesProvider).getStringList(kReminderPresetsKey);
    final stored = _readIntList(raw);
    if (stored == null) return List<int>.from(kDefaultReminderPresets);
    return _normalizeReminder(stored, kDefaultReminderPresets);
  }

  /// Задать новый набор пресетов напоминаний (минуты до; 0 = «в момент»).
  Future<void> setPresets(List<int> presets) async {
    final normalized = _normalizeReminder(presets, kDefaultReminderPresets);
    await ref.read(sharedPreferencesProvider).setStringList(
          kReminderPresetsKey,
          normalized.map((e) => e.toString()).toList(),
        );
    state = normalized;
  }
}

/// Пресеты напоминаний (минуты до начала; 0 = «в момент»).
/// Читается формой создания задачи.
final reminderPresetsProvider =
    NotifierProvider<ReminderPresetsNotifier, List<int>>(
  ReminderPresetsNotifier.new,
);
