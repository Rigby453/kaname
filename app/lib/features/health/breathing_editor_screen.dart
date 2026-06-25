// Редактор пользовательской дыхательной техники.
// Имя + упорядоченный список фаз (тип + секунды), число циклов, превью
// суммарной длительности. Сохранение → CustomBreathingDao.create.
//
// Overflow-безопасность: весь контент в ScrollView; каждая фаза — карточка с
// вертикальной раскладкой (dropdown в Expanded, степпер в Wrap), поэтому экран
// выживает на 320px при textScale 1.5.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/theme/app_theme.dart';
import 'breathing_custom.dart';
import 'breathing_engine.dart';

/// Типы фаз, доступные в редакторе (совпадают с label'ами движка).
const _phaseTypes = ['Inhale', 'Hold', 'Exhale'];

const _kMinPhaseSeconds = 1;
const _kMaxPhaseSeconds = 60;
const _kMinCycles = 1;
const _kMaxCycles = 20;

/// Изменяемая фаза в редакторе (до сохранения).
class _EditPhase {
  _EditPhase({required this.type, required this.seconds});
  String type;
  int seconds;
}

class BreathingEditorScreen extends ConsumerStatefulWidget {
  const BreathingEditorScreen({super.key});

  @override
  ConsumerState<BreathingEditorScreen> createState() =>
      _BreathingEditorScreenState();
}

class _BreathingEditorScreenState extends ConsumerState<BreathingEditorScreen> {
  final _nameController = TextEditingController();

  // Дефолтный шаблон — простой вдох/выдох, чтобы было что редактировать.
  final List<_EditPhase> _phases = [
    _EditPhase(type: 'Inhale', seconds: 4),
    _EditPhase(type: 'Exhale', seconds: 4),
  ];

  int _cycles = 4;

  @override
  void initState() {
    super.initState();
    // Перерисовываем кнопку Save при изменении имени.
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // --- Локализация типа фазы (переиспользуем ключи фаз) ---
  String _localizeType(String type) {
    switch (type) {
      case 'Inhale':
        return context.s('breathing.inhale');
      case 'Exhale':
        return context.s('breathing.exhale');
      case 'Hold':
        return context.s('breathing.hold');
      default:
        return type;
    }
  }

  // --- Сумма секунд одного цикла ---
  int get _cycleSeconds =>
      _phases.fold<int>(0, (acc, p) => acc + p.seconds);

  Duration get _totalDuration => Duration(seconds: _cycleSeconds * _cycles);

  String _formatTotal(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _phases.isNotEmpty;

  // --- Конвертация в фазы движка ---
  // expand/hold выводятся из типа: Inhale→растёт, Exhale→сжимается,
  // Hold→фиксирует предыдущее состояние круга (как в встроенных пресетах).
  List<BreathPhase> _buildEnginePhases() {
    final out = <BreathPhase>[];
    var lastExpand = true;
    for (final p in _phases) {
      final isHold = p.type == 'Hold';
      bool expand;
      if (p.type == 'Inhale') {
        expand = true;
        lastExpand = true;
      } else if (p.type == 'Exhale') {
        expand = false;
        lastExpand = false;
      } else {
        expand = lastExpand;
      }
      out.add(BreathPhase(
        label: p.type,
        duration: Duration(seconds: p.seconds),
        expand: expand,
        hold: isHold,
      ));
    }
    return out;
  }

  Future<void> _save() async {
    final json = encodePhases(_buildEnginePhases());
    await ref.read(customBreathingDaoProvider).create(
          name: _nameController.text.trim(),
          phasesJson: json,
          cycles: _cycles,
        );
    if (mounted) Navigator.of(context).pop();
  }

  void _addPhase() {
    setState(() => _phases.add(_EditPhase(type: 'Inhale', seconds: 4)));
  }

  void _removePhase(int index) {
    setState(() => _phases.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('breathing.create_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // --- Имя техники ---
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.s('breathing.name_label'),
              ),
            ),
            const SizedBox(height: 24),

            // --- Список фаз ---
            Text(context.s('breathing.phases'), style: textTheme.titleMedium),
            const SizedBox(height: 12),
            ...List.generate(_phases.length, (i) => _buildPhaseCard(i)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addPhase,
                icon: const Icon(Icons.add),
                label: Text(context.s('breathing.add_phase')),
              ),
            ),
            const SizedBox(height: 16),

            // --- Циклы ---
            _buildCyclesRow(textTheme),
            const SizedBox(height: 16),

            // --- Превью суммарной длительности ---
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 20, color: ext.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${context.s('breathing.total')}: ${_formatTotal(_totalDuration)}',
                    style: textTheme.titleMedium?.copyWith(color: ext.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // --- Сохранить ---
            FilledButton.icon(
              onPressed: _canSave ? _save : null,
              icon: const Icon(Icons.check),
              label: Text(context.s('btn.save')),
            ),
          ],
        ),
      ),
    );
  }

  // Карточка одной фазы: тип (dropdown в Expanded) + удалить; снизу степпер секунд.
  Widget _buildPhaseCard(int index) {
    final phase = _phases[index];
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: phase.type,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: _phaseTypes
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(_localizeType(t)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => phase.type = v);
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: ext.ember),
                  tooltip: context.s('btn.delete'),
                  // Минимум одна фаза — иначе технику нечего запускать.
                  onPressed:
                      _phases.length > 1 ? () => _removePhase(index) : null,
                ),
              ],
            ),
            // Степпер секунд в Wrap — переносится на узком экране/большом тексте.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: phase.seconds > _kMinPhaseSeconds
                      ? () => setState(() => phase.seconds--)
                      : null,
                ),
                Text(plSeconds(context, phase.seconds)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: phase.seconds < _kMaxPhaseSeconds
                      ? () => setState(() => phase.seconds++)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCyclesRow(TextTheme textTheme) {
    return Row(
      children: [
        Expanded(
          child: Text(context.s('breathing.cycles'),
              style: textTheme.titleMedium),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: _cycles > _kMinCycles
              ? () => setState(() => _cycles--)
              : null,
        ),
        Text(
          '$_cycles',
          style: textTheme.titleMedium
              ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: _cycles < _kMaxCycles
              ? () => setState(() => _cycles++)
              : null,
        ),
      ],
    );
  }
}
