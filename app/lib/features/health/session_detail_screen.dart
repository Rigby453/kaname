// Экран «Тренировка <дата>» — журнал одной сессии по датам (Part 1).
// Тап по прошлой сессии во вкладке «Дневник» открывает этот экран:
// список упражнений сессии, под каждым — фактически выполненные подходы
// (Подход N: reps × weight), из workout_set_logs за эту сессию.
//
// Офлайн-первый: данные только из Drift через WorkoutsDao.watchSessionSetGroups.
//
// Заголовок = дата сессии (передаётся через ?date=ISO; опционально ?name=).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/database/daos/workouts_dao.dart' show ExerciseSetGroup;
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';

/// Группы подходов одной сессии, сгруппированные по упражнению (family по id).
final sessionSetGroupsProvider = StreamProvider.autoDispose
    .family<List<ExerciseSetGroup>, String>((ref, sessionId) {
  return ref.watch(workoutsDaoProvider).watchSessionSetGroups(sessionId);
});

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({
    super.key,
    required this.sessionId,
    this.startedAt,
    this.workoutName,
  });

  final String sessionId;

  /// Время начала сессии — для заголовка-даты (опционально).
  final DateTime? startedAt;

  /// Имя тренировки — подзаголовок (опционально).
  final String? workoutName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final title = startedAt != null
        ? DateFormat('EEE, MMM d').format(startedAt!)
        : context.s('workout.session_title');

    final groupsAsync = ref.watch(sessionSetGroupsProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (workoutName != null && workoutName!.isNotEmpty)
              Text(
                workoutName!,
                style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: groupsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => _empty(context, ext, textTheme),
        data: (groups) {
          if (groups.isEmpty) return _empty(context, ext, textTheme);
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              for (final group in groups) ...[
                _ExerciseBlock(group: group, ext: ext, textTheme: textTheme),
                const SizedBox(height: 20),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _empty(
    BuildContext context,
    FocusThemeExtension ext,
    TextTheme textTheme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center_outlined, size: 56, color: ext.textFaint),
            const SizedBox(height: 16),
            Text(
              context.s('workout.session_empty'),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Блок одного упражнения сессии: имя + список выполненных подходов.
class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({
    required this.group,
    required this.ext,
    required this.textTheme,
  });

  final ExerciseSetGroup group;
  final FocusThemeExtension ext;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    // Имя упражнения; если упражнение удалено из шаблона — fallback-метка.
    final name = group.name ?? context.s('workout.deleted_exercise');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: textTheme.titleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        for (final log in group.sets)
          _SetRow(log: log, ext: ext, textTheme: textTheme),
      ],
    );
  }
}

/// Строка подхода: «Set 1 · 12 × 40 kg» / «Set 2 · 15 × Bodyweight».
class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.log,
    required this.ext,
    required this.textTheme,
  });

  final WorkoutSetLogsTableData log;
  final FocusThemeExtension ext;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final weight = _formatWeight(context, log.weightKg);
    // «Подход N» — локализованный префикс с номером (setIndex 0-based → +1).
    final label =
        context.s('workout.set_n').replaceAll('{n}', '${log.setIndex + 1}');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              '${log.reps} × $weight',
              style: textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatWeight(BuildContext context, double? w) {
    if (w == null) return context.s('workout.bodyweight');
    final v = w == w.truncateToDouble() ? '${w.round()}' : '$w';
    return '$v ${context.s('workout.weight_short')}';
  }
}
