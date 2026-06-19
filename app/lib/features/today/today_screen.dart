// FL-TODAY-01: Экран Today — собирает кольцо прогресса, строку streak,
// список задач и FAB добавления. AppBar даёт общая оболочка ScaffoldWithNavBar,
// поэтому здесь вложенный Scaffold без AppBar (нужен только ради FAB),
// а приветствие и дата вынесены в шапку тела.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/mascot_provider.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/breakpoints.dart';
import '../../core/widgets/collapsing_fab.dart';
import '../../core/widgets/kai_loader.dart';
import '../../features/mascot/kai_mascot.dart';
import '../../services/streak/streak_service.dart';
import '../../services/widget/widget_service.dart';
import 'widgets/add_task_sheet.dart';
import 'widgets/celebration_overlay.dart';
import 'widgets/evening_review_card.dart';
import 'widgets/morning_review_card.dart';
import 'widgets/progress_ring.dart';
import 'widgets/streak_row.dart';
import 'widgets/task_list.dart';

/// Все задачи на сегодня (реактивно из Drift)
final todayItemsProvider =
    StreamProvider.autoDispose<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchTodayItems(DateTime.now());
});

/// Только main-задачи на сегодня — для кольца прогресса
final todayMainItemsProvider =
    StreamProvider.autoDispose<List<ItemsTableData>>((ref) {
  return ref.watch(itemsDaoProvider).watchMainItems(DateTime.now());
});

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch/listen — ВНЕ LayoutBuilder: callbacks LayoutBuilder не регистрируют
    // подписки Riverpod для пересборки (вызываются в layout-фазе, не в build-фазе).
    ref.listen(todayMainItemsProvider, (_, _) async {
      await ref.read(streakServiceProvider).recomputeForDay(DateTime.now());
      await refreshHomeWidget(
        itemsDao: ref.read(itemsDaoProvider),
        streakDao: ref.read(streakDaoProvider),
      );
    });

    final now = DateTime.now();
    final itemsAsync = ref.watch(todayItemsProvider);
    final mainItems = ref.watch(todayMainItemsProvider).valueOrNull ??
        const <ItemsTableData>[];
    final tone = ref.watch(toneProvider);
    final allMainDone = mainItems.isNotEmpty &&
        mainItems.every((i) => i.status == 'done' || i.status == 'skipped');

    // Kai: определяем эмоцию по реальному состоянию дня.
    //
    // Приоритет проверок (сверху вниз — первое совпавшее побеждает):
    //   1. success  — все главные задачи закрыты.
    //   2. anxious  — есть просроченные pending main/important задачи СЕГОДНЯ
    //                 (scheduledAt в прошлом, статус pending, приоритет main|important).
    //   3. thinking — есть карточка утреннего разбора (overdue != empty, т.е.
    //                 MorningReviewCard сейчас показана) и главные задачи ещё не начаты,
    //                 ИЛИ показана карточка вечернего разбора (час >= 17).
    //   4. neutral  — иначе.
    final showKai = ref.watch(showKaiProvider);
    final overdueItems = ref.watch(overduePendingProvider).valueOrNull ??
        const <ItemsTableData>[];
    // Переиспользуем уже отслеживаемый itemsAsync — не добавляем лишних подписок.
    final allItems = itemsAsync.valueOrNull ?? const <ItemsTableData>[];

    // Задачи с просроченным временем сегодня (main|important, pending, scheduledAt < now)
    final overdueToday = allItems.where((i) =>
      (i.priority == 'main' || i.priority == 'important') &&
      i.status == 'pending' &&
      i.scheduledAt.isBefore(now),
    ).toList();

    // Показан ли утренний разбор (есть просроченные невыполненные из прошлых дней)?
    final morningReviewVisible = overdueItems.isNotEmpty;
    // Показан ли вечерний разбор (время >= 17:00)?
    final eveningReviewVisible = now.hour >= 17;

    final KaiEmotion kaiEmotion;
    if (allMainDone) {
      kaiEmotion = KaiEmotion.success;
    } else if (overdueToday.isNotEmpty) {
      kaiEmotion = KaiEmotion.anxious;
    } else if (morningReviewVisible ||
        (eveningReviewVisible && mainItems.isNotEmpty &&
         mainItems.any((i) => i.status == 'pending'))) {
      kaiEmotion = KaiEmotion.thinking;
    } else {
      kaiEmotion = KaiEmotion.neutral;
    }

    final isTablet = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    if (isTablet) {
      return _buildTabletLayout(
          context, itemsAsync, mainItems, tone, allMainDone, now,
          showKai: showKai, kaiEmotion: kaiEmotion);
    }
    return _buildMobileLayout(
        context, itemsAsync, mainItems, tone, allMainDone, now,
        showKai: showKai, kaiEmotion: kaiEmotion);
  }

  /// Мобильный макет — одна колонка, оригинальный вид.
  Widget _buildMobileLayout(
    BuildContext context,
    AsyncValue<List<ItemsTableData>> itemsAsync,
    List<ItemsTableData> mainItems,
    AppTone tone,
    bool allMainDone,
    DateTime now, {
    required bool showKai,
    required KaiEmotion kaiEmotion,
  }) {

    return Stack(
      children: [
        Scaffold(
          // CollapsingFab: развёрнут «+ Add» в покое, сворачивается при скролле вниз.
          // Зазор ≥16dp над таб-баром обеспечивается стандартным FAB-отступом Flutter
          // (16dp от нижней границы SafeArea); extraBottomMargin не нужен, т.к.
          // ScaffoldWithNavBar уже корректирует MediaQuery.padding для вложенных Scaffold.
          floatingActionButton: CollapsingFab(
            onPressed: () => showAddTaskSheet(context, day: now),
            icon: const Icon(Icons.add),
            label: Text(context.s('today.fab_add')),
          ),
          body: itemsAsync.when(
            // Заменяем стандартный спиннер на KaiLoader (BOLD design system)
            loading: () => Center(
              child: KaiLoader(label: context.s('loading.tasks')),
            ),
            error: (err, _) => Center(child: Text('Failed to load tasks: $err')),
            data: (items) {
              return ListView(
                // 24dp горизонтальный отступ экрана (02-type-space.md §4.1: lg=24)
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _Header(now: now)),
                      if (showKai) ...[
                        const SizedBox(width: 8),
                        _KaiHeader(
                          emotion: kaiEmotion,
                          isHarsh: tone == AppTone.harsh,
                        ),
                      ],
                      const _ToneToggle(),
                    ],
                  ),
                  // xl=32 между шапкой и кольцом (02-type-space.md §4.1)
                  const SizedBox(height: 32),
                  Center(child: ProgressRing(items: mainItems)),
                  // xl=32 между кольцом и streak-строкой
                  const SizedBox(height: 32),
                  const StreakRow(),
                  if (allMainDone) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        ToneCopy.allDone(tone),
                        textAlign: TextAlign.center,
                        // success-цвет через ThemeExtension (не accent — это позитивный фидбэк)
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context)
                                  .extension<FocusThemeExtension>()
                                  ?.success,
                            ),
                      ),
                    ),
                  ],
                  // Карточки обзора — после streak, с разделителем xl=32
                  const SizedBox(height: 32),
                  const MorningReviewCard(),
                  const EveningReviewCard(),
                  const SizedBox(height: 32),
                  TaskList(items: items, day: now),
                ],
              );
            },
          ),
        ),
        const Positioned.fill(child: CelebrationOverlay()),
      ],
    );
  }

  /// Планшетный макет ≥600px — две колонки равной ширины.
  /// Левая: шапка + ProgressRing + StreakRow + карточки обзора.
  /// Правая: список задач.
  Widget _buildTabletLayout(
    BuildContext context,
    AsyncValue<List<ItemsTableData>> itemsAsync,
    List<ItemsTableData> mainItems,
    AppTone tone,
    bool allMainDone,
    DateTime now, {
    required bool showKai,
    required KaiEmotion kaiEmotion,
  }) {
    final items = itemsAsync.valueOrNull ?? const <ItemsTableData>[];

    return Stack(
      children: [
        Scaffold(
          // Планшет: collapse-on-scroll не применяем — две независимые колонки
          // прокручиваются отдельно, поэтому CollapsingFab будет реагировать
          // только на одну из них непредсказуемо. Используем обычный extended FAB
          // с корректным зазором через стандартный отступ Flutter.
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showAddTaskSheet(context, day: now),
            icon: const Icon(Icons.add),
            label: Text(context.s('today.fab_add')),
          ),
          body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Левая колонка: шапка, кольцо, серия, карточки обзора ---
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _Header(now: now)),
                            if (showKai) ...[
                              const SizedBox(width: 8),
                              _KaiHeader(
                                emotion: kaiEmotion,
                                isHarsh: tone == AppTone.harsh,
                              ),
                            ],
                            const _ToneToggle(),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Center(child: ProgressRing(items: mainItems)),
                        const SizedBox(height: 32),
                        const StreakRow(),
                        if (allMainDone) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              ToneCopy.allDone(tone),
                              textAlign: TextAlign.center,
                              // success-цвет через ThemeExtension
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .extension<FocusThemeExtension>()
                                        ?.success,
                                  ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        const MorningReviewCard(),
                        const EveningReviewCard(),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                // --- Правая колонка: список задач ---
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: TaskList(items: items, day: now),
                  ),
                ),
              ],
            ),
        ),
        const Positioned.fill(child: CelebrationOverlay()),
      ],
    );
  }
}

