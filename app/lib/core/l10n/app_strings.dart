import 'package:flutter/material.dart';

class S {
  S._();

  static const _en = <String, String>{
    // Навигация
    'nav.today': 'Today',
    'nav.plan': 'Plan',
    'nav.health': 'Health',
    'nav.diary': 'Diary',
    // Общие кнопки
    'btn.save': 'Save',
    'btn.cancel': 'Cancel',
    'btn.add': 'Add',
    'btn.delete': 'Delete',
    'btn.done': 'Done',
    'btn.skip': 'Skip',
    'btn.back': 'Back',
    'btn.close': 'Close',
    'btn.sign_out': 'Sign out',
    'btn.sign_in': 'Sign in / Sign up',
    // Today
    'today.greeting_morning': 'Good morning',
    'today.greeting_afternoon': 'Good afternoon',
    'today.greeting_evening': 'Good evening',
    'today.add_food': 'Add food',
    'today.main_tasks': 'Main today',
    'today.later': 'Later today',
    // Профиль
    'profile.title': 'Profile',
    'profile.language': 'Language',
    'profile.theme': 'Theme',
    'profile.notifications': 'Daily reminders',
    'profile.text_size': 'Text size',
    'profile.tone': 'Tone',
    // Health
    'health.title': 'Health',
    'health.water': 'Water',
    'health.sleep': 'Sleep',
    'health.food': 'Food',
    'health.workouts': 'Workouts',
    'health.breathing': 'Breathing',
    'health.posture': 'Posture',
    // Diary
    'diary.title': 'How was today?',
    'diary.mood': 'Mood',
    'diary.note': 'Note',
    'diary.save_day': 'Save day',
    'diary.history': 'View History',
    // Plan
    'plan.title': 'Plan',
    // Еда
    'food.add': 'Add food',
    'food.search_hint': 'Search a product…',
    'food.nothing_today': 'Nothing logged today.\nTap "Add food" to search a product.',
    // Стрики
    'streak.freeze': 'Freeze streak',
    // Настройки
    'settings.gentle': 'Gentle',
    'settings.harsh': 'Harsh',
  };

  static const _ru = <String, String>{
    'nav.today': 'Сегодня',
    'nav.plan': 'План',
    'nav.health': 'Здоровье',
    'nav.diary': 'Дневник',
    'btn.save': 'Сохранить',
    'btn.cancel': 'Отмена',
    'btn.add': 'Добавить',
    'btn.delete': 'Удалить',
    'btn.done': 'Готово',
    'btn.skip': 'Пропустить',
    'btn.back': 'Назад',
    'btn.close': 'Закрыть',
    'btn.sign_out': 'Выйти',
    'btn.sign_in': 'Войти / Зарегистрироваться',
    'today.greeting_morning': 'Доброе утро',
    'today.greeting_afternoon': 'Добрый день',
    'today.greeting_evening': 'Добрый вечер',
    'today.add_food': 'Добавить еду',
    'today.main_tasks': 'Главное сегодня',
    'today.later': 'Позже сегодня',
    'profile.title': 'Профиль',
    'profile.language': 'Язык',
    'profile.theme': 'Тема',
    'profile.notifications': 'Ежедневные напоминания',
    'profile.text_size': 'Размер текста',
    'profile.tone': 'Тон',
    'health.title': 'Здоровье',
    'health.water': 'Вода',
    'health.sleep': 'Сон',
    'health.food': 'Питание',
    'health.workouts': 'Тренировки',
    'health.breathing': 'Дыхание',
    'health.posture': 'Осанка',
    'diary.title': 'Как прошёл день?',
    'diary.mood': 'Настроение',
    'diary.note': 'Заметка',
    'diary.save_day': 'Сохранить день',
    'diary.history': 'История',
    'plan.title': 'План',
    'food.add': 'Добавить еду',
    'food.search_hint': 'Найти продукт…',
    'food.nothing_today': 'Ничего не добавлено.\nНажми «Добавить еду» для поиска.',
    'streak.freeze': 'Заморозить стрик',
    'settings.gentle': 'Мягкий',
    'settings.harsh': 'Строгий',
  };

  static const _de = <String, String>{
    'nav.today': 'Heute',
    'nav.plan': 'Plan',
    'nav.health': 'Gesundheit',
    'nav.diary': 'Tagebuch',
    'btn.save': 'Speichern',
    'btn.cancel': 'Abbrechen',
    'btn.add': 'Hinzufügen',
    'btn.delete': 'Löschen',
    'btn.done': 'Fertig',
    'btn.skip': 'Überspringen',
    'btn.back': 'Zurück',
    'btn.close': 'Schließen',
    'btn.sign_out': 'Abmelden',
    'btn.sign_in': 'Anmelden / Registrieren',
    'today.greeting_morning': 'Guten Morgen',
    'today.greeting_afternoon': 'Guten Tag',
    'today.greeting_evening': 'Guten Abend',
    'today.add_food': 'Essen hinzufügen',
    'today.main_tasks': 'Hauptaufgaben heute',
    'today.later': 'Später heute',
    'profile.title': 'Profil',
    'profile.language': 'Sprache',
    'profile.theme': 'Thema',
    'profile.notifications': 'Tägliche Erinnerungen',
    'profile.text_size': 'Textgröße',
    'profile.tone': 'Ton',
    'health.title': 'Gesundheit',
    'health.water': 'Wasser',
    'health.sleep': 'Schlaf',
    'health.food': 'Ernährung',
    'health.workouts': 'Training',
    'health.breathing': 'Atemübungen',
    'health.posture': 'Haltung',
    'diary.title': 'Wie war dein Tag?',
    'diary.mood': 'Stimmung',
    'diary.note': 'Notiz',
    'diary.save_day': 'Tag speichern',
    'diary.history': 'Verlauf',
    'plan.title': 'Plan',
    'food.add': 'Essen hinzufügen',
    'food.search_hint': 'Produkt suchen…',
    'food.nothing_today': 'Noch nichts eingetragen.\nTippe auf „Essen hinzufügen".',
    'streak.freeze': 'Streak einfrieren',
    'settings.gentle': 'Sanft',
    'settings.harsh': 'Streng',
  };

  static final _tables = {'en': _en, 'ru': _ru, 'de': _de};

  static String of(BuildContext context, String key) {
    final lang = Localizations.localeOf(context).languageCode;
    return _tables[lang]?[key] ?? _en[key] ?? key;
  }
}

/// Удобное расширение: context.s('key')
extension SContext on BuildContext {
  String s(String key) => S.of(this, key);
}
