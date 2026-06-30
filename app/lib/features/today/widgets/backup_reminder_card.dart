// G2: Напоминание о резервном копировании для гостей (офлайн-режим).
//
// Показывается тихой ЗАКРЫВАЕМОЙ карточкой вверху Today ТОЛЬКО для гостей
// (guest_mode=true, JWT-токена нет) при launchCount >= 3.
// После закрытия крестиком — не показывается повторно (prefs-флаг
// backup_reminder_dismissed).
// У пользователей с реальным аккаунтом (есть токен) НЕ показывается.
//
// Публичный API:
//   shouldShowBackupReminder({isGuest, launchCount, isDismissed}) → bool
//   showBackupReminderProvider    → Provider<bool>
//   backupReminderDismissedProvider → StateProvider<bool>
//   isGuestModeProvider           → Provider<bool>
//   BackupReminderCard()          → ConsumerWidget

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/settings/app_usage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../features/auth/auth_controller.dart';
import '../../../services/api/api_client.dart';

// ---------------------------------------------------------------------------
// Константы
// ---------------------------------------------------------------------------

/// Ключ SharedPreferences: пользователь закрыл напоминание → больше не показываем.
const String kBackupReminderDismissedKey = 'backup_reminder_dismissed';

/// Минимальное количество запусков до показа напоминания (3-й запуск).
const int kBackupReminderMinLaunchCount = 3;

// ---------------------------------------------------------------------------
// Чистая функция — политика показа (тестируема без Riverpod и Flutter)
// ---------------------------------------------------------------------------

/// Возвращает true, если нужно показать напоминание о резервном копировании.
///
/// Условия показа (все три должны выполняться):
///   - [isGuest] — пользователь в офлайн-режиме (нет JWT-токена).
///   - [launchCount] >= [kBackupReminderMinLaunchCount] — минимум 3 запуска.
///   - [isDismissed] == false — пользователь ещё не закрыл напоминание.
bool shouldShowBackupReminder({
  required bool isGuest,
  required int launchCount,
  required bool isDismissed,
}) =>
    isGuest && launchCount >= kBackupReminderMinLaunchCount && !isDismissed;

// ---------------------------------------------------------------------------
// Провайдеры
// ---------------------------------------------------------------------------

/// true если пользователь вошёл в офлайн-режим (guest_mode=true) без JWT-токена.
/// false при наличии аккаунта (токен есть) или при выходе из приложения.
final isGuestModeProvider = Provider<bool>((ref) {
  final isLoggedIn = ref.watch(authControllerProvider);
  if (!isLoggedIn) return false;
  final api = ref.watch(apiClientProvider);
  return api.token == null;
});

/// Флаг закрытия напоминания (StateProvider для реактивного скрытия карточки).
/// Инициализируется из SharedPreferences; обновляется при нажатии крестика.
final backupReminderDismissedProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(kBackupReminderDismissedKey) ?? false;
});

/// Объединённое условие показа карточки (для удобного watch в UI и тестах).
final showBackupReminderProvider = Provider<bool>((ref) {
  return shouldShowBackupReminder(
    isGuest: ref.watch(isGuestModeProvider),
    launchCount: ref.watch(appUsageProvider).launchCount,
    isDismissed: ref.watch(backupReminderDismissedProvider),
  );
});

// ---------------------------------------------------------------------------
// BackupReminderCard — публичный виджет
// ---------------------------------------------------------------------------

/// Тихая закрываемая карточка-напоминание о резервном копировании.
/// Возвращает [SizedBox.shrink()] если условия показа не выполнены.
class BackupReminderCard extends ConsumerWidget {
  const BackupReminderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showBackupReminderProvider)) {
      return const SizedBox.shrink();
    }

    return _BackupReminderContent(
      onDismiss: () async {
        // Сохраняем флаг в SharedPreferences и обновляем провайдер реактивно.
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.setBool(kBackupReminderDismissedKey, true);
        ref.read(backupReminderDismissedProvider.notifier).state = true;
      },
      onSignIn: () => context.go('/auth'),
    );
  }
}

// ---------------------------------------------------------------------------
// _BackupReminderContent — внутренний виджет (вынесен для тестируемости)
// ---------------------------------------------------------------------------

class _BackupReminderContent extends StatelessWidget {
  const _BackupReminderContent({
    required this.onDismiss,
    required this.onSignIn,
  });

  final VoidCallback onDismiss;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FocusThemeExtension>()!;
    final scheme = theme.colorScheme;

    // Нижний отступ отделяет карточку от _QuietHeader ниже.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ext.border, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Иконка «облако со стрелкой вверх»
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: PhosphorIcon(
                  PhosphorIcons.cloudArrowUp(PhosphorIconsStyle.regular),
                  size: 18,
                  color: ext.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              // Текст + кнопка «Войти» — Expanded предотвращает overflow
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.s('backup.reminder_title'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: ext.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.s('backup.reminder_text'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ext.textMuted,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Основное действие — войти / включить синхронизацию
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.primary,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onSignIn,
                      child: Text(
                        context.s('backup.sign_in'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        // Overflow-safe на 320px: ellipsis вместо wrap за кнопку
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    // TODO(G2): кнопка «Экспорт копии» через share_plus.
                    // Реализовать после появления метода getAllItems/getAllWaterLogs
                    // в DAO: собрать JSON из items+water+day_logs, записать во
                    // временный файл (path_provider) и вызвать Share.shareXFiles.
                  ],
                ),
              ),
              // Крестик — закрыть навсегда
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: context.s('backup.dismiss'),
                icon: PhosphorIcon(
                  PhosphorIcons.x(PhosphorIconsStyle.regular),
                  size: 16,
                  color: ext.textFaint,
                ),
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
