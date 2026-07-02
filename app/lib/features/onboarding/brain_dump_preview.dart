// Превью-подтверждение ответа ИИ-онбординга «брейн-дамп»
// (Волна 6, этап 3, docs/AI-ONBOARDING-DESIGN.md).
//
// parseOnboardingPlan — чистая функция разбора ответа POST /ai/onboarding-plan
// (по образцу parseQuickAddResponse в ai_quick_add_sheet.dart): deadline без
// scheduled_at → type='deadline' + scheduledAt=deadline (решение C); мусорные
// элементы (без title) отбрасываются; food_prefs намеренно игнорируется —
// нет модуля, который сохранял бы эти флаги без риска сломать что-то ещё
// (TODO: подключить, когда появится единый профиль предпочтений питания/сна).
//
// BrainDumpPreviewScreen показывает цели+задачи с переключателем
// включить/исключить (default: включён). Тап по задаче открывает
// showAddTaskSheet(prefill: ...) для правки-и-сохранения СРАЗУ — после
// возврата из листа задача помечается «добавлена» и исключается из
// пакетного сохранения (не дублируем — как заметил, так и не заметил
// сохранение, пользователь уже разобрался с этой задачей вручную).
//
// «Принять план» пишет прямо через itemsDaoProvider.insertItem с тем же
// набором полей, что и ветка создания новой задачи в AddTaskSheet._save()
// (add_task_sheet.dart) — тот же DAO-путь, без дублирования UI-логики формы.
// Цели — через goalsDaoProvider.createGoal (ADR-027: без синка).

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/id.dart';
import '../today/widgets/add_task_sheet.dart' show showAddTaskSheet, AddTaskPrefill;

// ---------------------------------------------------------------------------
// Модели черновика плана
// ---------------------------------------------------------------------------

class DraftGoal {
  const DraftGoal({required this.title, this.horizon});

  final String title;

  /// 'week'|'month'|'quarter'|'year' как вернул ИИ (контракт), или null.
  final String? horizon;
}

class DraftTask {
  const DraftTask({
    required this.title,
    this.type,
    this.priority,
    this.scheduledAt,
    this.durationMinutes,
    this.note,
  });

  final String title;
  final String? type;
  final String? priority;
  final DateTime? scheduledAt;
  final int? durationMinutes;
  final String? note;
}

class DraftPlan {
  const DraftPlan({required this.goals, required this.tasks});

  final List<DraftGoal> goals;
  final List<DraftTask> tasks;

  bool get isEmpty => goals.isEmpty && tasks.isEmpty;
}

const _validHorizons = {'week', 'month', 'quarter', 'year'};

/// Разбирает тело ответа `{ goals: [...], tasks: [...], food_prefs?: {...} }`
/// в [DraftPlan]. Никогда не бросает — мусорные/неполные элементы (без title,
/// не-Map записи) молча отбрасываются; при отсутствии/неверном типе полей
/// возвращается пустой [DraftPlan] (isEmpty=true — вызывающий код показывает
/// onboarding_ai.parse_error).
DraftPlan parseOnboardingPlan(Map<String, dynamic> response) {
  final goals = <DraftGoal>[];
  final goalsRaw = response['goals'];
  if (goalsRaw is List) {
    for (final g in goalsRaw) {
      if (g is! Map) continue;
      final map = Map<String, dynamic>.from(g);
      final title = (map['title'] as String?)?.trim();
      if (title == null || title.isEmpty) continue;
      final horizonRaw = map['horizon'] as String?;
      final horizon = _validHorizons.contains(horizonRaw) ? horizonRaw : null;
      goals.add(DraftGoal(title: title, horizon: horizon));
    }
  }

  final tasks = <DraftTask>[];
  final tasksRaw = response['tasks'];
  if (tasksRaw is List) {
    for (final t in tasksRaw) {
      if (t is! Map) continue;
      final map = Map<String, dynamic>.from(t);
      final title = (map['title'] as String?)?.trim();
      if (title == null || title.isEmpty) continue;

      String? type = map['type'] as String?;
      final priority = map['priority'] as String?;
      final scheduledAtRaw = map['scheduled_at'] as String?;
      final deadlineRaw = map['deadline'] as String?;
      var scheduledAt =
          scheduledAtRaw != null ? DateTime.tryParse(scheduledAtRaw)?.toLocal() : null;
      final deadline =
          deadlineRaw != null ? DateTime.tryParse(deadlineRaw)?.toLocal() : null;

      // Решение C (AI-ONBOARDING-DESIGN.md): deadline без scheduled_at →
      // type='deadline' + scheduledAt=deadline. Идентично parseQuickAddResponse.
      if (scheduledAt == null && deadline != null) {
        type = 'deadline';
        scheduledAt = deadline;
      }

      final durationRaw = map['duration_minutes'];
      final durationMinutes = durationRaw is num ? durationRaw.toInt() : null;
      final note = (map['note'] as String?)?.trim();

      tasks.add(DraftTask(
        title: title,
        type: type,
        priority: priority,
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
        note: (note == null || note.isEmpty) ? null : note,
      ));
    }
  }

  // food_prefs намеренно не читаем — см. комментарий в шапке файла.
  return DraftPlan(goals: goals, tasks: tasks);
}

