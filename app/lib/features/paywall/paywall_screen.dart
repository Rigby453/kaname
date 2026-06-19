// Экран подписки / пейволл (SPEC: $10/мес, premium открывает AI).
// Реальные платежи (RevenueCat) — Phase 1; сейчас Subscribe работает через
// PurchaseService (заглушка): в debug вызывает dev-апгрейд, в release — сообщает
// «скоро». Одна кнопка Subscribe заменяет прежние Subscribe + Dev: unlock premium.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import '../../services/api/api_client.dart';
import '../../services/purchases/purchase_service.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_screen.dart' show currentUserProvider;

// Иконки остаются статичными; тексты локализуются через context.s().
const List<({IconData icon, String titleKey, String subtitleKey})> _benefits = [
  (
    icon: Icons.auto_awesome,
    titleKey: 'paywall.benefit_smarter_title',
    subtitleKey: 'paywall.benefit_smarter_subtitle',
  ),
  (
    icon: Icons.bolt,
    titleKey: 'paywall.benefit_tone_title',
    subtitleKey: 'paywall.benefit_tone_subtitle',
  ),
  (
    icon: Icons.insights,
    titleKey: 'paywall.benefit_diary_title',
    subtitleKey: 'paywall.benefit_diary_subtitle',
  ),
  (
    icon: Icons.photo_camera_outlined,
    titleKey: 'paywall.benefit_photo_title',
    subtitleKey: 'paywall.benefit_photo_subtitle',
  ),
  (
    icon: Icons.block,
    titleKey: 'paywall.benefit_noads_title',
    subtitleKey: 'paywall.benefit_noads_subtitle',
  ),
];

/// Показывает апселл-снэкбар с действием «Upgrade» → пейволл.
/// Вызывается там, где упёрлись в premium-гейт (AI-фичи).
void showPremiumUpsell(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Premium feature — upgrade for $feature'),
      action: SnackBarAction(
        label: context.s('paywall.upgrade'),
        onPressed: () => context.push('/paywall'),
      ),
    ),
  );
}

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _working = false;

  Future<void> _subscribe() async {
    setState(() => _working = true);
    try {
      final outcome = await ref.read(purchaseServiceProvider).buyPremium();
      if (!mounted) return;

      switch (outcome) {
        case PurchaseOutcome.success:
          ref.invalidate(isPremiumProvider);
          ref.invalidate(currentUserProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('paywall.welcome_premium'))),
          );
          context.pop();

        case PurchaseOutcome.unavailable:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.s('paywall.coming_soon')),
            ),
          );

        case PurchaseOutcome.error:
          // Если не авторизован — подсказываем войти.
          final isAuthed =
              ref.read(authControllerProvider.notifier).isAuthenticated;
          final message = isAuthed
              ? context.s('paywall.error_generic')
              : context.s('paywall.sign_in_to_subscribe');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );

        case PurchaseOutcome.cancelled:
          break;
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _devActivate() async {
    setState(() => _working = true);
    try {
      await ref.read(apiClientProvider).devUpgrade(tier: 'premium');
      ref.invalidate(isPremiumProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium activated!')),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _devDeactivate() async {
    setState(() => _working = true);
    try {
      await ref.read(apiClientProvider).devUpgrade(tier: 'free');
      ref.invalidate(isPremiumProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downgraded to Free')),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _working = true);
    try {
      final outcome =
          await ref.read(purchaseServiceProvider).restorePurchases();
      if (!mounted) return;

      switch (outcome) {
        case PurchaseOutcome.success:
          ref.invalidate(isPremiumProvider);
          ref.invalidate(currentUserProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('paywall.restored'))),
          );
          context.pop();

        case PurchaseOutcome.unavailable:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.s('paywall.nothing_to_restore')),
            ),
          );

        case PurchaseOutcome.error:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('paywall.restore_error'))),
          );

        case PurchaseOutcome.cancelled:
          break;
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final isAuthed = ref.read(authControllerProvider.notifier).isAuthenticated;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('paywall.title'))),
      body: SafeArea(
        child: _working
            ? const Center(child: KaiLoader(label: 'Processing…'))
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  // Заголовок экрана — display font через headlineSmall
                  Text(
                    context.s('paywall.headline'),
                    style: textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.s('paywall.subheadline'),
                    style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                  ),
                  const SizedBox(height: 28),

                  // Список фич — иконки success (checkmark-feel), не accent
                  ..._benefits.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // success color для позитивных фич (03-components §1: success = completion)
                          Icon(b.icon, color: ext.success, size: 22),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.s(b.titleKey),
                                  style: textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.s(b.subtitleKey),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: ext.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Карточка цены — «best value» highlight: accentMuted fill (03-components §1)
                  Card(
                    color: ext.accentMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.primary, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '\$10',
                            // displayMedium для героической цены
                            style: textTheme.displayMedium,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.s('paywall.per_month'),
                            style: textTheme.bodyMedium?.copyWith(
                              color: ext.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Подсказка для незалогиненных — caption, нейтральная
                  if (!isAuthed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        context.s('paywall.sign_in_hint'),
                        style: textTheme.bodySmall?.copyWith(
                          color: ext.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Единственная primary CTA — FilledButton (03-components §2)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _working ? null : _subscribe,
                      child: Text(context.s('paywall.subscribe')),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Восстановление покупок — TextButton (третичный, не акцентный)
                  Center(
                    child: TextButton(
                      onPressed: _working ? null : _restorePurchases,
                      child: Text(context.s('paywall.restore')),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Отмена-подсказка — bodySmall/textFaint
                  Text(
                    context.s('paywall.cancel_hint'),
                    style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
                    textAlign: TextAlign.center,
                  ),

                  // Dev tools — только в debug, с нейтральным разделителем
                  if (kDebugMode) ...[
                    const SizedBox(height: 24),
                    Divider(color: ext.border),
                    const SizedBox(height: 8),
                    Text(
                      'Dev tools',
                      style: textTheme.labelSmall?.copyWith(color: ext.textFaint),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _working ? null : _devActivate,
                      child: const Text('Activate Premium (dev only)'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _working ? null : _devDeactivate,
                      child: const Text('Downgrade to Free (dev only)'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
