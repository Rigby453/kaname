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
    return saved != null ? Locale(saved) : const Locale('en');
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }
}

const supportedLocales = [
  Locale('en'),
  Locale('ru'),
  Locale('de'),
];

const localeNames = {
  'en': 'English',
  'ru': 'Русский',
  'de': 'Deutsch',
};
