// Экран редактирования целей (вес/рост/возраст/пол/активность/цель питания/вода).
// Открывается из профиля. После сохранения invalidate nutritionTargetsProvider,
// чтобы провайдер пересчитал нормы по новым данным без перезапуска.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/settings/food_preferences_provider.dart';
import '../../core/settings/nutrition_targets.dart';
import '../../core/settings/water_goal_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';

class EditGoalsScreen extends ConsumerStatefulWidget {
  const EditGoalsScreen({super.key});

  @override
  ConsumerState<EditGoalsScreen> createState() => _EditGoalsScreenState();
}

class _EditGoalsScreenState extends ConsumerState<EditGoalsScreen> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _ageCtrl;

  late String _sex;      // 'male'|'female'|'other'
  late String _activity; // 'low'|'medium'|'high'
  late String _goal;     // 'maintain'|'lose'|'gain'
  late int _waterGoal;

  // Расчётные нормы (обновляются live при изменении любого поля)
  NutritionTargets? _preview;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);

    final weightVal = prefs.getDouble(kUserWeightKgKey);
    final heightVal = prefs.getInt(kUserHeightCmKey);
    final ageVal = prefs.getInt(kUserAgeKey);

    _weightCtrl = TextEditingController(
      text: weightVal != null && weightVal > 0
          ? weightVal == weightVal.floorToDouble()
              ? weightVal.toInt().toString()
              : weightVal.toString()
          : '',
    );
    _heightCtrl = TextEditingController(
      text: heightVal != null && heightVal > 0 ? '$heightVal' : '',
    );
    _ageCtrl = TextEditingController(
      text: ageVal != null && ageVal > 0 ? '$ageVal' : '',
    );

    _sex = prefs.getString(kUserSexKey) ?? 'other';
    _activity = prefs.getString(kUserActivityKey) ?? 'medium';
    _goal = prefs.getString(kFoodGoalKey) ?? 'maintain';
    _waterGoal = ref.read(waterGoalProvider);

    // Добавляем слушателей после инициализации
    _weightCtrl.addListener(_recalc);
    _heightCtrl.addListener(_recalc);
    _ageCtrl.addListener(_recalc);

    // Начальный расчёт
    _recalc();
  }

  @override
  void dispose() {
    _weightCtrl.removeListener(_recalc);
    _heightCtrl.removeListener(_recalc);
    _ageCtrl.removeListener(_recalc);
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Пересчёт нормы воды и нормы питания (live)
  // ---------------------------------------------------------------------------

  void _recalc() {
    final weight = double.tryParse(_weightCtrl.text.trim().replaceAll(',', '.'));
    final height = double.tryParse(_heightCtrl.text.trim());
    final age = int.tryParse(_ageCtrl.text.trim());

    // Пересчёт нормы воды
    if (weight != null && weight > 0) {
      final recommended = recommendedWaterMl(
        weightKg: weight,
        activity: _activity,
        heightCm: height,
        age: age,
      );
      setState(() {
        _waterGoal = recommended;
        _preview = _computePreview(weight, height, age);
      });
    } else {
      setState(() {
        _preview = null;
      });
    }
  }

  NutritionTargets? _computePreview(
    double weight,
    double? height,
    int? age,
  ) {
    if (height == null || height <= 0) return null;
    if (age == null || age <= 0) return null;
    return computeNutritionTargets(
      weightKg: weight,
      heightCm: height,
      age: age,
      sex: _sex,
      activity: _activity,
      goal: _goal,
    );
  }

  // ---------------------------------------------------------------------------
  // Сохранение
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    final prefs = ref.read(sharedPreferencesProvider);

    final weight = double.tryParse(_weightCtrl.text.trim().replaceAll(',', '.'));
    final height = int.tryParse(_heightCtrl.text.trim());
    final age = int.tryParse(_ageCtrl.text.trim());

    if (weight != null && weight > 0) {
      await prefs.setDouble(kUserWeightKgKey, weight);
    }
    if (height != null && height > 0) {
      await prefs.setInt(kUserHeightCmKey, height);
    }
    if (age != null && age > 0) {
      await prefs.setInt(kUserAgeKey, age);
    }
    await prefs.setString(kUserSexKey, _sex);
    await prefs.setString(kUserActivityKey, _activity);

    // Цель питания — пишем в тот же ключ, что использует nutritionTargetsProvider
    await prefs.setString(kFoodGoalKey, _goal);
    // Также обновляем FoodPreferences, чтобы цель отображалась в секции пищевых предпочтений
    final fp = ref.read(foodPreferencesProvider);
    await ref.read(foodPreferencesProvider.notifier).save(fp.copyWith(goal: _goal));

    // Норма воды
    await ref.read(waterGoalProvider.notifier).set(_waterGoal);

    // Invalidate nutritionTargetsProvider — провайдер пересчитает нормы из prefs
    ref.invalidate(nutritionTargetsProvider);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.s('edit_goals.saved_snack'))),
    );
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('edit_goals.title')),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Возраст + пол ----
            Text(
              context.s('onboarding.norms_age'),
              style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 8),
            _AgeField(controller: _ageCtrl),
            const SizedBox(height: 20),

            Text(
              context.s('onboarding.norms_sex'),
              style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ('male', context.s('onboarding.sex_male')),
                ('female', context.s('onboarding.sex_female')),
                ('other', context.s('onboarding.sex_other')),
              ].map((pair) {
                final (val, label) = pair;
                return ChoiceChip(
                  label: Text(label),
                  selected: _sex == val,
                  onSelected: (_) => setState(() {
                    _sex = val;
                    _recalc();
                  }),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ---- Рост и вес ----
            Text(
              context.s('edit_goals.body_params'),
              style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                    ],
                    decoration: InputDecoration(
                      labelText: context.s('onboarding.norms_weight'),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _heightCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: context.s('onboarding.norms_height'),
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ---- Активность ----
            Text(
              context.s('onboarding.norms_activity'),
              style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 8),
            _ActivityChips(
              selected: _activity,
              onChanged: (val) => setState(() {
                _activity = val;
                _recalc();
              }),
            ),

            const SizedBox(height: 24),

            // ---- Цель питания ----
            Text(
              context.s('food_prefs.goal_label'),
              style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'lose',
                  label: Flexible(
                    child: Text(
                      context.s('food_prefs.goal_lose'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                ButtonSegment(
                  value: 'maintain',
                  label: Flexible(
                    child: Text(
                      context.s('food_prefs.goal_maintain'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                ButtonSegment(
                  value: 'gain',
                  label: Flexible(
                    child: Text(
                      context.s('food_prefs.goal_gain'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              selected: {_goal},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                _goal = s.first;
                _recalc();
              }),
            ),

            const SizedBox(height: 24),

            // ---- Норма воды ----
            Text(
              context.s('edit_goals.water_goal_label'),
              style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.water_drop_outlined, size: 18, color: ext.success),
                const SizedBox(width: 6),
                Text(
                  '$_waterGoal ml',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ext.success,
                  ),
                ),
              ],
            ),
            Slider(
              value: _waterGoal.toDouble(),
              min: 1000,
              max: 4000,
              divisions: 30,
              label: '$_waterGoal ml',
              onChanged: (v) => setState(() => _waterGoal = v.round()),
            ),
            Text(
              context.s('onboarding.norms_adjust_hint'),
              style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
            ),

            const SizedBox(height: 28),

            // ---- Предварительный расчёт норм ----
            if (_preview != null) ...[
              Divider(color: ext.border),
              const SizedBox(height: 16),
              Text(
                context.s('edit_goals.targets_preview'),
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              _NutritionPreviewCard(targets: _preview!),
              const SizedBox(height: 4),
              Text(
                context.s('edit_goals.targets_note'),
                style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
              ),
            ] else ...[
              Divider(color: ext.border),
              const SizedBox(height: 12),
              Text(
                context.s('edit_goals.targets_fill_all'),
                style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
              ),
            ],

            const SizedBox(height: 32),

            // ---- Кнопка сохранения ----
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _save,
                child: Text(context.s('edit_goals.save_btn')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Вспомогательные виджеты
// ---------------------------------------------------------------------------

/// Поле ввода возраста (только цифры).
class _AgeField extends StatelessWidget {
  const _AgeField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: context.s('onboarding.norms_age'),
      ),
      textInputAction: TextInputAction.next,
    );
  }
}

/// Чипы выбора уровня активности (three-way choice).
class _ActivityChips extends StatelessWidget {
  const _ActivityChips({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        'low',
        context.s('onboarding_quiz.activity_low_label'),
        context.s('onboarding_quiz.activity_low_sub'),
      ),
      (
        'medium',
        context.s('onboarding_quiz.activity_medium_label'),
        context.s('onboarding_quiz.activity_medium_sub'),
      ),
      (
        'high',
        context.s('onboarding_quiz.activity_high_label'),
        context.s('onboarding_quiz.activity_high_sub'),
      ),
    ];

    return Column(
      children: options.map((opt) {
        final (val, label, subtitle) = opt;
        final isSelected = selected == val;
        final colorScheme = Theme.of(context).colorScheme;
        final ext = Theme.of(context).extension<FocusThemeExtension>()!;
        final textTheme = Theme.of(context).textTheme;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => onChanged(val),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? colorScheme.primary : ext.border,
                  width: isSelected ? 1.5 : 1.0,
                ),
                color: isSelected
                    ? colorScheme.primary.withAlpha(18)
                    : Colors.transparent,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: ext.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: isSelected ? colorScheme.primary : ext.border,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Карточка с расчётными нормами питания (live-preview).
class _NutritionPreviewCard extends StatelessWidget {
  const _NutritionPreviewCard({required this.targets});

  final NutritionTargets targets;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ext.border),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        children: [
          row(
            context.s('edit_goals.preview_kcal'),
            '${targets.kcal} ${context.s('edit_goals.unit_kcal')}',
          ),
          row(
            context.s('edit_goals.preview_protein'),
            '${targets.proteinG} ${context.s('edit_goals.unit_g')}',
          ),
          row(
            context.s('edit_goals.preview_fat'),
            '${targets.fatG} ${context.s('edit_goals.unit_g')}',
          ),
          row(
            context.s('edit_goals.preview_carbs'),
            '${targets.carbsG} ${context.s('edit_goals.unit_g')}',
          ),
          row(
            context.s('edit_goals.preview_fiber'),
            '${targets.fiberG} ${context.s('edit_goals.unit_g')}',
          ),
          row(
            context.s('edit_goals.preview_sugar_max'),
            '${targets.sugarMaxG} ${context.s('edit_goals.unit_g')}',
          ),
        ],
      ),
    );
  }
}
