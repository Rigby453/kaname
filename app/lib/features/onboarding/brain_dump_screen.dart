// Экран ИИ-онбординга «брейн-дамп» (Волна 6, этап 3, docs/AI-ONBOARDING-DESIGN.md).
//
// Одно большое поле-«холст» (VoiceTextField) + 6 вопросов-подсказок сверху,
// которые гаснут эвристикой по длине ответа (activeHintIndex — чистая
// функция, тестируется отдельно). «Собрать план» → согласие (один раз,
// SharedPreferences[kAiConsentKey]) → premium-гейт → POST /ai/onboarding-plan
// → превью-подтверждение (brain_dump_preview.dart).
//
// Сетевой/гейт/ошибки-паттерн скопирован из ai_quick_add_sheet.dart:
// premium ПЕРЕД вызовом; 403 → showPremiumUpsell; 502/503/прочее → снекбар
// с Retry, текст в поле НЕ очищается.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/settings/timezone_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart' show sharedPreferencesProvider;
import '../../core/widgets/kai_loader.dart';
import '../../core/widgets/voice_text_field.dart';
import '../../services/api/api_client.dart';
import '../auth/auth_controller.dart' show isPremiumProvider;
import '../mascot/kai_mascot.dart';
import '../paywall/paywall_screen.dart' show showPremiumUpsell;
import 'brain_dump_preview.dart';

/// Ключ SharedPreferences — согласие на отправку текста брейн-дампа ИИ-провайдеру.
/// Показываем диалог согласия только один раз (приватность #13).
const kAiConsentKey = 'ai_consent_accepted';

/// Число подсказок-вопросов (docs/AI-ONBOARDING-QUESTIONS-DRAFT.md §2).
const int kBrainDumpHintCount = 6;

/// Порог символов на одну подсказку — простая честная эвристика прогресса.
const int kBrainDumpHintThreshold = 60;

const List<String> _hintKeys = [
  'onboarding_ai.hint_1',
  'onboarding_ai.hint_2',
  'onboarding_ai.hint_3',
  'onboarding_ai.hint_4',
  'onboarding_ai.hint_5',
  'onboarding_ai.hint_6',
];

/// Сколько подсказок считать «отвеченными» (гаснут) при данной длине текста.
/// Подсказка i (0-based) гаснет, когда textLength > i*60 (т.е. пересечён
/// порог (i+1)-го вопроса). Ничего не обязательно — просто индикатор
/// прогресса. Результат ограничен [0, kBrainDumpHintCount].
///
/// Чистая функция — тестируется без виджета.
int activeHintIndex(int textLength) {
  if (textLength <= 0) return 0;
  final dimmed = textLength ~/ kBrainDumpHintThreshold;
  return dimmed.clamp(0, kBrainDumpHintCount);
}

/// Определяет IANA-таймзону для запроса (копия resolveQuickAddTimezone из
/// ai_quick_add_sheet.dart — тот же алгоритм, дублируем ради независимости
/// модулей друг от друга).
Future<String> resolveBrainDumpTimezone(WidgetRef ref) async {
  final override = ref.read(timezoneOverrideProvider);
  if (!override.isAuto && override.iana != null && override.iana!.isNotEmpty) {
    return override.iana!;
  }
  if (kIsWeb) return 'UTC';
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    return info.identifier;
  } catch (_) {
    return 'UTC';
  }
}

/// Диалог согласия на отправку текста ИИ-провайдеру. Показывается один раз —
/// повторные вызовы читают [kAiConsentKey] из SharedPreferences и не
/// показывают диалог снова. Возвращает true, если можно продолжать вызов ИИ.
Future<bool> ensureAiConsent(BuildContext context, SharedPreferences prefs) async {
  if (prefs.getBool(kAiConsentKey) ?? false) return true;

  final accepted = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.s('onboarding_ai.consent_title')),
      content: Text(ctx.s('onboarding_ai.consent_body')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(ctx.s('onboarding_ai.consent_cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(ctx.s('onboarding_ai.consent_accept')),
        ),
      ],
    ),
  );

  if (accepted == true) {
    await prefs.setBool(kAiConsentKey, true);
    return true;
  }
  return false;
}

