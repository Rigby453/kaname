// Экран подписки / пейволл (SPEC: $10/мес, premium открывает AI).
// Реальные платежи (RevenueCat) — Phase 1; пока кнопка Subscribe — заглушка.
// В debug-сборке есть «Dev: unlock premium» → /subscription/dev-upgrade,
// чтобы протестировать AI-фичи (нужен ANTHROPIC_API_KEY на бэкенде).

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/api/api_client.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_screen.dart' show currentUserProvider;

const List<({IconData icon, String title, String subtitle})> _benefits = [
  (
    icon: Icons.auto_awesome,
    title: 'Smarter plans',
    subtitle: 'AI rebuilds your day around what matters — morning & evening.',
  ),
  (
    icon: Icons.bolt,
    title: 'Tone-aware nudges',
    subtitle: 'Gentle or harsh — AI messages that actually land.',
  ),
  (
    icon: Icons.insights,
    title: 'Deeper diary insights',
    subtitle: 'Understand why plans slip, beyond the free weekly summary.',
  ),
  (
    icon: Icons.photo_camera_outlined,
    title: 'Photo schedule import',
    subtitle: 'Snap your timetable — AI turns it into tasks.',
  ),
  (
    icon: Icons.block,
    title: 'No ads',
    subtitle: 'Calm, focused, ad-free.',
  ),
];

/// Показывает апселл-снэкбар с действием «Upgrade» → пейволл.
/// Вызывается там, где упёрлись в premium-гейт (AI-фичи).
void showPremiumUpsell(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Premium feature — upgrade for $feature'),
      action: SnackBarAction(
        label: 'Upgrade',
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
    // Реальные платежи появятся в Phase 1.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Subscriptions launch soon — payments are coming in the next update.'),
      ),
    );
  }

  Future<void> _devUnlock() async {
    setState(() => _working = true);
    try {
      await ref.read(apiClientProvider).devUpgrade(tier: 'premium');
      // Обновляем premium-статус и данные пользователя в UI.
      ref.invalidate(isPremiumProvider);
      ref.invalidate(currentUserProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium unlocked (dev). AI features are on.')),
      );
      context.pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isAuthed = ref.read(authControllerProvider.notifier).isAuthenticated;

    return Scaffold(
      appBar: AppBar(title: const Text('Kaizen Premium')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Text('Unlock the AI', style: textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'The important stuff, planned for you.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ..._benefits.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(b.icon, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.title, style: textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(b.subtitle, style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: colorScheme.primary.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('\$10', style: textTheme.headlineMedium),
                    Text(' / month', style: textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!isAuthed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Sign in to subscribe and sync premium across devices.',
                  style: textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _working ? null : _subscribe,
                child: const Text('Subscribe'),
              ),
            ),
            // Dev-разблокировка только в debug-сборке и при наличии аккаунта.
            if (kDebugMode && isAuthed) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: _working
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open, size: 18),
                  label: const Text('Dev: unlock premium'),
                  onPressed: _working ? null : _devUnlock,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Cancel anytime. Free tier keeps tasks, streaks, rule-based plans, '
              'water & diary.',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
