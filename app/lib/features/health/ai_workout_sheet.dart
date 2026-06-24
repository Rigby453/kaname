// Лист «Собрать программу тренировок» (Feature A).
//
// Две ветки сохраняются в ОДНУ модель WorkoutProgram (workout_templates.dart):
//   • «Build program» (free, offline) — buildTemplateProgram(...) из анкеты;
//   • «AI program» (premium) — /ai/workout-build → parseAiWorkoutProgram(...).
// Обе ведут в общий маршрут saveWorkoutProgram(dao, program): каждый день →
// шаблон Workout, упражнения → строки. Затем лист закрывается, показывается
// SnackBar, и новые тренировки появляются в списке (Drift-стрим).
//
// Структура зеркалит ai_menu_sheet.dart: KaiLoader на async, тема через
// FocusThemeExtension, строки через context.s(...).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animations/app_sheet.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/settings/water_goal_provider.dart'
    show kUserAgeKey, kUserHeightCmKey, kUserSexKey, kUserWeightKgKey;
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart' show sharedPreferencesProvider;
import '../../core/widgets/kai_loader.dart';
import '../../services/api/api_client.dart';
import '../auth/auth_controller.dart';
import '../paywall/paywall_screen.dart';
import 'workout_templates.dart';

/// Точка входа с экрана тренировок. Открывает прокручиваемый bottom sheet с анкетой.
Future<void> showAiWorkoutSheet(BuildContext context, WidgetRef ref) async {
  await showAppSheet<void>(
    context,
    isScrollControlled: true,
    builder: (_) => const _AiWorkoutSheet(),
  );
}

// ---------------------------------------------------------------------------
// Варианты выбора анкеты (значения = ключи API; подписи — через l10n)
// ---------------------------------------------------------------------------

const _goals = <({String value, String labelKey})>[
  (value: 'strength', labelKey: 'workout.ai_goal_strength'),
  (value: 'muscle', labelKey: 'workout.ai_goal_muscle'),
  (value: 'fat_loss', labelKey: 'workout.ai_goal_fat_loss'),
  (value: 'endurance', labelKey: 'workout.ai_goal_endurance'),
  (value: 'general', labelKey: 'workout.ai_goal_general'),
];

const _experiences = <({String value, String labelKey})>[
  (value: 'beginner', labelKey: 'workout.ai_exp_beginner'),
  (value: 'intermediate', labelKey: 'workout.ai_exp_intermediate'),
  (value: 'advanced', labelKey: 'workout.ai_exp_advanced'),
];

const _equipmentOptions = <({String value, String labelKey})>[
  (value: 'barbell', labelKey: 'workout.ai_eq_barbell'),
  (value: 'dumbbells', labelKey: 'workout.ai_eq_dumbbells'),
  (value: 'pullup_bar', labelKey: 'workout.ai_eq_pullup_bar'),
  (value: 'bodyweight', labelKey: 'workout.ai_eq_bodyweight'),
  (value: 'full_gym', labelKey: 'workout.ai_eq_full_gym'),
];

const _minutesPresets = <int>[30, 45, 60, 90];

class _AiWorkoutSheet extends ConsumerStatefulWidget {
  const _AiWorkoutSheet();

  @override
  ConsumerState<_AiWorkoutSheet> createState() => _AiWorkoutSheetState();
}

class _AiWorkoutSheetState extends ConsumerState<_AiWorkoutSheet> {
  // Дефолты выбраны так, чтобы лист работал «из коробки» без касаний.
  String _goal = 'muscle';
  String _experience = 'beginner';
  final Set<String> _equipment = {'bodyweight'};
  int _daysPerWeek = 3;
  int _minutes = 45;

  final _focusController = TextEditingController();
  final _limitationsController = TextEditingController();

  // true пока идёт сетевой AI-вызов → показываем KaiLoader.
  bool _loading = false;
  // Сообщение об ошибке AI-ветки (читаемое, в т.ч. 503 geo/quota).
  String? _error;

  @override
  void dispose() {
    _focusController.dispose();
    _limitationsController.dispose();
    super.dispose();
  }

  void _toggleEquipment(String value) {
    setState(() {
      if (_equipment.contains(value)) {
        // Не даём снять последний выбор — иначе анкета пустая.
        if (_equipment.length > 1) _equipment.remove(value);
      } else {
        _equipment.add(value);
      }
    });
  }