class BrainDumpScreen extends ConsumerStatefulWidget {
  const BrainDumpScreen({super.key});

  @override
  ConsumerState<BrainDumpScreen> createState() => _BrainDumpScreenState();
}

class _BrainDumpScreenState extends ConsumerState<BrainDumpScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Перерисовка при вводе — включает кнопку и гасит подсказки.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend => _controller.text.trim().isNotEmpty && !_loading;

  void _showErrorSnack(String messageKey) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(context.s(messageKey)),
          action: SnackBarAction(
            label: context.s('onboarding_ai.retry'),
            onPressed: _buildPlan,
          ),
        ),
      );
  }

  Future<void> _buildPlan() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    // Premium-гейт ДО вызова (как в ai_quick_add_sheet) — экран доступен для
    // набора текста всем, но сборка плана требует premium.
    final premium = await ref.read(isPremiumProvider.future);
    if (!mounted) return;
    if (!premium) {
      showPremiumUpsell(context, context.s('onboarding_ai.feature_name'));
      return;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    final consented = await ensureAiConsent(context, prefs);
    if (!mounted) return;
    if (!consented) return;

    setState(() => _loading = true);

    try {
      final timezone = await resolveBrainDumpTimezone(ref);
      if (!mounted) return;
      final locale = localeTag(ref.read(localeNotifierProvider));
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final response = await ref.read(apiClientProvider).aiOnboardingPlan(
            answers: text,
            date: date,
            timezone: timezone,
            locale: locale,
          );

      final plan = parseOnboardingPlan(response);
      if (!mounted) return;
      if (plan.isEmpty) {
        setState(() => _loading = false);
        _showErrorSnack('onboarding_ai.parse_error');
        return;
      }

      setState(() => _loading = false);

      final day = DateTime.now();
      final result = await Navigator.of(context).push<int>(
        MaterialPageRoute(
          builder: (_) => BrainDumpPreviewScreen(plan: plan, day: day),
        ),
      );
      if (!mounted) return;
      // Приняли план (savedCount > 0) — закрываем и брейндамп-экран, отдавая
      // пользователя обратно туда, откуда он пришёл (Profile / приглашение).
      if (result != null && result > 0 && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (e.statusCode == 403) {
        showPremiumUpsell(context, context.s('onboarding_ai.feature_name'));
        return;
      }
      _showErrorSnack('onboarding_ai.error');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showErrorSnack('onboarding_ai.error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('onboarding_ai.screen_title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: KaiMascot(
                  size: 64,
                  emotion: _loading ? KaiEmotion.thinking : KaiEmotion.neutral,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.s('onboarding_ai.screen_subtitle'),
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(color: ext.textMuted),
              ),
              const SizedBox(height: 24),
              if (_loading) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: KaiLoader(label: context.s('onboarding_ai.loading')),
                  ),
                ),
              ] else ...[
                _HintList(textLength: _controller.text.length),
                const SizedBox(height: 20),
                VoiceTextField(
                  controller: _controller,
                  labelText: context.s('onboarding_ai.field_hint'),
                  maxLines: 10,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _canSend ? _buildPlan : null,
                    icon: Icon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), size: 18),
                    label: Text(context.s('onboarding_ai.build_plan_button')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Компактный список 6 вопросов-подсказок; подсказка тихо гаснет
/// (галочка + приглушённый цвет), когда пересечён её порог (activeHintIndex).
class _HintList extends StatelessWidget {
  const _HintList({required this.textLength});
  final int textLength;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dimmedCount = activeHintIndex(textLength);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _hintKeys.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == _hintKeys.length - 1 ? 0 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    i < dimmedCount
                        ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                        : PhosphorIcons.circle(),
                    size: 16,
                    color: i < dimmedCount ? ext.success : ext.textFaint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.s(_hintKeys[i]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: i < dimmedCount ? ext.textFaint : ext.textMuted,
                        decoration:
                            i < dimmedCount ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
