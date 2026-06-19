// Онбординг первого запуска: 3 слайда о сути продукта, затем переход к входу.
// Флаг 'onboarding_done' хранится в SharedPreferences; redirect в роутере
// показывает онбординг, пока флаг не выставлен.
//
// Редизайн (design-kai): editorial feel — displayLarge/headlineLarge serif,
// xxl breathing room, accent только на активном dot + кнопке Continue,
// Kai-маскот на первом слайде (отключается при reduce-motion).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/mascot_provider.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart'; // sharedPreferencesProvider
import '../../features/mascot/kai_mascot.dart';

const onboardingDoneKey = 'onboarding_done';

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
    if (_page < _slides.length - 1) {
      _pageController.nextPage(
        duration: effectiveDuration(context, kDurationNormal),
        curve: kCurveLift,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final isLast = _page == _slides.length - 1;
    // Kai: только на первом слайде, отключается при reduce-motion
    final showKai = ref.watch(showKaiProvider);
    final tone = ref.watch(toneProvider);
    final reduce = reduceMotionOf(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip — TextButton, минимальный вес
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

            // Слайды
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  // Первый слайд — Kai вместо иконки (при желании)
                  final bool isFirst = i == 0;
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

            // Dot-индикаторы: активный = accent, остальные = border
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: effectiveDuration(context, kDurationFast),
                  curve: kCurveLift,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    // Accent только для активного dot — дисциплина акцента
                    color: active ? colorScheme.primary : ext.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // Единственная primary-кнопка на шаг
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(
                    isLast
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

/// Слайд онбординга — editorial верстка с xxl spacing.
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
          // Kai или иконка — размещено по центру горизонтально
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
                    // Иконки нейтральные (textMuted), не accent — дисциплина
                    color: ext.textMuted,
                  ),
          ),

          const SizedBox(height: 48), // xxl breathing room

          // displayLarge / headlineLarge — editorial serif первого впечатления
          Text(
            context.s(slideData.titleKey),
            style: textTheme.headlineLarge,
            textAlign: TextAlign.left,
          ),

          const SizedBox(height: 16),

          // bodyLarge — комфортное чтение
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
