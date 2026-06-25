// Riverpod-слой пользовательских дыхательных техник.
//
// Связывает CustomBreathingDao (Drift) с UI дыхания: декодирует phasesJson в
// список фаз движка и отдаёт удобную модель [CustomTechnique]. Пикер дыхания
// watch'ит [customTechniquesProvider]; в тестах его можно переопределить
// фейковыми данными — без Drift.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import 'breathing_custom.dart';
import 'breathing_engine.dart';

/// Пользовательская дыхательная техника (раскодированная из БД).
class CustomTechnique {
  const CustomTechnique({
    required this.id,
    required this.name,
    required this.phases,
    required this.cycles,
  });

  final String id;
  final String name;
  final List<BreathPhase> phases;
  final int cycles;

  /// Адаптер к движку: техника — это пресет с тем же name/phases.
  BreathingPreset get preset => BreathingPreset(name: name, phases: phases);

  /// Длительность одного цикла (сумма фаз).
  Duration get cycleDuration => preset.cycleDuration;
}

/// Реактивный список пользовательских техник.
///
/// Техники с пустым (невалидным) списком фаз отфильтровываются — их нельзя
/// запустить через движок. Пока стрим грузится — пустой список.
final customTechniquesProvider =
    StreamProvider.autoDispose<List<CustomTechnique>>((ref) {
  final dao = ref.watch(customBreathingDaoProvider);
  return dao.watchAll().map(
        (rows) => rows
            .map(
              (r) => CustomTechnique(
                id: r.id,
                name: r.name,
                phases: decodePhases(r.phasesJson),
                cycles: r.cycles,
              ),
            )
            .where((t) => t.phases.isNotEmpty)
            .toList(),
      );
});
