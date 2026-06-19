// Строки нового 16-экранного онбординга (quiz-style flow).
// Ключ-формат: 'onboarding_quiz.<screen_id>.<element>'.
// Локали: en, ru, de.
const Map<String, Map<String, String>> onboardingQuizStrings = {
  // ---------------------------------------------------------------------------
  // Экраны 1–3: приветствие / проблема / решение (информационные)
  // ---------------------------------------------------------------------------
  'onboarding_quiz.s1_title': {
    'en': 'Do what matters.',
    'ru': 'Делай главное.',
    'de': 'Tu das Wichtige.',
  },
  'onboarding_quiz.s1_subtitle': {
    'en': 'A planner that rebuilds your day for you.',
    'ru': 'Планер, который сам пересобирает твой день.',
    'de': 'Ein Planer, der deinen Tag selbst neu aufbaut.',
  },
  'onboarding_quiz.s1_cta': {
    'en': 'Get started',
    'ru': 'Начать',
    'de': 'Loslegen',
  },

  'onboarding_quiz.s2_title': {
    'en': 'Everything feels like it crumbles.',
    'ru': 'В голове всё рушится.',
    'de': 'Alles fühlt sich chaotisch an.',
  },
  'onboarding_quiz.s2_body': {
    'en':
        'Tasks pile up, deadlines sneak up, and the day slips away before you\'ve done what truly mattered.',
    'ru':
        'Задачи копятся, дедлайны подкрадываются, и день заканчивается, прежде чем ты успел сделать главное.',
    'de':
        'Aufgaben häufen sich, Fristen schleichen heran, und der Tag ist vorbei, bevor du das Wichtigste erledigt hast.',
  },
  'onboarding_quiz.s2_cta': {
    'en': 'I feel this',
    'ru': 'Знакомо',
    'de': 'Das kenne ich',
  },

  'onboarding_quiz.s3_title': {
    'en': 'It will adjust to you.',
    'ru': 'Подстроится под тебя.',
    'de': 'Es passt sich dir an.',
  },
  'onboarding_quiz.s3_bullet1': {
    'en': 'Rebuilds your day around what matters',
    'ru': 'Пересоберёт день вокруг важного',
    'de': 'Baut deinen Tag rund um das Wichtige neu auf',
  },
  'onboarding_quiz.s3_bullet2': {
    'en': 'Reminds you to drink water',
    'ru': 'Напомнит выпить воду',
    'de': 'Erinnert dich ans Trinken',
  },
  'onboarding_quiz.s3_bullet3': {
    'en': 'Warns before deadlines slip',
    'ru': 'Предупредит о дедлайне заранее',
    'de': 'Warnt, bevor Fristen verfallen',
  },
  'onboarding_quiz.s3_cta': {
    'en': 'Sounds good',
    'ru': 'Звучит хорошо',
    'de': 'Klingt gut',
  },

  // ---------------------------------------------------------------------------
  // Экран 4: язык (без skip)
  // ---------------------------------------------------------------------------
  'onboarding_quiz.s4_title': {
    'en': 'What language do we work in?',
    'ru': 'На каком языке работаем?',
    'de': 'In welcher Sprache arbeiten wir?',
  },
  'onboarding_quiz.s4_cta': {
    'en': 'Continue',
    'ru': 'Продолжить',
    'de': 'Fortfahren',
  },

  // ---------------------------------------------------------------------------
  // Экран 5: цели (multiselect)
  // ---------------------------------------------------------------------------
  'onboarding_quiz.s5_title': {
    'en': 'What do you want to achieve?',
    'ru': 'Чего хочешь добиться?',
    'de': 'Was möchtest du erreichen?',
  },
  'onboarding_quiz.s5_subtitle': {
    'en': 'Choose one or several. This will shape your experience.',
    'ru': 'Выбери одно или несколько. Это настроит опыт под тебя.',
    'de': 'Wähle eines oder mehrere. Das prägt deine Erfahrung.',
  },
  'onboarding_quiz.goal_study': {
    'en': 'Keep up with studies',
    'ru': 'Успевать с учёбой',
    'de': 'Mit dem Studium Schritt halten',
  },
  'onboarding_quiz.goal_procrastination': {
    'en': 'Stop procrastinating',
    'ru': 'Перестать прокрастинировать',
    'de': 'Prokrastination überwinden',
  },
  'onboarding_quiz.goal_routine': {
    'en': 'Build a healthy routine',
    'ru': 'Наладить режим',
    'de': 'Gesunde Routine aufbauen',
  },
  'onboarding_quiz.goal_free_time': {
    'en': 'Have more free time',
    'ru': 'Больше свободного времени',
    'de': 'Mehr Freizeit haben',
  },
  'onboarding_quiz.goal_exams': {
    'en': 'Prepare for exams',
    'ru': 'Подготовиться к экзаменам',
    'de': 'Auf Prüfungen vorbereiten',
  },
  'onboarding_quiz.s5_skip': {
    'en': 'Fill in later',
    'ru': 'Заполнить позже',
    'de': 'Später ausfüllen',
  },
  'onboarding_quiz.s5_cta': {
    'en': 'Continue',
    'ru': 'Продолжить',
    'de': 'Fortfahren',
  },

  // ---------------------------------------------------------------------------
  // Экран 6: время на планирование
  // ---------------------------------------------------------------------------
  'onboarding_quiz.s6_title': {
    'en': 'How much time do you spend planning now?',
    'ru': 'Сколько времени уходит на планирование сейчас?',
    'de': 'Wie viel Zeit verbringst du jetzt mit Planen?',
  },
  'onboarding_quiz.s6_subtitle': {
    'en': 'Per day on average.',
    'ru': 'В среднем за день.',
    'de': 'Im Durchschnitt pro Tag.',
  },
  'onboarding_quiz.plan_none': {
    'en': 'Barely plan',
    'ru': 'Почти не планирую',
    'de': 'Kaum Planung',
  },
  'onboarding_quiz.plan_10': {
    'en': '~10 min',
    'ru': '~10 мин',
    'de': '~10 Min.',
  },
  'onboarding_quiz.plan_30': {
    'en': '~30 min',
    'ru': '~30 мин',
    'de': '~30 Min.',
  },
  'onboarding_quiz.plan_more': {
    'en': 'More than 30 min',
    'ru': 'Больше 30 мин',
    'de': 'Mehr als 30 Min.',
  },
  'onboarding_quiz.s6_skip': {
    'en': 'Fill in later',
    'ru': 'Заполнить позже',
    'de': 'Später ausfüllen',
  },
  'onboarding_quiz.s6_cta': {
    'en': 'Continue',
    'ru': 'Продолжить',
    'de': 'Fortfahren',
  },

  // ---------------------------------------------------------------------------
  // Экран 7: горизонт планирования
  // ---------------------------------------------------------------------------
  'onboarding_quiz.s7_title': {
    'en': 'How far ahead do you usually plan?',
    'ru': 'На сколько вперёд планируешь?',
    'de': 'Wie weit planst du in der Regel voraus?',
  },
  'onboarding_quiz.horizon_day': {
    'en': 'Just today',
    'ru': 'День',
    'de': 'Heute',
  },
  'onboarding_quiz.horizon_week': {
    'en': 'The week',
    'ru': 'Неделя',
    'de': 'Die Woche',
  },
  'onboarding_quiz.horizon_months': {
    'en': 'Months ahead',
    'ru': 'Месяцы',
    'de': 'Monate voraus',
  },
  'onboarding_quiz.horizon_years': {
    'en': 'Years ahead',
    'ru': 'Годы',
    'de': 'Jahre voraus',
  },
  'onboarding_quiz.s7_skip': {
    'en': 'Fill in later',
    'ru': 'Заполнить позже',
    'de': 'Später ausfüllen',
  },
  'onboarding_quiz.s7_cta': {
    'en': 'Continue',
    'ru': 'Продолжить',
    'de': 'Fortfahren',
  },

  // ---------------------------------------------------------------------------
  // Экран 8: проекция (честная, derived)
  // ---------------------------------------------------------------------------
  'onboarding_quiz.s8_title_prefix': {
    'en': 'About',
    'ru': 'Примерно',
    'de': 'Etwa',
  },
  'onboarding_quiz.s8_title_suffix': {
    'en': 'hours a year go to manual planning.',
    'ru': 'часов в год уходит на ручное планирование.',
    'de': 'Stunden pro Jahr gehen in manuelle Planung.',
  },
  'onboarding_quiz.s8_body': {
    'en': 'At your current pace — a rough estimate. We can make that time actually count.',
    'ru':
        'При текущем темпе — примерная оценка. Мы можем сделать это время по-настоящему продуктивным.',
    'de':
        'Bei deinem aktuellen Tempo — eine grobe Schätzung. Wir können diese Zeit sinnvoll nutzen.',
  },
  'onboarding_quiz.s8_cta': {
    'en': 'I want that',
    'ru': 'Хочу так',
    'de': 'Das will ich',
  },

  // ---------------------------------------------------------------------------
  // Экраны 9–11: параметры тела
  // ---------------------------------------------------------------------------
  'onboarding_quiz.s9_title': {
    'en': 'A bit about you',
    'ru': 'Немного о тебе',
    'de': 'Ein bisschen über dich',
  },
  'onboarding_quiz.s9_subtitle': {
    'en': "We'll use this to personalise your water and nutrition goals.",
    'ru': 'Используем для подбора нормы воды и питания.',
    'de': 'Damit personalisieren wir deine Wasser- und Ernährungsziele.',
  },
  'onboarding_quiz.s9_skip': {
    'en': 'Fill in later',
    'ru': 'Заполнить позже',
    'de': 'Später ausfüllen',
  },
  'onboarding_quiz.s9_cta': {
    'en': 'Continue',
    'ru': 'Продолжить',
    'de': 'Fortfahren',
  },

  'onboarding_quiz.s10_title': {
    'en': 'Height & weight',
    'ru': 'Рост и вес',
    'de': 'Größe und Gewicht',
  },
  'onboarding_quiz.s10_subtitle': {
    'en': 'For water and calorie targets.',
    'ru': 'Для нормы воды и калорий.',
    'de': 'Für Wasser- und Kalorienziele.',
  },
  'onboarding_quiz.s10_skip': {
    'en': 'Fill in later',
    'ru': 'Заполнить позже',
    'de': 'Später ausfüllen',
  },
  'onboarding_quiz.s10_cta': {
    'en': 'Continue',
    'ru': 'Продолжить',
    'de': 'Fortfahren',
  },

  'onboarding_quiz.s11_title': {
    'en': 'Activity level',
    'ru': 'Уровень активности',
    'de': 'Aktivitätslevel',
  },
  'onboarding_quiz.s11_subtitle': {
    'en': 'This adjusts your daily water and calorie needs.',
    'ru': 'Влияет на норму воды и калорий.',
    'de': 'Passt deinen täglichen Wasser- und Kalorienbedarf an.',
  },
  'onboarding_quiz.activity_low_label': {
    'en': 'Low',
    'ru': 'Низкий',
    'de': 'Niedrig',
  },
  'onboarding_quiz.activity_low_sub': {
    'en': 'Mostly sitting, little movement',
    'ru': 'В основном сижу, мало двигаюсь',
    'de': 'Meistens sitzend, wenig Bewegung',
  },
  'onboarding_quiz.activity_medium_label': {
    'en': 'Medium',
    'ru': 'Средний',
    'de': 'Mittel',
  },
  'onboarding_quiz.activity_medium_sub': {
    'en': 'Walking, light exercise a few times a week',
    'ru': 'Хожу пешком, лёгкая нагрузка несколько раз в неделю',
    'de': 'Spazieren, leichtes Training ein paar Mal pro Woche',
  },
  'onboarding_quiz.activity_high_label': {
    'en': 'High',
    'ru': 'Высокий',
    'de': 'Hoch',
  },
  'onboarding_quiz.activity_high_sub': {
    'en': 'Regular workouts or physical work',
    'ru': 'Регулярные тренировки или физический труд',
    'de': 'Regelmäßiges Training oder körperliche Arbeit',
  },
  'onboarding_quiz.s11_skip': {
    'en': 'Fill in later',
    'ru': 'Заполнить позже',
    'de': 'Später ausfüllen',
  },
  'onboarding_quiz.s11_cta': {
    'en': 'Continue',
    'ru': 'Продолжить',
    'de': 'Fortfahren',
  },

  // ---------------------------------------------------------------------------
  // Экран 12: первая задача (без skip)
  // ---------------------------------------------------------------------------
  'onboarding_quiz.s12_title': {
    'en': 'Add your first task.',
    'ru': 'Добавь первую задачу.',
    'de': 'Füge deine erste Aufgabe hinzu.',
  },
  'onboarding_quiz.s12_subtitle': {
    'en': "What's the one thing you must do today?",
    'ru': 'Что обязательно нужно сделать сегодня?',
    'de': 'Was ist die eine Sache, die du heute tun musst?',
  },
  'onboarding_quiz.s12_hint': {
    'en': 'e.g. Submit assignment, Call mom…',
    'ru': 'Сдать задание, Позвонить маме…',
    'de': 'z.B. Aufgabe einreichen, Mutter anrufen…',
  },
  'onboarding_quiz.s12_cta': {
    'en': 'Add task',
    'ru': 'Добавить задачу',
    'de': 'Aufgabe hinzufügen',
  },
  'onboarding_quiz.s12_err_empty': {
    'en': 'Please type something',
    'ru': 'Напиши что-нибудь',
    'de': 'Bitte etwas eingeben',
  },
  'onboarding_quiz.s12_kai_line': {
    'en': "Let's do it.",
    'ru': 'Давай сделаем это.',
    'de': 'Lass es uns anpacken.',
  },

  // ---------------------------------------------------------------------------
  // Экран 13: демо переноса (без прогресс-индикатора)
  // ---------------------------------------------------------------------------
  'onboarding_quiz.s13_title': {
    'en': 'Done. Now — the key part.',
    'ru': 'Готово. А теперь — главное.',
    'de': 'Fertig. Und jetzt der entscheidende Teil.',
  },
  'onboarding_quiz.s13_question': {
    'en': "What if you don't make it in time?",
    'ru': 'А если не успеешь?',
    'de': 'Was, wenn du es nicht rechtzeitig schaffst?',
  },
  'onboarding_quiz.s13_move_btn': {
    'en': 'Reschedule',
    'ru': 'Перенести',
    'de': 'Verschieben',
  },
  'onboarding_quiz.s13_task_moved': {
    'en': 'Moved to top of tomorrow',
    'ru': 'Перенесено наверх завтра',
    'de': 'An die Spitze von morgen verschoben',
  },
  'onboarding_quiz.s13_kai_line': {
    'en': "I rebuild the day around what matters and explain what went wrong.",
    'ru': 'Я пересоберу день вокруг важного и скажу, почему сорвалось.',
    'de': 'Ich baue den Tag rund um das Wichtige neu auf und erkläre, was schiefgelaufen ist.',
  },
  'onboarding_quiz.s13_cta': {
    'en': 'Got it',
    'ru': 'Понятно',
    'de': 'Verstanden',
  },

  // ---------------------------------------------------------------------------
  // Экран 14: время разборов
  // ---------------------------------------------------------------------------
  'onboarding_quiz.s14_title': {
    'en': 'When is it convenient to plan?',
    'ru': 'Когда тебе удобно планировать?',
    'de': 'Wann ist es für dich bequem zu planen?',
  },
  'onboarding_quiz.s14_subtitle': {
    'en': "We'll send reminders at these times.",
    'ru': 'Мы пришлём напоминания в это время.',
    'de': 'Wir senden Erinnerungen zu diesen Zeiten.',
  },
  'onboarding_quiz.timing_morning': {
    'en': 'In the morning',
    'ru': 'Утром',
    'de': 'Morgens',
  },
  'onboarding_quiz.timing_afternoon': {
    'en': 'In the afternoon',
    'ru': 'Днём',
    'de': 'Mittags',
  },
  'onboarding_quiz.timing_evening': {
    'en': 'In the evening',
    'ru': 'Вечером',
    'de': 'Abends',
  },
  'onboarding_quiz.timing_both': {
    'en': 'Morning and evening',
    'ru': 'Утром и вечером',
    'de': 'Morgens und abends',
  },
  'onboarding_quiz.s14_skip': {
    'en': 'Fill in later',
    'ru': 'Заполнить позже',
    'de': 'Später ausfüllen',
  },
  'onboarding_quiz.s14_cta': {
    'en': 'Continue',
    'ru': 'Продолжить',
    'de': 'Fortfahren',
  },

  // ---------------------------------------------------------------------------
  // Экран 15: итоговый саммари
  // ---------------------------------------------------------------------------
  'onboarding_quiz.s15_title': {
    'en': 'Your Glavnoe is ready.',
    'ru': 'Твоё Главное готово.',
    'de': 'Dein Główne ist bereit.',
  },
  'onboarding_quiz.s15_lang_label': {
    'en': 'Language',
    'ru': 'Язык',
    'de': 'Sprache',
  },
  'onboarding_quiz.s15_goal_label': {
    'en': 'Main goal',
    'ru': 'Главная цель',
    'de': 'Hauptziel',
  },
  'onboarding_quiz.s15_water_label': {
    'en': 'Water goal',
    'ru': 'Норма воды',
    'de': 'Wasserziel',
  },
  'onboarding_quiz.s15_water_value': {
    'en': '~{n} ml / day',
    'ru': '~{n} мл / день',
    'de': '~{n} ml / Tag',
  },
  'onboarding_quiz.s15_cal_label': {
    'en': 'Calories',
    'ru': 'Калории',
    'de': 'Kalorien',
  },
  'onboarding_quiz.s15_cal_value': {
    'en': '~{n} kcal / day',
    'ru': '~{n} ккал / день',
    'de': '~{n} kcal / Tag',
  },
  'onboarding_quiz.s15_timing_label': {
    'en': 'Review time',
    'ru': 'Время разбора',
    'de': 'Überprüfungszeit',
  },
  'onboarding_quiz.s15_no_goal': {
    'en': 'Not set',
    'ru': 'Не указано',
    'de': 'Nicht gesetzt',
  },
  'onboarding_quiz.s15_cta': {
    'en': "Let's go",
    'ru': 'Поехали',
    'de': 'Los geht\'s',
  },

  // ---------------------------------------------------------------------------
  // Экран 16: paywall (title / cta — на случай навигации)
  // ---------------------------------------------------------------------------
  'onboarding_quiz.s16_skip': {
    'en': 'Continue for free',
    'ru': 'Продолжить бесплатно',
    'de': 'Kostenlos fortfahren',
  },

  // ---------------------------------------------------------------------------
  // Общие
  // ---------------------------------------------------------------------------
  'onboarding_quiz.back': {
    'en': 'Back',
    'ru': 'Назад',
    'de': 'Zurück',
  },
  'onboarding_quiz.progress': {
    'en': '{cur}/{total}',
    'ru': '{cur}/{total}',
    'de': '{cur}/{total}',
  },
};
