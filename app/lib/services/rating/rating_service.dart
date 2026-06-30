// Сервис запроса оценки приложения (фича E3).
//
// Политика (чистая функция shouldRequestRating, тестируемая отдельно):
//   – Не показывает при первом входе.
//   – Показывает после «момента ценности» (завершение задачи в today_screen).
//   – launchCount >= 4 ИЛИ daysSinceFirstLaunch >= 3 (условие ИЛИ).
//   – Показывает ровно ОДИН РАЗ (prefs-флаг rating_requested=true).
//   – На web/desktop InAppReview.isAvailable() вернёт false → тихо no-op.
//   – Все исключения поглощаются → завершение задачи никогда не падает.
//
// Точка вызова: _TodayTimelineState._doDone() (today_screen.dart)
//   fire-and-forget: `.ignore()` — не блокирует UI.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/settings/app_usage.dart';
import '../../core/theme/theme_provider.dart'; // sharedPreferencesProvider

// ---------------------------------------------------------------------------
// Константы
// ---------------------------------------------------------------------------

/// Prefs-флаг: запрос уже показан, повторно не показываем.
const String kRatingRequestedKey = 'rating_requested';

/// Минимум запусков для показа запроса.
const int kRatingMinLaunchCount = 4;

/// Минимум дней с первого запуска (альтернативный критерий — «ИЛИ»).
const int kRatingMinDaysSinceFirstLaunch = 3;

// ---------------------------------------------------------------------------
// Абстракция InAppReview — позволяет инъекцию в тестах
// ---------------------------------------------------------------------------

abstract class InAppReviewDelegate {
  Future<bool> isAvailable();
  Future<void> requestReview();
}

class _RealInAppReview implements InAppReviewDelegate {
  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();
}

// ---------------------------------------------------------------------------
// Политика — чистая функция (тестируется без Flutter/Drift/prefs)
// ---------------------------------------------------------------------------

/// Возвращает true если по политике следует показать нативный запрос оценки.
bool shouldRequestRating({
  required int launchCount,
  required int daysSinceFirstLaunch,
  required bool alreadyRequested,
}) {
  if (alreadyRequested) return false;
  // Условие ИЛИ: достаточно запусков ИЛИ достаточно дней
  return launchCount >= kRatingMinLaunchCount ||
      daysSinceFirstLaunch >= kRatingMinDaysSinceFirstLaunch;
}

// ---------------------------------------------------------------------------
// RatingService
// ---------------------------------------------------------------------------

class RatingService {
  /// [prefs] — SharedPreferences для чтения счётчика и записи флага.
  /// [review] — инъекция для тестов; production использует InAppReview.instance.
  RatingService(this._prefs, {InAppReviewDelegate? review})
      : _review = review ?? _RealInAppReview();

  final SharedPreferences _prefs;
  final InAppReviewDelegate _review;

  /// Мягко показывает нативный запрос оценки, если политика разрешает.
  ///
  /// Вызывать fire-and-forget (`.ignore()`): не блокирует UI, не кидает.
  /// Все ошибки поглощаются; флаг [kRatingRequestedKey] пишется только
  /// если нативный диалог реально запрошен.
  Future<void> maybeRequestReview() async {
    final launch = getLaunchCount(_prefs);
    final days = getDaysSinceFirstLaunch(_prefs);
    final already = _prefs.getBool(kRatingRequestedKey) ?? false;

    if (!shouldRequestRating(
      launchCount: launch,
      daysSinceFirstLaunch: days,
      alreadyRequested: already,
    )) {
      return;
    }

    try {
      final available = await _review.isAvailable();
      if (!available) return;
      await _review.requestReview();
      await _prefs.setBool(kRatingRequestedKey, true);
    } catch (_) {
      // Web / desktop / сетевые ошибки — тихо игнорируем
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod провайдер
// ---------------------------------------------------------------------------

final ratingServiceProvider = Provider<RatingService>((ref) {
  return RatingService(ref.read(sharedPreferencesProvider));
});
