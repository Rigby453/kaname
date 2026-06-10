// Дневные нормы питания (калории, белок). Пока задаются дефолтами и хранятся
// в SharedPreferences; после переработки онбординга (бэклог ревью MVP) будут
// считаться из параметров пользователя (вес/возраст/цель).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

const _kCalorieGoalKey = 'calorie_goal_kcal';
const _kProteinGoalKey = 'protein_goal_g';
const kDefaultCalorieGoal = 2000;
const kDefaultProteinGoalG = 60;

class CalorieGoalNotifier extends Notifier<int> {
  @override
  int build() =>
      ref.read(sharedPreferencesProvider).getInt(_kCalorieGoalKey) ??
      kDefaultCalorieGoal;

  Future<void> set(int kcal) async {
    await ref.read(sharedPreferencesProvider).setInt(_kCalorieGoalKey, kcal);
    state = kcal;
  }
}

class ProteinGoalNotifier extends Notifier<int> {
  @override
  int build() =>
      ref.read(sharedPreferencesProvider).getInt(_kProteinGoalKey) ??
      kDefaultProteinGoalG;

  Future<void> set(int grams) async {
    await ref.read(sharedPreferencesProvider).setInt(_kProteinGoalKey, grams);
    state = grams;
  }
}

final calorieGoalProvider =
    NotifierProvider<CalorieGoalNotifier, int>(CalorieGoalNotifier.new);
final proteinGoalProvider =
    NotifierProvider<ProteinGoalNotifier, int>(ProteinGoalNotifier.new);
