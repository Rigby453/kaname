// Чистая функция вычисления прогресса цели по шагам.
// Используется в GoalsScreen для LinearProgressIndicator.

import '../../core/database/database.dart';

/// Возвращает долю выполненных шагов (0.0..1.0).
/// Если шагов нет — возвращает 0.0.
double goalProgress(List<GoalStepsTableData> steps) {
  if (steps.isEmpty) return 0.0;
  final doneCount = steps.where((s) => s.done).length;
  return doneCount / steps.length;
}
