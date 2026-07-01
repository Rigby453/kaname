// Экран глобального поиска (#17, часть 2/2 — UI).
// Слой данных (search_providers.dart, search_results_model.dart) уже готов:
// globalSearchQueryProvider хранит нормализуемый провайдером сырой запрос,
// globalSearchResultsProvider(query) считает совпадения по 4 сущностям
// локальной Drift-БД (задачи/дневник/рецепты/покупки). Здесь — только рендер
// + debounce ~300мс перед записью в провайдер (чтобы не сканировать БД на
// каждый символ ввода).
//
// Навигация по хиту (kind, id, date) — см. GlobalSearchHit:
//   - task: выставляем selectedDayProvider = hit.date (если есть) и уходим на
//     Plan (`context.go('/plan')`). ДЕГРАДАЦИЯ: Plan не имеет API «открыть и
//     выделить конкретный item по id» без рефакторинга экрана — переход на
//     нужный день уже осмысленно приближает пользователя к задаче.
//   - diary: открываем DiaryDayDetailScreen(date: hit.date) — тот же паттерн,
//     что features/diary/diary_history_screen.dart. Точный переход, не деградация.
//   - recipe: открываем /recipes/:id (RecipeEditorScreen). Точный переход.
//   - shopping: открываем /shopping. Список один на пользователя — id хита не
//     нужен для навигации (сама позиция видна в списке), это не деградация,
//     так задумано в data-слое (см. комментарий в search_results_model.dart).
//
// Иконки: Phosphor (regular). Секции — та же типографика/отступы, что
// _SectionHeader в today/widgets/task_list.dart (titleSmall + textMuted).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/theme/app_theme.dart';
import '../diary/diary_day_detail_screen.dart';
import '../mascot/kai_mascot.dart';
import '../plan/widgets/week_strip.dart' show dateOnly, selectedDayProvider;
import 'search_providers.dart';
import 'search_results_model.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() =>
      _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Дебаунс: обновляем провайдер (и тем самым запускаем поиск в БД) только
  /// через ~300мс тишины после последнего символа.
  void _onChanged(String value) {
    setState(() {}); // немедленно обновляем видимость крестика очистки
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(globalSearchQueryProvider.notifier).state = value;
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(globalSearchQueryProvider.notifier).state = '';
    setState(() {});
  }

  void _openHit(GlobalSearchHit hit) {
    switch (hit.kind) {
      case SearchHitKind.task:
        if (hit.date != null) {
          ref.read(selectedDayProvider.notifier).state = dateOnly(hit.date!);
        }
        context.go('/plan');
        break;
      case SearchHitKind.diary:
        final day = hit.date != null ? dateOnly(hit.date!) : dateOnly(DateTime.now());
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DiaryDayDetailScreen(date: day),
          ),
        );
        break;
      case SearchHitKind.recipe:
        context.push('/recipes/${hit.id}');
        break;
      case SearchHitKind.shopping:
        context.push('/shopping');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(globalSearchQueryProvider);
    final resultsAsync = ref.watch(globalSearchResultsProvider(query));
    final queryIsEmpty = query.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('search.title')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.s('search.hint'),
                prefixIcon: Icon(
                  PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.regular),
                  size: 20,
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          PhosphorIcons.x(PhosphorIconsStyle.regular),
                          size: 20,
                        ),
                        onPressed: _clear,
                      )
                    : null,
                isDense: true,
              ),
              onChanged: _onChanged,
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              data: (results) => _ResultsView(
                results: results,
                queryIsEmpty: queryIsEmpty,
                onTap: _openHit,
              ),
              // Компактный индикатор (не полноэкранный спиннер) — не дёргает
              // раскладку при вводе; при пустом запросе не показываем вовсе.
              loading: () =>
                  queryIsEmpty ? const SizedBox.shrink() : const _CompactLoading(),
              error: (_, _) => _ErrorState(message: context.s('search.error')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Компактный индикатор загрузки — небольшой круг сверху, не занимает весь
/// экран (UB-задача: "не дёргаться при вводе").
class _CompactLoading extends StatelessWidget {
  const _CompactLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 32),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: ext?.textMuted),
        ),
      ),
    );
  }
}

