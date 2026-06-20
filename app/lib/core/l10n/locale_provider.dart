import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/theme_provider.dart';

const _kLocaleKey = 'app_locale';

final localeNotifierProvider =
    NotifierProvider<LocaleNotifier, Locale>(() => LocaleNotifier());

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(_kLocaleKey);
    if (saved == null) return const Locale('en');
    // Полный тег вида 'pt-BR', 'es-ES', или просто 'en'
    final parts = saved.split('-');
    if (parts.length >= 2) {
      return Locale(parts[0], parts[1]);
    }
    return Locale(parts[0]);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    // Сохраняем полный тег: 'pt-BR', 'es-ES', 'en', 'ru' и т.д.
    final tag = locale.countryCode != null && locale.countryCode!.isNotEmpty
        ? '${locale.languageCode}-${locale.countryCode}'
        : locale.languageCode;
    await prefs.setString(_kLocaleKey, tag);
  }
}

/// Упорядоченный список всех поддерживаемых локалей приложения.
const supportedLocales = [
  Locale('en'),
  Locale('ru'),
  Locale('de'),
  Locale('fr'),
  Locale('it'),
  Locale('pt', 'BR'),
  Locale('id'),
  Locale('hi'),
  Locale('ja'),
  Locale('ko'),
  Locale('es'),
  Locale('es', 'ES'),
];

/// Упорядоченный список {locale, displayName} для пикеров UI.
/// Используем List, а не Map, чтобы поддерживать два варианта 'es' как отдельные пункты.
class LocaleEntry {
  const LocaleEntry(this.locale, this.displayName);
  final Locale locale;
  final String displayName;
}

const List<LocaleEntry> localeEntries = [
  LocaleEntry(Locale('en'), 'English'),
  LocaleEntry(Locale('ru'), 'Русский'),
  LocaleEntry(Locale('de'), 'Deutsch'),
  LocaleEntry(Locale('fr'), 'Français'),
  LocaleEntry(Locale('it'), 'Italiano'),
  LocaleEntry(Locale('pt', 'BR'), 'Português (Brasil)'),
  LocaleEntry(Locale('id'), 'Bahasa Indonesia'),
  LocaleEntry(Locale('hi'), 'हिन्दी'),
  LocaleEntry(Locale('ja'), '日本語'),
  LocaleEntry(Locale('ko'), '한국어'),
  LocaleEntry(Locale('es'), 'Español (Latinoamérica)'),
  LocaleEntry(Locale('es', 'ES'), 'Español (España)'),
];

/// Канонический тег для Locale: 'pt-BR', 'es-ES', 'en', 'ru' и т.д.
String localeTag(Locale locale) {
  if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
    return '${locale.languageCode}-${locale.countryCode}';
  }
  return locale.languageCode;
}

