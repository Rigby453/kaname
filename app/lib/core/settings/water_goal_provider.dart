// Дневная норма воды (мл). Настраивается в онбординге (шаг «нормы», SPEC C1)
// и в будущем в настройках профиля. Хранится в SharedPreferences.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

const _kWaterGoalKey = 'water_goal_ml';
const kDefaultWaterGoalMl = 2000;

class WaterGoalNotifier extends Notifier<int> {
  @override
  int build() =>
      ref.read(sharedPreferencesProvider).getInt(_kWaterGoalKey) ??
      kDefaultWaterGoalMl;

  Future<void> set(int ml) async {
    await ref.read(sharedPreferencesProvider).setInt(_kWaterGoalKey, ml);
    state = ml;
  }
}

final waterGoalProvider =
    NotifierProvider<WaterGoalNotifier, int>(WaterGoalNotifier.new);
