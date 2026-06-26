// Вспомогательная функция автоматического определения moduleLink по заголовку задачи.
//
// Значения, совпадающие с картой роутинга в task_list.dart, day_timeline.dart,
// week_agenda.dart:
//   'workout'        → /workouts
//   'meal:breakfast' → /food?meal=breakfast
//   'meal:lunch'     → /food?meal=lunch
//   'meal:dinner'    → /food?meal=dinner
//   'sleep'          → /sleep-report
//   'focus'          → /focus
//   'warmup'         → /warmup
//   'breathing'      → /breathing
//   'meditation'     → /meditation
//   null             → нет привязки
//
// ИСТОЧНИК ИСТИНЫ: [kModuleInferenceKeywords] — публичная карта ключевых слов.
// nl_datetime.dart::_moduleKeywords ДОЛЖНА реиспользовать ту же карту через импорт.
// При добавлении новых ключевых слов правьте ТОЛЬКО kModuleInferenceKeywords здесь.
//
// Расширение: добавить кортеж в kModuleInferenceKeywords и соответствующий тест.

/// Описание одного ключевого слова модуля.
///
/// Используется как в [inferModuleLink] (запись в БД), так и в
/// nl_datetime.dart::_detectModuleLink (подсказки парсера).
class ModuleInferenceKey {
  const ModuleInferenceKey(this.text, {this.wholeWord = false});

  /// Корень-стем или целое слово (нижний регистр).
  final String text;

  /// true → совпадает только как целое слово (границы с обеих сторон);
  /// false → корень-префикс (левая граница + начало слова, правая не нужна).
  final bool wholeWord;
}

// Проверяем, является ли символ границей слова (пробел, пунктуация, начало строки).
bool _isBoundary(String ch) {
  final code = ch.codeUnitAt(0);
  // ASCII: не буква и не цифра → граница.
  if (code < 128) return !((code >= 65 && code <= 90) || (code >= 97 && code <= 122) || (code >= 48 && code <= 57));
  // Кириллица: буквы «А»–«я» + «Ё»/«ё».
  final isCyr = (code >= 0x0410 && code <= 0x044F) || code == 0x0401 || code == 0x0451;
  return !isCyr;
}

// Стем: ищем вхождение, у которого перед ним — граница слова (начало строки или _isBoundary).
bool _hasStem(String lower, String stem) {
  var from = 0;
  while (true) {
    final idx = lower.indexOf(stem, from);
    if (idx < 0) return false;
    final leftOk = idx == 0 || _isBoundary(lower[idx - 1]);
    if (leftOk) return true;
    from = idx + 1;
  }
}

// Целое слово: стем + граница СПРАВА.
bool _hasWord(String lower, String word) {
  var from = 0;
  while (true) {
    final idx = lower.indexOf(word, from);
    if (idx < 0) return false;
    final leftOk = idx == 0 || _isBoundary(lower[idx - 1]);
    final end = idx + word.length;
    final rightOk = end >= lower.length || _isBoundary(lower[end]);
    if (leftOk && rightOk) return true;
    from = idx + 1;
  }
}

bool _matchKey(String lower, ModuleInferenceKey k) =>
    k.wholeWord ? _hasWord(lower, k.text) : _hasStem(lower, k.text);

