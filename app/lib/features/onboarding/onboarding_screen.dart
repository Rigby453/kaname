// Онбординг первого запуска: Language-слайд + 3 слайда о сути продукта,
// затем переход к входу.
// Флаг 'onboarding_done' хранится в SharedPreferences; redirect в роутере
// показывает онбординг, пока флаг не выставлен.
//
// Страница 0: выбор языка (3 кнопки; тап выставляет locale + переходит дальше).
// Страницы 1–3: editorial value slides (Kai на первой).
// Редизайн (design-kai): displayLarge/headlineLarge serif,
// xxl breathing room, accent только на активном dot + кнопке Continue.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/settings/mascot_provider.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart'; // sharedPreferencesProvider
import '../../features/mascot/kai_mascot.dart';

const onboardingDoneKey = 'onboarding_done';

// Индекс language-слайда.
const _kLangPage = 0;

// Value-слайды (после language).
class _SlideData {
  const _SlideData(this.icon, this.titleKey, this.subtitleKey);
  final IconData icon;
  final String titleKey;
  final String subtitleKey;
}

const _slides = [
  _SlideData(
    Icons.flag_outlined,
    'onboarding.slide1_title',
    'onboarding.slide1_subtitle',
  ),
  _SlideData(
    Icons.wb_twilight,
    'onboarding.slide2_title',
    'onboarding.slide2_subtitle',
  ),
  _SlideData(
    Icons.menu_book_outlined,
    'onboarding.slide3_title',
    'onboarding.slide3_subtitle',
  ),
];

// Всего страниц: 1 language + 3 value.
const _pageCount = 1 + 3; // 4

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(sharedPreferencesProvider).setBool(onboardingDoneKey, true);
    if (mounted) context.go('/auth');
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _pageController.nextPage(
        duration: effectiveDuration(context, kDurationNormal),
        curve: kCurveLift,
      );
    } else {
      _finish();
    }
  }

  /// Тап на кнопку языка: выставляет locale LIVE и переходит к следующей странице.
  void _selectLocale(Locale locale) {
    ref.read(localeNotifierProvider.notifier).setLocale(locale);
    _next();
  }

  bool get _isLangPage => _page == _kLangPage;
  bool get _isLastPage => _page == _pageCount - 1;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final showKai = ref.watch(showKaiProvider);
    final tone = ref.watch(toneProvider);
    final reduce = reduceMotionOf(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip — показываем на всех страницах, включая language
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      context.s('btn.skip'),
                      style: textTheme.labelLarge?.copyWith(
                        color: ext.textMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Страницы
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pageCount,
                itemBuilder: (context, i) {
                  // Страница 0 — выбор языка
                  if (i == _kLangPage) {
                    return _LanguageSlide(
                      ext: ext,
                      textTheme: textTheme,
                      colorScheme: colorScheme,
                      onSelect: _selectLocale,
                    );
                  }
                  // Страницы 1–3 — value slides (индекс слайда = i - 1)
                  final s = _slides[i - 1];
                  final isFirst = i == 1; // первый value-слайд показывает Kai
                  return _OnboardingSlide(
                    slideData: s,
                    isFirst: isFirst,
                    showKai: showKai && !reduce && isFirst,
                    tone: tone,
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                    ext: ext,
                  );
                },
              ),
            ),

            // Dot-индикаторы
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pageCount, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: effectiveDuration(context, kDurationFast),
                  curve: kCurveLift,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? colorScheme.primary : ext.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // CTA-кнопка: скрыта на language-слайде (переход идёт через кнопки языка).
            // На остальных — Continue / Get started.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: _isLangPage
                  ? const SizedBox.shrink()
                  : SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _next,
                        child: Text(
                          _isLastPage
                              ? context.s('onboarding.btn_get_started')
                              : context.s('onboarding.btn_next'),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Слайд выбора языка
// ---------------------------------------------------------------------------

class _LanguageSlide extends ConsumerWidget {
  const _LanguageSlide({
    required this.ext,
    required this.textTheme,
    required this.colorScheme,
    required this.onSelect,
  });

  final FocusThemeExtension ext;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final void Function(Locale locale) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeNotifierProvider);
    final currentTag = localeTag(locale);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Иконка языка — нейтральная, не accent
          Center(
            child: Icon(
              Icons.language_rounded,
              size: 64,
              color: ext.textMuted,
            ),
          ),
          const SizedBox(height: 32),

          Text(
            context.s('onboarding_quiz.s4_title'),
            style: textTheme.headlineLarge,
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 24),

          // Список всех 12 языков — скролл-список внутри Expanded
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: localeEntries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final entry = localeEntries[i];
                final tag = localeTag(entry.locale);
                return _LangButton(
                  label: entry.displayName,
                  tag: tag,
                  selected: currentTag == tag,
                  colorScheme: colorScheme,
                  ext: ext,
                  textTheme: textTheme,
                  onTap: () => onSelect(entry.locale),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  const _LangButton({
    required this.label,
    required this.tag,
    required this.selected,
    required this.colorScheme,
    required this.ext,
    required this.textTheme,
    required this.onTap,
  });

  final String label;
  final String tag;
  final bool selected;
  final ColorScheme colorScheme;
  final FocusThemeExtension ext;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: kDurationSnap,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? colorScheme.primary : ext.border,
              width: selected ? 1.5 : 1.0,
            ),
            color: selected
                ? colorScheme.primary.withAlpha(18)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? colorScheme.primary : null,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Value-слайд (editorial)
// ---------------------------------------------------------------------------

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.slideData,
    required this.isFirst,
    required this.showKai,
    required this.tone,
    required this.textTheme,
    required this.colorScheme,
    required this.ext,
  });

  final _SlideData slideData;
  final bool isFirst;
  final bool showKai;
  final AppTone tone;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final FocusThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kai или иконка — по центру горизонтально
          Center(
            child: showKai
                ? KaiMascot(
                    size: 96,
                    emotion: KaiEmotion.neutral,
                    isHarsh: tone == AppTone.harsh,
                  )
                : Icon(
                    slideData.icon,
                    size: 64,
                    color: ext.textMuted,
                  ),
          ),

          const SizedBox(height: 48), // xxl breathing room

          Text(
            context.s(slideData.titleKey),
            style: textTheme.headlineLarge,
            textAlign: TextAlign.left,
          ),

          const SizedBox(height: 16),

          Text(
            context.s(slideData.subtitleKey),
            style: textTheme.bodyLarge?.copyWith(color: ext.textMuted),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }
}