/// Маппинг горизонта из контракта ИИ ('week'|'month'|'quarter'|'year') в
/// словарь существующей модели целей (goals_screen.dart:
/// 'month'|'year'|'five_years'|'ten_years' — нет понятий «неделя»/«квартал»).
/// 'week' сворачивается в 'month' (ближайший меньший горизонт модели);
/// 'quarter' — в 'year' (ближайший больший). Не смена контракта/схемы —
/// просто перевод словаря на границе двух фич.
String mapAiHorizonToGoalHorizon(String? aiHorizon) {
  switch (aiHorizon) {
    case 'week':
    case 'month':
      return 'month';
    case 'quarter':
    case 'year':
      return 'year';
    default:
      return 'month';
  }
}

/// Дефолтное время задачи без scheduledAt в плане — день превью, 09:00.
DateTime _defaultTaskTime(DateTime day) =>
    DateTime(day.year, day.month, day.day, 9, 0);

// ---------------------------------------------------------------------------
// Экран превью
// ---------------------------------------------------------------------------

class BrainDumpPreviewScreen extends ConsumerStatefulWidget {
  const BrainDumpPreviewScreen({super.key, required this.plan, required this.day});

  final DraftPlan plan;

  /// День, к которому привязываются задачи без своего scheduledAt.
  final DateTime day;

  @override
  ConsumerState<BrainDumpPreviewScreen> createState() =>
      _BrainDumpPreviewScreenState();
}

class _BrainDumpPreviewScreenState extends ConsumerState<BrainDumpPreviewScreen> {
  late List<bool> _goalIncluded;
  late List<bool> _taskIncluded;
  // true = задачу открыли в showAddTaskSheet и лист закрылся (сохранена ИЛИ
  // отклонена пользователем вручную) — в обоих случаях больше не участвует
  // в пакетном сохранении (см. комментарий в шапке файла).
  late List<bool> _taskHandled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _goalIncluded = List<bool>.filled(widget.plan.goals.length, true);
    _taskIncluded = List<bool>.filled(widget.plan.tasks.length, true);
    _taskHandled = List<bool>.filled(widget.plan.tasks.length, false);
  }

  int get _selectedCount {
    var count = 0;
    for (var i = 0; i < _goalIncluded.length; i++) {
      if (_goalIncluded[i]) count++;
    }
    for (var i = 0; i < _taskIncluded.length; i++) {
      if (_taskIncluded[i] && !_taskHandled[i]) count++;
    }
    return count;
  }

  Future<void> _editTask(int index) async {
    final t = widget.plan.tasks[index];
    final prefill = AddTaskPrefill(
      title: t.title,
      type: t.type,
      priority: t.priority,
      scheduledAt: t.scheduledAt,
      durationMinutes: t.durationMinutes,
      note: t.note,
    );
    await showAddTaskSheet(
      context,
      day: t.scheduledAt ?? widget.day,
      prefill: prefill,
    );
    if (!mounted) return;
    setState(() {
      _taskHandled[index] = true;
      _taskIncluded[index] = false;
    });
  }

  Future<void> _accept() async {
    if (_saving || _selectedCount == 0) return;
    setState(() => _saving = true);

    final itemsDao = ref.read(itemsDaoProvider);
    final goalsDao = ref.read(goalsDaoProvider);

    var savedCount = 0;

    for (var i = 0; i < widget.plan.goals.length; i++) {
      if (!_goalIncluded[i]) continue;
      final g = widget.plan.goals[i];
      await goalsDao.createGoal(g.title, mapAiHorizonToGoalHorizon(g.horizon));
      savedCount++;
    }

    // Лимит main/день (правило приложения, максимум 3 — add_task_sheet.dart
    // _maxMainPerDay): считаем от уже существующих в БД + уже вставленных в
    // этом батче на тот же календарный день; лишние main понижаем до 'high'
    // (AI-ONBOARDING-DESIGN.md §Контракты).
    final mainCountByDay = <DateTime, int>{};
    for (var i = 0; i < widget.plan.tasks.length; i++) {
      if (!_taskIncluded[i] || _taskHandled[i]) continue;
      final t = widget.plan.tasks[i];
      final scheduledAt = t.scheduledAt ?? _defaultTaskTime(widget.day);
      final dayKey = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);

      var priority = t.priority ?? 'medium';
      if (priority == 'main') {
        int current;
        if (mainCountByDay.containsKey(dayKey)) {
          current = mainCountByDay[dayKey]!;
        } else {
          current = await itemsDao.countMainItems(dayKey);
        }
        if (current >= 3) {
          priority = 'high';
        } else {
          mainCountByDay[dayKey] = current + 1;
        }
      }

      final now = DateTime.now();
      await itemsDao.insertItem(
        ItemsTableCompanion(
          id: Value(uuidV4()),
          userId: const Value('local'),
          title: Value(t.title),
          type: Value(t.type ?? 'task'),
          priority: Value(priority),
          status: const Value('pending'),
          scheduledAt: Value(scheduledAt),
          durationMinutes: Value(t.durationMinutes ?? 30),
          isProtected: Value(priority == 'main'),
          location: Value(t.note), // локальное поле — не синкается
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      savedCount++;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.s('onboarding_ai.snackbar_created').replaceAll('{n}', '$savedCount'),
        ),
      ),
    );
    Navigator.of(context).pop(savedCount);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Scaffold(
      appBar: AppBar(title: Text(context.s('onboarding_ai.preview_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            if (plan.goals.isNotEmpty) ...[
              _SectionLabel(context.s('onboarding_ai.preview_section_goals')),
              for (var i = 0; i < plan.goals.length; i++)
                _GoalRow(
                  goal: plan.goals[i],
                  included: _goalIncluded[i],
                  onChanged: (v) => setState(() => _goalIncluded[i] = v),
                ),
            ],
            if (plan.tasks.isNotEmpty) ...[
              _SectionLabel(context.s('onboarding_ai.preview_section_tasks')),
              for (var i = 0; i < plan.tasks.length; i++)
                _TaskRow(
                  task: plan.tasks[i],
                  included: _taskIncluded[i],
                  handled: _taskHandled[i],
                  day: widget.day,
                  onChanged: (v) => setState(() => _taskIncluded[i] = v),
                  onTap: () => _editTask(i),
                ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_saving || _selectedCount == 0) ? null : _accept,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.s('onboarding_ai.preview_accept_button')),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Виджеты списка
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 0, 8),
      child: Text(label, style: textTheme.labelMedium?.copyWith(color: ext.textMuted)),
    );
  }
}

