// Шит сравнения тарифов Free vs Premium.
// Открывается из paywall_screen.dart через showComparePlansSheet(context).
//
// Структура:
//   • ComparePlansSheet   — обёртка-шит с хэндлом, заголовком, кнопкой закрыть
//   • ComparePlansTable   — публичный виджет таблицы (тестируется напрямую)
//   • _TableHeader        — строка заголовков колонок
//   • _SectionHeader      — разделитель секции
//   • _FeatureRow         — одна строка фичи (name | Free | Premium)
//   • _CheckCell          — ячейка с иконкой check или lock

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Публичная функция-открывалка
// ---------------------------------------------------------------------------

/// Открывает шит сравнения тарифов снизу.
/// Вызывается из [PaywallScreen] по нажатию «Compare plans».
void showComparePlansSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ComparePlansSheet(),
  );
}

// ---------------------------------------------------------------------------
// Шит-обёртка
// ---------------------------------------------------------------------------

/// Полноэкранный модальный шит со сравнением тарифов.
class ComparePlansSheet extends StatelessWidget {
  const ComparePlansSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Шит занимает максимум 90% высоты экрана.
    // Column(mainAxisSize.max) заполняет доступное пространство, Flexible
    // отдаёт оставшееся место прокручиваемой таблице.
    final maxH = MediaQuery.of(context).size.height * 0.90;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: ext.border, width: 0.5),
          ),
          // Тень только для шитов (design-tokens: boxShadow only on sheets/popovers)
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        // mainAxisSize.max: Column заполняет maxH, Flexible делит остаток
        child: Column(
          children: [
            // Хэндл-перетяжка
            const SizedBox(height: 12),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: ext.textFaint.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Заголовок + кнопка ✕
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.s('paywall.compare_plans_title'),
                      style: textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        PhosphorIcons.x(),
                        size: 20,
                        color: ext.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Прокручиваемая таблица — Flexible берёт оставшееся место
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: ComparePlansTable(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Таблица сравнения (публичный виджет — тестируется напрямую)
// ---------------------------------------------------------------------------

/// Таблица «фича | Free | Premium» с иконками check/lock.
///
/// Секции:
///   1. Productivity  — все функции бесплатные
///   2. Wellbeing     — все функции бесплатные
///   3. AI features   — только в Premium
class ComparePlansTable extends StatelessWidget {
  const ComparePlansTable({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;

    // Секции данных
    final sections = _sections(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Строка заголовков колонок
        _TableHeader(),

        const SizedBox(height: 8),

        // Рендер каждой секции
        for (int si = 0; si < sections.length; si++) ...[
          _SectionHeader(title: sections[si].title),
          // Карточка с hairline border (design-tokens: card R14, border 0.5)
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ext.border, width: 0.5),
            ),
            child: Column(
              children: [
                for (int ri = 0; ri < sections[si].rows.length; ri++) ...[
                  _FeatureRow(row: sections[si].rows[ri]),
                  if (ri < sections[si].rows.length - 1)
                    Divider(
                      height: 0,
                      thickness: 0.5,
                      color: ext.border,
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  // Данные секций. Строится в build, чтобы иметь доступ к context.s().
  List<_Section> _sections(BuildContext context) {
    return [
      _Section(
        title: context.s('paywall.compare_section_productivity'),
        rows: [
          _FeatureData(
            label: context.s('paywall.compare_tasks_planning'),
            isFreeAvailable: true,
          ),
          _FeatureData(
            label: context.s('paywall.compare_priority_limit'),
            isFreeAvailable: true,
          ),
          _FeatureData(
            label: context.s('paywall.compare_streaks'),
            isFreeAvailable: true,
          ),
          _FeatureData(
            label: context.s('paywall.compare_review'),
            isFreeAvailable: true,
          ),
          _FeatureData(
            label: context.s('paywall.compare_diary'),
            isFreeAvailable: true,
          ),
          _FeatureData(
            label: context.s('paywall.compare_plan_sharing'),
            isFreeAvailable: true,
          ),
        ],
      ),
      _Section(
        title: context.s('paywall.compare_section_wellbeing'),
        rows: [
          _FeatureData(
            label: context.s('paywall.compare_water'),
            isFreeAvailable: true,
          ),
          _FeatureData(
            label: context.s('paywall.compare_sleep'),
            isFreeAvailable: true,
          ),
          _FeatureData(
            label: context.s('paywall.compare_breathing'),
            isFreeAvailable: true,
          ),
          _FeatureData(
            label: context.s('paywall.compare_workouts'),
            isFreeAvailable: true,
          ),
          _FeatureData(
            label: context.s('paywall.compare_food_basic'),
            isFreeAvailable: true,
          ),
        ],
      ),
      _Section(
        title: context.s('paywall.compare_section_ai'),
        rows: [
          // AI-строки — Premium only; используем уже существующие benefit-ключи
          _FeatureData(
            label: context.s('paywall.benefit_reschedule_title'),
            isFreeAvailable: false,
          ),
          _FeatureData(
            label: context.s('paywall.benefit_menu_title'),
            isFreeAvailable: false,
          ),
          _FeatureData(
            label: context.s('paywall.benefit_photo_title'),
            isFreeAvailable: false,
          ),
          _FeatureData(
            label: context.s('paywall.benefit_voice_title'),
            isFreeAvailable: false,
          ),
          _FeatureData(
            label: context.s('paywall.benefit_wrapped_title'),
            isFreeAvailable: false,
          ),
          _FeatureData(
            label: context.s('paywall.compare_ai_insights'),
            isFreeAvailable: false,
          ),
        ],
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Приватные вспомогательные классы
// ---------------------------------------------------------------------------

/// Данные одной секции таблицы.
class _Section {
  const _Section({required this.title, required this.rows});
  final String title;
  final List<_FeatureData> rows;
}

/// Данные одной строки таблицы.
class _FeatureData {
  const _FeatureData({required this.label, required this.isFreeAvailable});
  final String label;
  // true → check + check; false → lock + check
  final bool isFreeAvailable;
}

/// Строка заголовков колонок (пустая колонка фич + Free + Premium).
class _TableHeader extends StatelessWidget {
  const _TableHeader();

  static const double _colW = 52.0;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        // Пустая ячейка под колонку фич
        const Expanded(child: SizedBox()),
        // Free
        SizedBox(
          width: _colW,
          child: Text(
            context.s('paywall.compare_col_free'),
            style: textTheme.labelSmall?.copyWith(
              color: ext.textMuted,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Premium
        SizedBox(
          width: _colW,
          child: Text(
            context.s('paywall.compare_col_premium'),
            style: textTheme.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Заголовок секции таблицы (Productivity / Wellbeing / AI features).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4, left: 2),
      child: Text(
        title,
        style: textTheme.labelMedium?.copyWith(
          color: ext.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Одна строка таблицы (название фичи + ячейка Free + ячейка Premium).
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.row});
  final _FeatureData row;

  static const double _colW = 52.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Название фичи — Expanded для overflow-safety на 320px
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(
              row.label,
              style: textTheme.bodySmall?.copyWith(color: ext.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ),
        // Free колонка: check если free, lock если premium-only
        SizedBox(
          width: _colW,
          child: Center(
            child: _CheckCell(
              available: row.isFreeAvailable,
              isPremiumCol: false,
            ),
          ),
        ),
        // Premium колонка: всегда check
        SizedBox(
          width: _colW,
          child: Center(
            child: _CheckCell(
              available: true,
              isPremiumCol: true,
            ),
          ),
        ),
      ],
    );
  }
}

/// Ячейка со значком доступности.
///
/// [available] = true → иконка check (fill).
/// [available] = false → иконка lock (fill), означает «заблокировано» в Free.
/// [isPremiumCol] влияет на цвет: true → colorScheme.primary, false → success/textFaint.
class _CheckCell extends StatelessWidget {
  const _CheckCell({required this.available, required this.isPremiumCol});
  final bool available;
  final bool isPremiumCol;

  static const double _iconSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;

    if (available) {
      // Галочка: accent в Premium-колонке, success в Free-колонке
      return Icon(
        PhosphorIcons.check(PhosphorIconsStyle.fill),
        size: _iconSize,
        color: isPremiumCol ? cs.primary : ext.success,
      );
    } else {
      // Замок: в Free-колонке (функция заблокирована)
      return Icon(
        PhosphorIcons.lock(PhosphorIconsStyle.fill),
        size: _iconSize,
        color: ext.textFaint,
      );
    }
  }
}
