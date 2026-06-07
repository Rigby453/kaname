// Экран профиля (не таб). Показывает статус аккаунта и кнопку выхода/входа.
// При выходе routerProvider уводит на /auth.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../services/api/api_client.dart';
import '../auth/auth_controller.dart';

/// Данные текущего пользователя (или null, если офлайн-режим / не вошёл).
final currentUserProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth) return null;
  final api = ref.read(apiClientProvider);
  if (api.token == null) return null; // офлайн-режим
  try {
    return await api.me();
  } on ApiException {
    return null;
  }
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final userAsync = ref.watch(currentUserProvider);
    final isAuthenticated =
        ref.read(authControllerProvider.notifier).isAuthenticated;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            userAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const SizedBox.shrink(),
              data: (user) {
                if (user == null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Offline mode', style: textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Your tasks are stored on this device only. '
                        'Sign in to sync across devices.',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (user['name'] as String?) ?? 'You',
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (user['email'] as String?) ?? '',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            Text('Appearance', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            const _ThemePicker(),
            const Spacer(),
            FilledButton(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).logout();
              },
              child: Text(isAuthenticated ? 'Sign out' : 'Sign in / Sign up'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Выбор темы оформления. Реализованы focus / black / white;
/// calm и contrast пока недоступны (заглушки).
class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  static const _available = [
    (AppThemeKey.focus, 'Focus'),
    (AppThemeKey.calm, 'Calm'),
    (AppThemeKey.black, 'Black'),
    (AppThemeKey.white, 'White'),
    (AppThemeKey.contrast, 'Contrast'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeNotifierProvider);
    return Wrap(
      spacing: 8,
      children: _available.map((entry) {
        final (key, label) = entry;
        return ChoiceChip(
          label: Text(label),
          selected: current == key,
          onSelected: (_) =>
              ref.read(themeNotifierProvider.notifier).setTheme(key),
        );
      }).toList(),
    );
  }
}
