// Маппинг выбранных целей онбординга → флаги функциональных модулей.
// Чистая функция: никаких side-эффектов, только детерминированная логика.
// Вызывается в _finish() SetupFlowScreen; результат применяется через
// ref.read(<flag>Provider.notifier).set(v).
//
// Текущий набор целей (значения из _buildScreen5() в setup_flow.dart):
//   'study'           — учёба
//   'procrastination' — прокрастинация
//   'routine'         — режим (сон/ритм)
//   'free_time'       — свободное время
//   'exams'           — экзамены
//
// ПРИМЕЧАНИЕ: цели «тело/питание/фитнес» в текущем списке НЕТ.
// Поэтому nutritionMode и workoutMode онбордингом не включаются.
// Когда появится такая цель — добавить её строку в условие nutrition/workout.
//
// Принцип: тяжёлые модули включаются ТОЛЬКО при явном выборе цели.
//   study / procrastination / exams → ядро + фокус; никаких health-флагов.
//   free_time                       → ядро + фокус; никаких health-флагов.
//   routine                         → лёгкий сон и вода — L1-функции, всегда
//                                     доступны из плана; health L2-флаги НЕ
//                                     включаются (нет явного сигнала «тело»).
//   (future) fitness / body         → nutrition + workout.
//   (future) wellness / meditation  → meditationLibrary + breathingEditor.

/// Структура результата маппинга (record-тип Dart 3).
typedef GoalFlags = ({
  bool nutrition,
  bool workout,
  bool meditationLibrary,
  bool breathingEditor,
});

/// Возвращает набор флагов функциональных модулей для заданного
/// набора целей онбординга.
///
/// Чистая функция: детерминирована, без IO и side-эффектов.
/// Тестируется изолированно от Riverpod/Flutter.
GoalFlags goalsToFeatureFlags(Set<String> goals) {
  // --- Питание + тренировки ---
  // Включить только при явной цели «тело/питание».
  // Текущий список (study/procrastination/routine/free_time/exams) её не содержит.
  final nutrition = goals.contains('fitness') || goals.contains('body');
  final workout   = goals.contains('fitness') || goals.contains('body');

  // --- Медитации + дыхание ---
  // Редакторы пользовательских сессий — тяжёлые L2-функции;
  // включать только при явном wellness/meditation/breathing-намерении.
  // Цель 'routine' даёт только напоминание сна (L1); редакторы — нет.
  final meditationLibrary =
      goals.contains('wellness') || goals.contains('meditation');
  final breathingEditor =
      goals.contains('wellness') || goals.contains('breathing');

  return (
    nutrition: nutrition,
    workout: workout,
    meditationLibrary: meditationLibrary,
    breathingEditor: breathingEditor,
  );
}
