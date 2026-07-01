// Соглашение о «форме» задачи через существующее поле durationMinutes — БЕЗ
// новой колонки/миграции БД, оно синкается как есть (см. api-spec.yaml,
// data-model.md — контракт не меняется):
//
//   durationMinutes  > 0  → [TaskShape.block]  — обычная задача, занимает
//                            окно длительностью N минут (как раньше).
//   durationMinutes == 0  → [TaskShape.moment] — «момент»: есть время
//                            (scheduledAt), длительности нет. На сетке —
//                            МАРКЕР/точка, не блок. Пример: «таблетка 14:00».
//   durationMinutes == -1 → [TaskShape.open]   — «только начало» (открытый
//                            конец): есть время начала, конца нет. На сетке —
//                            блок, тянущийся до следующего события дня или до
//                            конца видимой сетки. Пример: «сесть за учёбу 15:00».
//
// Все места, читающие durationMinutes ради решения «что нарисовать/как
// посчитать», должны идти через [taskShapeOf] и константы этого файла —
// НЕ сравнивать с 0/-1 напрямую (магические числа легко забыть в одной из
// веток при следующей правке). Чистый Dart, без зависимости на Flutter —
// пригоден и для UI (time_grid, add_task_sheet), и для расчётов
// (review_engine.freeSlots/distributeToDay).

/// Сентинел «момент»: нет длительности, только точка во времени.
const int kMomentDuration = 0;

/// Сентинел «открытый конец»: есть начало, длительность не задана.
const int kOpenEndedDuration = -1;

/// Форма задачи, определяющая её отображение на сетке времени и участие в
/// расчётах свободных слотов.
enum TaskShape {
  /// Обычная задача с длительностью (durationMinutes > 0) — блок на сетке.
  block,

  /// «Момент» (durationMinutes == 0) — маркер/точка на сетке, без длительности.
  moment,

  /// «Только начало» (durationMinutes <= -1) — открытый блок без заданного
  /// конца (тянется до следующего события/конца видимой сетки).
  open,
}

/// Форма задачи по значению её `durationMinutes`. Единственное место, решающее,
/// что означает каждое значение — используйте его вместо прямых сравнений с
/// 0/-1. Любое значение `<= kOpenEndedDuration` (на случай будущих доп.
/// сентинелов < -1) трактуется как «открытый конец».
TaskShape taskShapeOf(int durationMinutes) {
  if (durationMinutes == kMomentDuration) return TaskShape.moment;
  if (durationMinutes <= kOpenEndedDuration) return TaskShape.open;
  return TaskShape.block;
}

/// Длительность (в минутах, всегда > 0) открытого блока [TaskShape.open] для
/// ЦЕЛЕЙ ВИЗУАЛЬНОГО РЕНДЕРА/раскладки по дорожкам: до времени следующего
/// события дня [nextStartMin] (минуты от полуночи, строго > [startMin]),
/// иначе — до конца видимой сетки [endOfDayMin] (по умолчанию конец суток).
/// Чистая математика: используется time_grid при построении блока и может
/// быть переиспользована в других расчётах, где нужен «эффективный конец»
/// открытой задачи. НЕ путать с фактическим durationMinutes в БД (там
/// остаётся -1, пока пользователь не задаст конец явным ресайзом).
///
/// [minDuration] — пол на случай вырожденного совпадения времён (следующее
/// событие начинается в ту же минуту) — открытый блок не должен схлопнуться
/// в 0 или отрицательную высоту.
int openEndedDurationMinutes(
  int startMin, {
  int? nextStartMin,
  int endOfDayMin = 24 * 60,
  int minDuration = 15,
}) {
  final endMin = (nextStartMin != null && nextStartMin > startMin)
      ? nextStartMin
      : endOfDayMin;
  final dur = endMin - startMin;
  return dur < minDuration ? minDuration : dur;
}

/// Минимальное значение из [starts], строго больше [after] — «следующее
/// начало» дня для открытого блока (см. [openEndedDurationMinutes]). null,
/// если такого нет (открытый блок тянется до конца дня). Чистая функция без
/// DateTime/Flutter — легко тестируется отдельно от сетки.
int? nextStartAfter(int after, List<int> starts) {
  int? best;
  for (final s in starts) {
    if (s > after && (best == null || s < best)) best = s;
  }
  return best;
}