/// Тело результатов: пусто при пустом запросе, empty-state при отсутствии
/// совпадений, иначе секции по типу (только непустые).
class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.results,
    required this.queryIsEmpty,
    required this.onTap,
  });

  final GlobalSearchResults results;
  final bool queryIsEmpty;
  final void Function(GlobalSearchHit) onTap;

  @override
  Widget build(BuildContext context) {
    if (queryIsEmpty) return const SizedBox.shrink();
    if (results.isEmpty) return const _NoResults();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (results.tasks.isNotEmpty)
          _Section(
            titleKey: 'search.tasks',
            hits: results.tasks,
            onTap: onTap,
          ),
        if (results.diary.isNotEmpty)
          _Section(
            titleKey: 'search.diary',
            hits: results.diary,
            onTap: onTap,
          ),
        if (results.recipes.isNotEmpty)
          _Section(
            titleKey: 'search.recipes',
            hits: results.recipes,
            onTap: onTap,
          ),
        if (results.shopping.isNotEmpty)
          _Section(
            titleKey: 'search.shopping',
            hits: results.shopping,
            onTap: onTap,
          ),
      ],
    );
  }
}

class _NoResults extends ConsumerWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KaiMascot(
              size: 64,
              emotion: KaiEmotion.neutral,
              isHarsh: tone == AppTone.harsh,
            ),
            const SizedBox(height: 16),
            Text(
              context.s('search.no_results'),
              style: textTheme.bodyMedium?.copyWith(color: ext?.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Секция результатов одного типа: заголовок (только если есть хиты — сами
/// вызывающие уже это гарантируют через `if (...isNotEmpty)`) + список строк.
class _Section extends StatelessWidget {
  const _Section({
    required this.titleKey,
    required this.hits,
    required this.onTap,
  });

  final String titleKey;
  final List<GlobalSearchHit> hits;
  final void Function(GlobalSearchHit) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: _SectionHeader(title: context.s(titleKey)),
        ),
        ...hits.map((hit) => _ResultTile(hit: hit, onTap: () => onTap(hit))),
      ],
    );
  }
}

/// Заголовок секции — зеркалит today/widgets/task_list.dart::_SectionHeader
/// (titleSmall + textMuted, тот же паттерн, что "REST OF THE DAY" и др.).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: ext?.textMuted,
          ),
    );
  }
}

/// Одна строка результата: иконка типа + заголовок (ellipsis) + вторая строка
/// (snippet, если есть; иначе дата, если есть; иначе ничего).
class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.hit, required this.onTap});

  final GlobalSearchHit hit;
  final VoidCallback onTap;

  IconData _iconFor(SearchHitKind kind) => switch (kind) {
        SearchHitKind.task => PhosphorIcons.checkCircle(PhosphorIconsStyle.regular),
        SearchHitKind.diary => PhosphorIcons.notebook(PhosphorIconsStyle.regular),
        SearchHitKind.recipe => PhosphorIcons.cookingPot(PhosphorIconsStyle.regular),
        SearchHitKind.shopping =>
          PhosphorIcons.shoppingCart(PhosphorIconsStyle.regular),
      };

  String? _subtitle() {
    if (hit.snippet != null && hit.snippet!.trim().isNotEmpty) {
      return hit.snippet;
    }
    if (hit.date != null) {
      return DateFormat('d MMM y').format(hit.date!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textTheme = Theme.of(context).textTheme;
    final subtitle = _subtitle();

    return ListTile(
      onTap: onTap,
      leading: Icon(_iconFor(hit.kind), size: 20, color: ext?.textMuted),
      title: Text(
        hit.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: ext?.textMuted),
            ),
    );
  }
}