/// ЕДИНАЯ карта ключевые-слова → moduleLink. ИСТОЧНИК ИСТИНЫ для обоих мест:
///   • [inferModuleLink] (запись в БД, вызывается из add_task_sheet._save)
///   • nl_datetime.dart::_detectModuleLink (подсказки UI парсера) — конвертирует
///     эту же карту через ModuleInferenceKey → _Keyword, не держит свою копию.
///
/// Проверяются по порядку; возвращается первое совпадение.
/// Значения должны ТОЧНО совпадать с тем, что ожидает _openModule в картах задач.
///
/// ПОРЯДОК приоритетов при коллизии ключевых слов:
///   workout > meal:* > focus > warmup > breathing > meditation > sleep
/// Пример: «дыхание перед сном» → breathing (breathing раньше sleep в списке).
const List<(List<ModuleInferenceKey>, String)> kModuleInferenceKeywords = [
  // --- workout ---
  (
    [
      ModuleInferenceKey('тренировк'),           // тренировка / тренировки / тренировку
      ModuleInferenceKey('трен', wholeWord: true), // «трен» как отдельное сокращение
      ModuleInferenceKey('качал'),               // качалка
      ModuleInferenceKey('спортзал'),            // спортзал
      ModuleInferenceKey('отжим'),               // отжимания
      ModuleInferenceKey('присед'),              // приседания
      ModuleInferenceKey('пробежк'),             // пробежка
      ModuleInferenceKey('бег', wholeWord: true), // бег (не «победа», не «берег»)
      ModuleInferenceKey('йога'),                // йога / йогой
      ModuleInferenceKey('workout'),             // EN
      ModuleInferenceKey('gym', wholeWord: true), // EN
      ModuleInferenceKey('run', wholeWord: true), // EN: run (не «runner» — wholeWord)
      ModuleInferenceKey('exercise'),            // EN
      ModuleInferenceKey('yoga'),                // EN
    ],
    'workout',
  ),
  // --- meal:breakfast ---
  (
    [
      ModuleInferenceKey('завтрак'),
      ModuleInferenceKey('breakfast'),
    ],
    'meal:breakfast',
  ),
  // --- meal:lunch ---
  (
    [
      ModuleInferenceKey('пообед'),              // пообедать / пообедаю
      ModuleInferenceKey('обед'),                // обед / обедать
      ModuleInferenceKey('lunch'),
    ],
    'meal:lunch',
  ),
  // --- meal:dinner ---
  (
    [
      ModuleInferenceKey('ужин'),
      ModuleInferenceKey('dinner'),
      ModuleInferenceKey('supper'),
    ],
    'meal:dinner',
  ),
  // Намеренно НЕ добавляем 'food', 'еда', 'поесть' без слота —
  // карточка не знает, в какой meal-слот маршрутизировать.

  // --- focus ---
  (
    [
      ModuleInferenceKey('фокус'),               // фокус-сессия, фокусировка
      ModuleInferenceKey('сосредоточ'),           // сосредоточиться, сосредоточься
      ModuleInferenceKey('помодоро'),             // помодоро-техника
      ModuleInferenceKey('pomodoro'),             // EN
      ModuleInferenceKey('focus', wholeWord: true), // EN: focus (целое слово)
      ModuleInferenceKey('deep work'),            // EN: deep work (фраза)
    ],
    'focus',
  ),
  // --- warmup ---
  (
    [
      ModuleInferenceKey('зарядк'),              // зарядка, зарядки
      ModuleInferenceKey('разминк'),             // разминка
      ModuleInferenceKey('растяжк'),             // растяжка
      ModuleInferenceKey('warmup'),              // EN: warmup
      ModuleInferenceKey('warm up'),             // EN: warm up (с пробелом)
      ModuleInferenceKey('stretch'),             // EN: stretch, stretching
    ],
    'warmup',
  ),
  // --- breathing ---
  // Стоит ПЕРЕД sleep: «подышать перед сном» → breathing, не sleep.
  (
    [
      ModuleInferenceKey('дых'),                 // дыхание/дыхательная/дыхания — общий корень «дых»
      ModuleInferenceKey('подыша'),              // подышать
      ModuleInferenceKey('breath'),              // EN: breath, breathe, breathing
    ],
    'breathing',
  ),
  // --- meditation ---
  (
    [
      ModuleInferenceKey('медитаци'),            // медитация, медитации
      ModuleInferenceKey('медитир'),             // медитировать
      ModuleInferenceKey('meditat'),             // EN: meditate, meditation, meditating
    ],
    'meditation',
  ),
  // --- sleep ---
  (
    [
      ModuleInferenceKey('поспат'),              // поспать
      ModuleInferenceKey('выспат'),              // выспаться
      ModuleInferenceKey('спать', wholeWord: true),
      ModuleInferenceKey('сон', wholeWord: true),
      ModuleInferenceKey('лечь', wholeWord: true), // лечь (спать)
      ModuleInferenceKey('nap', wholeWord: true),  // EN
      ModuleInferenceKey('sleep'),               // EN: sleep / sleeping
      ModuleInferenceKey('bedtime'),             // EN
    ],
    'sleep',
  ),
];

/// Определяет ссылку на модуль по заголовку задачи [title] (и необязательному
/// типу [type]) путём поиска ключевых слов.
///
/// Возвращает одно из:
///   'workout' | 'meal:breakfast' | 'meal:lunch' | 'meal:dinner' |
///   'sleep' | 'focus' | 'warmup' | 'breathing' | 'meditation' | null
///
/// Возвращаемые значения точно совпадают с тем, что ожидает _openModule()
/// в task_list.dart / day_timeline.dart / week_agenda.dart.
///
/// Пример:
///   inferModuleLink('Утренняя тренировка') → 'workout'
///   inferModuleLink('завтрак')             → 'meal:breakfast'
///   inferModuleLink('фокус-сессия 25 мин') → 'focus'
///   inferModuleLink('разминка утром')      → 'warmup'
///   inferModuleLink('подышать перед сном') → 'breathing'
///   inferModuleLink('медитация 10 минут')  → 'meditation'
///   inferModuleLink('Купить молоко')       → null
String? inferModuleLink(String title, {String? type}) {
  final lower = title.toLowerCase();
  for (final (keys, value) in kModuleInferenceKeywords) {
    for (final k in keys) {
      if (_matchKey(lower, k)) return value;
    }
  }
  return null;
}