  String? _trimmedOrNull(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  /// FREE / offline: собирает шаблонную программу и сохраняет её. Без сети.
  Future<void> _buildFree() async {
    final program = buildTemplateProgram(
      goal: _goal,
      experience: _experience,
      equipment: _equipment.toList(),
      daysPerWeek: _daysPerWeek,
    );
    // Шаблонная программа отдаёт КЛЮЧИ (слаги) — локализуем в display-строки
    // активного языка ДО записи в БД (схема БД не меняется, текст финальный).
    final localized = localizeWorkoutProgram(program, context.s);
    await _save(localized);
  }

  /// PREMIUM: проверяет тариф, читает профиль атлета, зовёт бэкенд-тренера,
  /// парсит ответ в WorkoutProgram и сохраняет. Ошибки показываем дружелюбно.
  Future<void> _buildAi() async {
    final premium = await ref.read(isPremiumProvider.future);
    if (!mounted) return;
    if (!premium) {
      showPremiumUpsell(context, context.s('workout.ai_premium_feature'));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tone =
          ref.read(toneProvider) == AppTone.harsh ? 'harsh' : 'gentle';
      // Профиль атлета из онбординга (необязательный контекст для модели).
      final prefs = ref.read(sharedPreferencesProvider);
      final profile = <String, dynamic>{
        'sex': prefs.getString(kUserSexKey),
        'age': prefs.getInt(kUserAgeKey),
        'weight_kg': prefs.getDouble(kUserWeightKgKey),
        'height_cm': prefs.getInt(kUserHeightCmKey),
      };

      final response = await ref.read(apiClientProvider).aiWorkoutBuild(
            goal: _goal,
            experience: _experience,
            equipment: _equipment.toList(),
            daysPerWeek: _daysPerWeek,
            minutesPerSession: _minutes,
            focus: _trimmedOrNull(_focusController),
            limitations: _trimmedOrNull(_limitationsController),
            tone: tone,
            profile: profile,
          );
      final program = parseAiWorkoutProgram(response);
      if (program.days.isEmpty) {
        // Пустая программа — показываем «не удалось», даём повторить.
        if (mounted) {
          setState(() {
            _loading = false;
            _error = context.s('workout.ai_empty');
          });
        }
        return;
      }
      await _save(program);
    } on ApiException catch (e) {
      // 503 = AI geo/quota-blocked (РФ IP) — показываем читаемое сообщение.
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = context.s('workout.ai_empty');
        });
      }
    }
  }

  /// Общий хвост обеих веток: пишет программу в Drift, закрывает лист, тостит.
  Future<void> _save(WorkoutProgram program) async {
    final dao = ref.read(workoutsDaoProvider);
    await saveWorkoutProgram(dao, program);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.s('workout.ai_saved'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? colorScheme.onSurface.withAlpha(153);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок листа — headlineSmall + иконка.
            Row(
              children: [
                Icon(Icons.fitness_center, size: 20, color: mutedColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.s('workout.ai_title'),
                    style: textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_loading) ...[
              Center(child: KaiLoader(label: context.s('workout.ai_loading'))),
              const SizedBox(height: 16),
            ] else ...[
              // Сообщение об ошибке AI-ветки (если была).
              if (_error != null) ...[
                Text(
                  _error!,
                  style: textTheme.bodyMedium?.copyWith(color: ext?.ember),
                ),
                const SizedBox(height: 12),
              ],

              // --- Goal ---
              _FieldLabel(text: context.s('workout.ai_goal')),
              _ChoiceChips(
                options: _goals,
                selected: {_goal},
                onTap: (v) => setState(() => _goal = v),
              ),
              const SizedBox(height: 16),

              // --- Experience ---
              _FieldLabel(text: context.s('workout.ai_experience')),
              _ChoiceChips(
                options: _experiences,
                selected: {_experience},
                onTap: (v) => setState(() => _experience = v),
              ),
              const SizedBox(height: 16),

              // --- Equipment (multi-select) ---
              _FieldLabel(text: context.s('workout.ai_equipment')),
              _ChoiceChips(
                options: _equipmentOptions,
                selected: _equipment,
                onTap: _toggleEquipment,
              ),
              const SizedBox(height: 16),

              // --- Days per week (stepper) ---
              _FieldLabel(text: context.s('workout.ai_days')),
              _Stepper(
                value: _daysPerWeek,
                min: 1,
                max: 7,
                onChanged: (v) => setState(() => _daysPerWeek = v),
              ),
              const SizedBox(height: 16),

              // --- Minutes per session (preset chips) ---
              _FieldLabel(text: context.s('workout.ai_minutes')),
              _ChoiceChips(
                options: [
                  for (final m in _minutesPresets)
                    (value: '$m', labelKey: 'lit:$m min'),
                ],
                selected: {'$_minutes'},
                onTap: (v) => setState(() => _minutes = int.parse(v)),
              ),
              const SizedBox(height: 16),

              // --- Focus (optional) ---
              TextField(
                controller: _focusController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.s('workout.ai_focus'),
                  hintText: context.s('workout.ai_focus_hint'),
                ),
              ),
              const SizedBox(height: 12),

              // --- Limitations (optional) ---
              TextField(
                controller: _limitationsController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.s('workout.ai_limitations'),
                  hintText: context.s('workout.ai_limitations_hint'),
                ),
              ),
              const SizedBox(height: 20),

              // --- Actions ---
              // FREE — первичное (FilledButton), полностью оффлайн.
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.bolt, size: 18),
                  label: Text(context.s('workout.ai_build_free')),
                  onPressed: _buildFree,
                ),
              ),
              const SizedBox(height: 10),
              // AI — вторичное (OutlinedButton), premium-гейт.
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(context.s('workout.ai_build_ai')),
                  onPressed: _buildAi,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Вспомогательные виджеты анкеты
// ---------------------------------------------------------------------------

/// Подпись поля над группой контролов — labelLarge + textMuted.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: ext?.textMuted,
            ),
      ),
    );
  }
}

/// Группа чипов выбора (одиночный или множественный — определяется [selected]).
/// labelKey с префиксом 'lit:' выводится как литерал (для «30 min» и т. п.).
class _ChoiceChips extends StatelessWidget {
  const _ChoiceChips({
    required this.options,
    required this.selected,
    required this.onTap,
  });

  final List<({String value, String labelKey})> options;
  final Set<String> selected;
  final void Function(String value) onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          FilterChip(
            label: Text(
              o.labelKey.startsWith('lit:')
                  ? o.labelKey.substring(4)
                  : context.s(o.labelKey),
            ),
            selected: selected.contains(o.value),
            onSelected: (_) => onTap(o.value),
          ),
      ],
    );
  }
}

/// Простой ± степпер для целого в диапазоне [min, max].
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        IconButton.outlined(
          icon: const Icon(Icons.remove),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 48,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
        ),
        IconButton.outlined(
          icon: const Icon(Icons.add),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
