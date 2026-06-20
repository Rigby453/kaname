// Тон общения приложения: gentle (мягкий) / harsh (жёсткий).
// Влияет ТОЛЬКО на тексты, не на логику (правило из app/CLAUDE.md).
// Сохраняется в SharedPreferences.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../theme/theme_provider.dart'; // sharedPreferencesProvider

enum AppTone { gentle, harsh }

const _kToneKey = 'tone_preference';

class ToneNotifier extends Notifier<AppTone> {
  @override
  AppTone build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_kToneKey);
    return saved == 'harsh' ? AppTone.harsh : AppTone.gentle;
  }

  Future<void> toggle() => set(state == AppTone.gentle ? AppTone.harsh : AppTone.gentle);

  Future<void> set(AppTone tone) async {
    await ref.read(sharedPreferencesProvider).setString(
          _kToneKey,
          tone == AppTone.harsh ? 'harsh' : 'gentle',
        );
    state = tone;
  }
}

final toneProvider = NotifierProvider<ToneNotifier, AppTone>(ToneNotifier.new);

/// Локализованные Kai-строки для речевого пузыря (MASCOT.md §4, SPEC B6).
/// Принимает BuildContext — резолвит через систему переводов S.
/// Шаблон {count} заменяется вручную на сайте вызова.
class KaiCopy {
  KaiCopy._();

  /// Утренний разбор.
  static String morningReview(BuildContext context, AppTone tone, int count) {
    if (tone == AppTone.harsh) {
      final key = count == 1
          ? 'kai.morning_review_harsh_one'
          : 'kai.morning_review_harsh_many';
      return S.of(context, key).replaceAll('{count}', '$count');
    }
    final key = count == 1
        ? 'kai.morning_review_gentle_one'
        : 'kai.morning_review_gentle_many';
    return S.of(context, key).replaceAll('{count}', '$count');
  }

  /// Строка для шапки Today — все выполнено.
  static String allDone(BuildContext context, AppTone tone) {
    final key = tone == AppTone.harsh ? 'kai.all_done_harsh' : 'kai.all_done_gentle';
    return S.of(context, key);
  }

  /// Вечерний разбор.
  static String eveningReview(BuildContext context, AppTone tone, int pending) {
    if (tone == AppTone.harsh) {
      final key =
          pending == 0 ? 'kai.evening_none_harsh' : 'kai.evening_pending_harsh';
      return S.of(context, key).replaceAll('{count}', '$pending');
    }
    final key =
        pending == 0 ? 'kai.evening_none_gentle' : 'kai.evening_pending_gentle';
    return S.of(context, key).replaceAll('{count}', '$pending');
  }

  /// Пустое состояние — ничего не запланировано.
  static String emptyDay(BuildContext context, AppTone tone) {
    final key =
        tone == AppTone.harsh ? 'kai.empty_day_harsh' : 'kai.empty_day_gentle';
    return S.of(context, key);
  }

  /// Нейтральный idle (по времени суток).
  static String idle(BuildContext context, AppTone tone, DateTime now) {
    final hour = now.hour;
    final timeKey =
        hour < 12 ? 'morning' : (hour < 18 ? 'afternoon' : 'evening');
    final toneKey = tone == AppTone.harsh ? 'harsh' : 'gentle';
    return S.of(context, 'kai.idle_${timeKey}_$toneKey');
  }
}
