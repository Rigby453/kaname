// Пользовательское соглашение и политика конфиденциальности.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Terms & Privacy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Terms of Service', style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(
            'Last updated: June 2026\n\n'
            'By using Kaizen ("the app"), you agree to these terms. '
            'Kaizen is a personal productivity tool for students.\n\n'
            '1. Use the app for lawful purposes only.\n'
            '2. You are responsible for keeping your account credentials secure.\n'
            '3. We may update the app and these terms at any time.\n'
            '4. The app is provided "as is" without warranties of any kind.\n'
            '5. Subscription fees are non-refundable except as required by law.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Divider(color: colorScheme.outline.withValues(alpha: 0.3)),
          const SizedBox(height: 32),
          Text('Privacy Policy', style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(
            'Last updated: June 2026\n\n'
            'We take your privacy seriously.\n\n'
            'What we collect:\n'
            '• Account info (email, name) — to identify your account.\n'
            '• Tasks, diary entries, health logs — synced to provide the service.\n'
            '• Usage data (anonymous) — to improve the app.\n\n'
            'What we don\'t do:\n'
            '• We do not sell your data to third parties.\n'
            '• We do not show ads to Premium users.\n'
            '• We do not share personal data with advertisers.\n\n'
            'AI features (Premium):\n'
            'When you use AI features, your tasks and diary summaries are sent to '
            'our AI provider (Google Gemini or Anthropic Claude) to generate responses. '
            'This data is not used to train their models per our agreements.\n\n'
            'Data storage:\n'
            'Your data is stored on servers in the EU/US. '
            'You can delete your account and all data at any time by contacting support@kaizen.app.\n\n'
            'Contact: support@kaizen.app',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 48),
          Text(
            'Kaizen — the important stuff won\'t slip.',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
