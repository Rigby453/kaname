// Пользовательское соглашение и политика конфиденциальности.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(context.s('profile.terms_privacy')),
      ),
      body: ListView(
        // 24dp screen margin (02-type-space.md §4.1)
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
        children: [
          Text(context.s('profile.terms_title'), style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(
            context.s('profile.terms_body'),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          // Разделитель с правильным цветом border (03-components §18)
          Divider(color: ext.border),
          const SizedBox(height: 32),
          Text(context.s('profile.privacy_title'), style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(
            context.s('profile.privacy_body'),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          // Разделитель перед разделом о здоровье
          Divider(color: ext.border),
          const SizedBox(height: 32),
          Text(context.s('profile.health_disclaimer_title'), style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(
            context.s('profile.health_disclaimer_body'),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 48),
          // Tagline — textFaint (третичный, самый тихий)
          Text(
            context.s('profile.tagline'),
            style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
