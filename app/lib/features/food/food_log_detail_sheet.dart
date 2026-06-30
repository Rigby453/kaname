// Шит просмотра/редактирования залогированной записи о еде (food-1).
//
// Открывается тапом по строке в дневнике еды (_FoodRow в food_screen.dart).
// Показывает название + КБЖУ/сахар/клетчатку — и за порцию (редактируемо),
// и пересчитанные на 100 г (живая подпись, только для справки).
//
// Сохранение пишет ИМЕННО эту запись через FoodLogsDao.updateLogMacros —
// граммы/приём пищи/дата не трогаются, глобальная база продуктов (Open Food
// Facts) не меняется.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animations/app_sheet.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import 'food_icons.dart';

// ---------------------------------------------------------------------------
// Публичный API
// ---------------------------------------------------------------------------

/// Показывает шит просмотра/редактирования [log].
Future<void> showFoodLogDetailSheet(
  BuildContext context,
  FoodLogsTableData log,
) {
  return showAppSheet<void>(
    context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      // Сжимаемся вместе с клавиатурой (anti-regression rule B).
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _FoodLogDetailSheet(log: log),
    ),
  );
}

// ---------------------------------------------------------------------------
// Виджет шита
// ---------------------------------------------------------------------------

class _FoodLogDetailSheet extends ConsumerStatefulWidget {
  const _FoodLogDetailSheet({required this.log});
  final FoodLogsTableData log;

  @override
  ConsumerState<_FoodLogDetailSheet> createState() =>
      _FoodLogDetailSheetState();
}

class _FoodLogDetailSheetState extends ConsumerState<_FoodLogDetailSheet> {
  late final TextEditingController _caloriesCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _fatCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _sugarCtrl;
  late final TextEditingController _fiberCtrl;

  bool _saving = false;

  /// Форматирует число для поля ввода: целые без дробной части, иначе 1 знак.
  static String _fmt(double? v) {
    if (v == null) return '';
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(1);
  }

  /// Форматирует число для read-only подписи «на 100 г»: '—' если неизвестно.
  static String _g(double? v) => v == null ? '—' : v.round().toString();

  @override
  void initState() {
    super.initState();
    final l = widget.log;
    _caloriesCtrl = TextEditingController(text: _fmt(l.calories));
    _proteinCtrl = TextEditingController(text: _fmt(l.protein));
    _fatCtrl = TextEditingController(text: _fmt(l.fat));
    _carbsCtrl = TextEditingController(text: _fmt(l.carbs));
    _sugarCtrl = TextEditingController(text: _fmt(l.sugar));
    _fiberCtrl = TextEditingController(text: _fmt(l.fiber));
  }

  @override
  void dispose() {
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _fatCtrl.dispose();
    _carbsCtrl.dispose();
    _sugarCtrl.dispose();
    _fiberCtrl.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  /// Живой пересчёт «на 100 г» из текущего (возможно ещё не сохранённого)
  /// значения поля — порция (grams) берётся из исходной записи, не редактируется.
  double? _per100(TextEditingController c) {
    final v = _parse(c);
    final grams = widget.log.grams;
    if (v == null || grams <= 0) return null;
    return v / grams * 100.0;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final dao = ref.read(foodLogsDaoProvider);
    await dao.updateLogMacros(
      widget.log.id,
      calories: _parse(_caloriesCtrl),
      protein: _parse(_proteinCtrl),
      fat: _parse(_fatCtrl),
      carbs: _parse(_carbsCtrl),
      sugar: _parse(_sugarCtrl),
      fiber: _parse(_fiberCtrl),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('"${widget.log.name}" ${context.s('food.log_updated')}'),
      ),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor =
        ext?.textMuted ??
        Theme.of(context).colorScheme.onSurface.withAlpha(153);
    final grams = widget.log.grams;

    // Без явного maxHeight SingleChildScrollView получает неограниченную
    // высоту от родительского Column(mainAxisSize: min) и просто растёт под
    // контент вместо скролла → overflow на узких/коротких экранах с крупным
    // текстом (320×700, textScale 1.5). Ограничиваем явно (как в import_sheet.dart).
    final maxBodyH = MediaQuery.sizeOf(context).height * 0.6;

    return AppSheetContent(
      title: widget.log.name,
      primaryButton: FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(context.s('btn.save')),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxBodyH),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FoodIconTile(name: widget.log.name, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context
                          .s('food.grams_val')
                          .replaceFirst('{val}', '${grams.round()}'),
                      style: textTheme.bodyMedium?.copyWith(color: mutedColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                context.s('food.log_detail_scope_hint'),
                style: textTheme.bodySmall?.copyWith(color: mutedColor),
              ),
              const SizedBox(height: 8),
              _MacroFieldRow(
                label: context.s('food.macro_calories'),
                unit: context.s('food.unit_kcal'),
                controller: _caloriesCtrl,
                per100Caption: context
                    .s('food.kcal_per_100g')
                    .replaceFirst('{kcal}', _g(_per100(_caloriesCtrl))),
                onChanged: () => setState(() {}),
              ),
              _MacroFieldRow(
                label: context.s('food.macro_protein'),
                unit: context.s('food.unit_g'),
                controller: _proteinCtrl,
                per100Caption: context
                    .s('food.per100_g_val')
                    .replaceFirst('{val}', _g(_per100(_proteinCtrl))),
                onChanged: () => setState(() {}),
              ),
              _MacroFieldRow(
                label: context.s('food.macro_fat'),
                unit: context.s('food.unit_g'),
                controller: _fatCtrl,
                per100Caption: context
                    .s('food.per100_g_val')
                    .replaceFirst('{val}', _g(_per100(_fatCtrl))),
                onChanged: () => setState(() {}),
              ),
              _MacroFieldRow(
                label: context.s('food.macro_carbs'),
                unit: context.s('food.unit_g'),
                controller: _carbsCtrl,
                per100Caption: context
                    .s('food.per100_g_val')
                    .replaceFirst('{val}', _g(_per100(_carbsCtrl))),
                onChanged: () => setState(() {}),
              ),
              _MacroFieldRow(
                label: context.s('food.macro_sugar'),
                unit: context.s('food.unit_g'),
                controller: _sugarCtrl,
                per100Caption: context
                    .s('food.per100_g_val')
                    .replaceFirst('{val}', _g(_per100(_sugarCtrl))),
                onChanged: () => setState(() {}),
              ),
              _MacroFieldRow(
                label: context.s('food.macro_fiber'),
                unit: context.s('food.unit_g'),
                controller: _fiberCtrl,
                per100Caption: context
                    .s('food.per100_g_val')
                    .replaceFirst('{val}', _g(_per100(_fiberCtrl))),
                onChanged: () => setState(() {}),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MacroFieldRow — строка «label + per-100g подпись» / редактируемое поле + единица
// ---------------------------------------------------------------------------

class _MacroFieldRow extends StatelessWidget {
  const _MacroFieldRow({
    required this.label,
    required this.unit,
    required this.controller,
    required this.per100Caption,
    required this.onChanged,
  });

  final String label;
  final String unit;
  final TextEditingController controller;

  /// Готовая локализованная подпись «на 100 г» (вычисляется в родителе).
  final String per100Caption;

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor =
        ext?.textMuted ??
        Theme.of(context).colorScheme.onSurface.withAlpha(153);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  per100Caption,
                  style: textTheme.bodySmall?.copyWith(color: mutedColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
            child: TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 6,
                ),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 32,
            child: Text(
              unit,
              style: textTheme.bodySmall?.copyWith(color: mutedColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
