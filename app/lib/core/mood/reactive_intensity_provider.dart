// Провайдер интенсивности реактивного настроения.
// Управляет тем, насколько сильно «реальный» прогресс дня влияет на вид Kai и тему.
// Хранится в SharedPreferences: ключ 'reactive_intensity'.
// Дефолт: off (обратная совместимость — при off вид не меняется).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

/// Интенсивность реактивного настроения.
/// off    → движок отключён, вид как раньше (multiplier = 0.0).
/// slight → слегка подогревает тему (multiplier = 0.5).
/// full   → полное влияние (multiplier = 1.0).
enum ReactiveIntensity { off, slight, full }

const _kReactiveIntensityKey = 'reactive_intensity';

/// Нотифер: читает/пишет ReactiveIntensity в SharedPreferences.
class ReactiveIntensityNotifier extends Notifier<ReactiveIntensity> {
  @override
  ReactiveIntensity build() {
    final saved = ref
        .read(sharedPreferencesProvider)
        .getString(_kReactiveIntensityKey);
    return switch (saved) {
      'slight' => ReactiveIntensity.slight,
      'full' => ReactiveIntensity.full,
      _ => ReactiveIntensity.off, // дефолт off
    };
  }

  Future<void> set(ReactiveIntensity value) async {
    await ref.read(sharedPreferencesProvider).setString(
          _kReactiveIntensityKey,
          value.name, // 'off' | 'slight' | 'full'
        );
    state = value;
  }
}

final reactiveIntensityProvider =
    NotifierProvider<ReactiveIntensityNotifier, ReactiveIntensity>(
  ReactiveIntensityNotifier.new,
);

/// Числовой множитель интенсивности: off=0.0, slight=0.5, full=1.0.
extension ReactiveIntensityMultiplier on ReactiveIntensity {
  double get multiplier => switch (this) {
        ReactiveIntensity.off => 0.0,
        ReactiveIntensity.slight => 0.5,
        ReactiveIntensity.full => 1.0,
      };
}
