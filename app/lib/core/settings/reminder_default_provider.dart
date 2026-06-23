// Глобальное напоминание по умолчанию для новых задач.
// Определяет, для каких задач при создании автоматически предлагается/ставится
// напоминание и за сколько минут до начала.
//
// Хранение в SharedPreferences по образцу sound_provider / swipe_action_provider:
// Notifier + NotifierProvider. UI настройки — в Профиле (секция «Задачи по
// умолчанию»). Сама форма создания задачи (другой агент) читает этот провайдер,
// чтобы предзаполнить напоминание.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

// ---------------------------------------------------------------------------
// Ключи SharedPreferences
// ---------------------------------------------------------------------------

/// Режим напоминания по умолчанию (string): 'none'|'main'|'all'.
const String kReminderDefaultModeKey = 'reminder_default_mode';

/// Минуты до начала задачи для напоминания по умолчанию (int).
const String kReminderDefaultMinutesKey = 'reminder_default_minutes';

// ---------------------------------------------------------------------------
// Модель
// ---------------------------------------------------------------------------

/// Настройка напоминания по умолчанию.
///
/// [mode] — для каких задач ставить напоминание по умолчанию:
///   'none' — не напоминать по умолчанию (дефолт),
///   'main' — только задачи с приоритетом 'main' (главные),
///   'all'  — все задачи.
/// [minutes] — за сколько минут до начала напоминать (дефолт 15).
class ReminderDefault {
  const ReminderDefault({
    this.mode = 'none',
    this.minutes = 15,
  });

  final String mode;
  final int minutes;

  ReminderDefault copyWith({String? mode, int? minutes}) => ReminderDefault(
        mode: mode ?? this.mode,
        minutes: minutes ?? this.minutes,
      );

  @override
  bool operator ==(Object other) =>
      other is ReminderDefault &&
      other.mode == mode &&
      other.minutes == minutes;

  @override
  int get hashCode => Object.hash(mode, minutes);
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Допустимые режимы напоминания.
const Set<String> _kValidModes = {'none', 'main', 'all'};

class ReminderDefaultNotifier extends Notifier<ReminderDefault> {
  @override
  ReminderDefault build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final mode = prefs.getString(kReminderDefaultModeKey);
    final minutes = prefs.getInt(kReminderDefaultMinutesKey);
    return ReminderDefault(
      mode: (mode != null && _kValidModes.contains(mode)) ? mode : 'none',
      minutes: (minutes != null && minutes >= 0) ? minutes : 15,
    );
  }

  /// Задать режим напоминания по умолчанию ('none'|'main'|'all').
  /// Невалидное значение игнорируется.
  Future<void> setMode(String mode) async {
    if (!_kValidModes.contains(mode)) return;
    await ref.read(sharedPreferencesProvider).setString(
          kReminderDefaultModeKey,
          mode,
        );
    state = state.copyWith(mode: mode);
  }

  /// Задать минуты до начала (>= 0). Отрицательные игнорируются.
  Future<void> setMinutes(int minutes) async {
    if (minutes < 0) return;
    await ref.read(sharedPreferencesProvider).setInt(
          kReminderDefaultMinutesKey,
          minutes,
        );
    state = state.copyWith(minutes: minutes);
  }
}

/// Напоминание по умолчанию для новых задач. Читается формой создания задачи.
final reminderDefaultProvider =
    NotifierProvider<ReminderDefaultNotifier, ReminderDefault>(
  ReminderDefaultNotifier.new,
);
