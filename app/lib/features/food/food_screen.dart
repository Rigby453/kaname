// Экран «Еда» (Health → Food, Phase 1, C5).
// Поиск продукта (Open Food Facts через бэкенд) → выбрать граммы/приём → запись.
// Итоги дня (ккал, Б/Ж/У, сахар/клетчатка) считаются локально из food_logs.
// Числа КБЖУ — из базы (на 100 г), масштабируются под порцию (food_nutrition).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animations/app_sheet.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../services/api/api_client.dart';
import 'food_nutrition.dart';

const List<String> _meals = ['breakfast', 'lunch', 'dinner', 'snack'];

/// Записи о еде за сегодня (реактивно).
final _todayFoodProvider =
    StreamProvider.autoDispose<List<FoodLogsTableData>>((ref) {
  return ref.watch(foodLogsDaoProvider).watchForDay(DateTime.now());
});

Nutrition _logToNutrition(FoodLogsTableData l) => Nutrition(
      calories: l.calories,
      protein: l.protein,
      fat: l.fat,
      carbs: l.carbs,
      sugar: l.sugar,
      fiber: l.fiber,
    );

class FoodScreen extends ConsumerWidget {
  const FoodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final logs = ref.watch(_todayFoodProvider).valueOrNull ??
        const <FoodLogsTableData>[];
    final totals = sumNutrition(logs.map(_logToNutrition));

    return Scaffold(
      appBar: AppBar(title: const Text('Food')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSearchSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add food'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _TotalsCard(totals: totals),
          const SizedBox(height: 16),
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Nothing logged today.\nTap "Add food" to search a product.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
              ),
            )
          else
            ...logs.map((l) => _FoodRow(log: l)),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals});
  final Nutrition totals;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    String g(double? v) => v == null ? '—' : v.round().toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(g(totals.calories), style: textTheme.headlineMedium),
                const SizedBox(width: 6),
                Text('kcal', style: textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Macro(label: 'Protein', value: '${g(totals.protein)} g'),
                _Macro(label: 'Fat', value: '${g(totals.fat)} g'),
                _Macro(label: 'Carbs', value: '${g(totals.carbs)} g'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.cookie_outlined,
                    size: 16, color: colorScheme.secondary),
                const SizedBox(width: 4),
                Text('Sugar ${g(totals.sugar)} g', style: textTheme.bodySmall),
                const SizedBox(width: 16),
                Icon(Icons.grass_outlined,
                    size: 16, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text('Fiber ${g(totals.fiber)} g', style: textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(value, style: textTheme.titleMedium),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }
}

class _FoodRow extends ConsumerWidget {
  const _FoodRow({required this.log});
  final FoodLogsTableData log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final kcal = log.calories == null ? '—' : '${log.calories!.round()} kcal';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(log.name),
        subtitle: Text('${log.grams.round()} g · ${log.meal} · $kcal',
            style: textTheme.bodySmall),
        trailing: IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => ref.read(foodLogsDaoProvider).deleteLog(log.id),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Поиск продукта (нижний лист)
// ---------------------------------------------------------------------------

Future<void> _showSearchSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    isScrollControlled: true,
    builder: (_) => const _FoodSearchSheet(),
  );
}

class _FoodSearchSheet extends ConsumerStatefulWidget {
  const _FoodSearchSheet();
  @override
  ConsumerState<_FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends ConsumerState<_FoodSearchSheet> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ref.read(apiClientProvider).foodSearch(q);
      if (!mounted) return;
      setState(() {
        _results = raw.whereType<Map<String, dynamic>>().toList();
        if (_results.isEmpty) _error = 'Nothing found';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add food', style: textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search a product…',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!, style: textTheme.bodyMedium),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final p = _results[i];
                    final per = p['per_100g'] as Map<String, dynamic>?;
                    final kcal = (per?['calories'] as num?)?.round();
                    return ListTile(
                      title: Text((p['name'] as String?) ?? 'Unknown'),
                      subtitle: Text([
                        if (p['brand'] != null) p['brand'] as String,
                        if (kcal != null) '$kcal kcal / 100g',
                      ].join(' · ')),
                      onTap: () => _addProduct(p),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addProduct(Map<String, dynamic> product) async {
    final result = await showDialog<({double grams, String meal})>(
      context: context,
      builder: (_) => _PortionDialog(name: (product['name'] as String?) ?? ''),
    );
    if (result == null) return;

    final per = product['per_100g'] as Map<String, dynamic>?;
    double? d(String k) => (per?[k] as num?)?.toDouble();
    final per100g = Nutrition(
      calories: d('calories'),
      protein: d('protein'),
      fat: d('fat'),
      carbs: d('carbs'),
      sugar: d('sugar'),
      fiber: d('fiber'),
    );
    final scaled = scaleNutrition(per100g, result.grams);

    await ref.read(foodLogsDaoProvider).addLog(
          date: DateTime.now(),
          meal: result.meal,
          name: (product['name'] as String?) ?? 'Food',
          grams: result.grams,
          calories: scaled.calories,
          protein: scaled.protein,
          fat: scaled.fat,
          carbs: scaled.carbs,
          sugar: scaled.sugar,
          fiber: scaled.fiber,
        );
    if (mounted) Navigator.of(context).pop(); // закрываем лист поиска
  }
}

/// Диалог выбора граммов и приёма пищи.
class _PortionDialog extends StatefulWidget {
  const _PortionDialog({required this.name});
  final String name;
  @override
  State<_PortionDialog> createState() => _PortionDialogState();
}

class _PortionDialogState extends State<_PortionDialog> {
  final _grams = TextEditingController(text: '100');
  String _meal = 'snack';

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _grams,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Grams'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _meals.map((m) {
              return ChoiceChip(
                label: Text(m),
                selected: _meal == m,
                onSelected: (_) => setState(() => _meal = m),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final grams = double.tryParse(_grams.text.trim());
            if (grams == null || grams <= 0) return;
            Navigator.of(context).pop((grams: grams, meal: _meal));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