/// Приветствие, зависящее от времени суток, + сегодняшняя дата
class _Header extends StatelessWidget {
  const _Header({required this.now});

  final DateTime now;

  String _greeting(BuildContext context) {
    final hour = now.hour;
    if (hour < 12) return context.s('today.greeting_morning');
    if (hour < 18) return context.s('today.greeting_afternoon');
    return context.s('today.greeting_evening');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // textFaint для даты — tertiary, не конкурирует с приветствием
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // headlineLarge: 40sp, display-font (Fraunces/Newsreader/...) по 02-type-space.md §1
        Text(_greeting(context), style: textTheme.headlineLarge),
        const SizedBox(height: 4),
        Text(
          DateFormat.yMMMMEEEEd().format(now),
          style: textTheme.bodyMedium?.copyWith(color: ext?.textFaint),
        ),
      ],
    );
  }
}

/// Маленький тумблер тона gentle/harsh в шапке Today.
class _ToneToggle extends ConsumerWidget {
  const _ToneToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    final harsh = tone == AppTone.harsh;
    return TextButton.icon(
      onPressed: () => ref.read(toneProvider.notifier).toggle(),
      icon: Icon(harsh ? Icons.bolt : Icons.spa_outlined, size: 18),
      label: Text(harsh ? context.s('today.tone_harsh') : context.s('today.tone_gentle')),
    );
  }
}