/// Hairline-карточка R14 (§4.2) с общей структурой строки-переключателя.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final card = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: card,
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal, required this.included, required this.onChanged});
  final DraftGoal goal;
  final bool included;
  final ValueChanged<bool> onChanged;

  String _horizonLabel(BuildContext context, String? horizon) {
    switch (horizon) {
      case 'week':
        return context.s('onboarding_ai.horizon_week');
      case 'month':
        return context.s('onboarding_ai.horizon_month');
      case 'quarter':
        return context.s('onboarding_ai.horizon_quarter');
      case 'year':
        return context.s('onboarding_ai.horizon_year');
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final horizonText = _horizonLabel(context, goal.horizon);

    return _PreviewCard(
      child: Row(
        children: [
          Icon(PhosphorIcons.flag(), size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.title,
                  style: textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (horizonText.isNotEmpty)
                  Text(
                    horizonText,
                    style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: included, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.included,
    required this.handled,
    required this.day,
    required this.onChanged,
    required this.onTap,
  });

  final DraftTask task;
  final bool included;
  final bool handled;
  final DateTime day;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTap;

  String _typeKey(String? type) => switch (type) {
        'event' => 'today.type_event',
        'exam' => 'today.type_exam',
        'deadline' => 'today.type_deadline',
        _ => 'today.type_task',
      };

  String _priorityKey(String? priority) => switch (priority) {
        'main' => 'today.priority_main',
        'high' => 'today.priority_high',
        'low' => 'today.priority_low',
        _ => 'today.priority_medium',
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final effectiveAt = task.scheduledAt ?? _defaultTaskTime(day);
    final timeLabel = DateFormat('d MMM, HH:mm').format(effectiveAt);
    final durationLabel = task.durationMinutes != null
        ? plMinutes(context, task.durationMinutes!)
        : null;

    return _PreviewCard(
      onTap: handled ? null : onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              task.priority == 'main'
                  ? PhosphorIcons.shield(PhosphorIconsStyle.fill)
                  : PhosphorIcons.checkCircle(),
              size: 18,
              color: task.priority == 'main' ? ext.ember : ext.textFaint,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: textTheme.bodyLarge?.copyWith(
                    color: handled ? ext.textFaint : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _MetaChip(label: timeLabel, ext: ext),
                    _MetaChip(label: context.s(_typeKey(task.type)), ext: ext),
                    _MetaChip(label: context.s(_priorityKey(task.priority)), ext: ext),
                    if (durationLabel != null) _MetaChip(label: durationLabel, ext: ext),
                    if (handled)
                      _MetaChip(
                        label: context.s('onboarding_ai.preview_added_badge'),
                        ext: ext,
                        icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (handled)
            Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                size: 22, color: ext.success)
          else
            Switch(value: included, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Маленький бейдж для метаданных задачи (время / тип / приоритет / длительность).
/// Копия паттерна import_sheet.dart._MetaChip (не экспортирован оттуда).
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.ext, this.icon});

  final String label;
  final FocusThemeExtension ext;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final labelStyle =
        Theme.of(context).textTheme.labelSmall?.copyWith(color: ext.textMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ext.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: ext.textMuted),
            const SizedBox(width: 3),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              style: labelStyle,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