/// Маскот Kai в шапке Today — 56×56, вертикально выровнен по центру.
/// Виден только если showKaiProvider == true (условие проверяется в _buildMobileLayout
/// и _buildTabletLayout, сюда попадаем уже внутри if-блока).
///
/// Tap micro-interaction (04-kai.md §3.4):
///   Tap циклически переключает _tapOverride через neutral → success → thinking → null
///   (возврат к app-state-driven emotion через 3 секунды).
///   Только если emotion не блокирует смысловой onTap снаружи.
class _KaiHeader extends StatefulWidget {
  const _KaiHeader({
    required this.emotion,
    required this.isHarsh,
  });

  final KaiEmotion emotion;
  final bool isHarsh;

  @override
  State<_KaiHeader> createState() => _KaiHeaderState();
}

class _KaiHeaderState extends State<_KaiHeader> {
  // null = показываем реальную app-state emotion; non-null = tap-overide
  KaiEmotion? _tapOverride;
  int _tapCycleIndex = 0; // индекс внутри цикла
  // Таймер сброса override после 3 секунд
  dynamic _resetTimer; // Timer, но import dart:async не нужен — используем Future+bool

  // Порядок цикла по 04-kai.md §3.4
  static const _tapCycle = [
    KaiEmotion.neutral,
    KaiEmotion.success,
    KaiEmotion.thinking,
  ];

  @override
  void dispose() {
    // Отменяем ожидающий сброс при удалении виджета
    _resetTimer = null; // флаг: callback не выполняется
    super.dispose();
  }

  void _handleTap() {
    // Отменяем предыдущий таймер (через флаг)
    final resetId = Object(); // уникальный токен для каждого тапа
    _resetTimer = resetId;

    setState(() {
      _tapOverride = _tapCycle[_tapCycleIndex % _tapCycle.length];
      _tapCycleIndex++;
    });

    // Сбрасываем override через 3 секунды
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_resetTimer != resetId) return; // был ещё один тап — не сбрасываем
      setState(() {
        _tapOverride = null;
        _tapCycleIndex = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // top: 4 — оптическое выравнивание с базовой линией двустрочного заголовка
      // (04-kai.md §1.3)
      padding: const EdgeInsets.only(top: 4),
      child: KaiMascot(
        size: 56,
        emotion: _tapOverride ?? widget.emotion,
        isHarsh: widget.isHarsh,
        onTap: _handleTap,
      ),
    );
  }
}
