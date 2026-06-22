// FL-RECUR: Чистая (без зависимостей от Flutter/Drift) библиотека повторов задач.
//
// Цель #6: повторяющиеся задачи. Хранение — одна «якорная» строка
// (anchor) в items + правило в текстовой колонке recurrenceRule. Никакой
// миграции схемы: переиспользуем существующую nullable-колонку recurrenceRule.
//
// Формат правила — iCal-подобная строка. Поддерживаемые частоты:
//
//   FREQ=DAILY                       — каждый день начиная с anchor-даты.
//   FREQ=WEEKLY;BYDAY=MO,WE,FR       — заданные дни недели (MO,TU,WE,TH,FR,SA,SU).
//                                       Если BYDAY опущен — берётся день недели anchor-даты.
//   FREQ=MONTHLY;BYMONTHDAY=15       — заданное число месяца (1..31).
//                                       Если BYMONTHDAY опущен — берётся день anchor-даты.
//
// Общие (для всех частот) необязательные части:
//   ;UNTIL=YYYY-MM-DD                (необязательно; включительно последний день — механизм отмены)
//   ;EXDATE=YYYYMMDD,YYYYMMDD,...    (необязательно; даты, исключённые из генерации,
//                                     потому что были «материализованы» в обычную строку)
//
// MONTHLY и «нет такого числа в месяце»: если BYMONTHDAY=31, а в месяце 30 (или
// 28/29) дней — повтор в этом месяце ПРОПУСКАЕТСЯ (без клампа к последнему дню).
// Это самый предсказуемый для пользователя вариант: «15 числа» означает строго
// 15-е; «31 числа» — только в месяцах, где 31-е существует. Клампинг к 28/30
// привёл бы к «плавающей» дате и сюрпризам в феврале.
//
// ВСЁ здесь — чистые функции/классы, полностью покрытые test/recurrence_test.dart.
// Даты повторов сравниваются ТОЛЬКО по году/месяцу/дню (время игнорируется).

/// Частота повторения.
enum RecurFreq { daily, weekly, monthly }

/// Дни недели для WEEKLY-правил. Значение = `DateTime.weekday` (Пн=1 … Вс=7),
/// `token` — iCal-обозначение (MO..SU).
enum RecurWeekday {
  mo(1, 'MO'),
  tu(2, 'TU'),
  we(3, 'WE'),
  th(4, 'TH'),
  fr(5, 'FR'),
  sa(6, 'SA'),
  su(7, 'SU');

  const RecurWeekday(this.dartWeekday, this.token);

  /// Соответствует `DateTime.weekday` (1=понедельник … 7=воскресенье).
  final int dartWeekday;

  /// iCal-токен (MO, TU, …).
  final String token;

  /// По `DateTime.weekday` (1..7). Бросает, если вне диапазона.
  static RecurWeekday fromDartWeekday(int wd) =>
      RecurWeekday.values.firstWhere((e) => e.dartWeekday == wd);

  /// По токену (без учёта регистра). null если неизвестен.
  static RecurWeekday? fromToken(String token) {
    final t = token.trim().toUpperCase();
    for (final e in RecurWeekday.values) {
      if (e.token == t) return e;
    }
    return null;
  }
}

/// Нормализует [d] до полуночи (год/месяц/день, без времени, локально).
/// Все сравнения дат в этой библиотеке идут через нормализованные значения.
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// `2026-06-22` (для UNTIL).
String _fmtUntil(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// `20260622` (для EXDATE).
String _fmtExDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

/// Парсит `YYYY-MM-DD` (UNTIL). null при неверном формате.
DateTime? _parseUntil(String s) {
  final parts = s.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Парсит `YYYYMMDD` (EXDATE). null при неверном формате.
DateTime? _parseExDate(String s) {
  if (s.length != 8) return null;
  final y = int.tryParse(s.substring(0, 4));
  final m = int.tryParse(s.substring(4, 6));
  final d = int.tryParse(s.substring(6, 8));
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Число дней в месяце [year]/[month] (1..12). 31/30/29/28.
int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Правило повторения серии задач.
///
/// [exDates] хранятся как нормализованные (полночь) даты; сравнение — по Y/M/D.
/// [byDays] — дни недели для WEEKLY (пусто = «как день недели anchor-даты»).
/// [byMonthDay] — число месяца для MONTHLY (null = «как день anchor-даты»).
class RecurrenceRule {
  RecurrenceRule({
    this.freq = RecurFreq.daily,
    DateTime? until,
    Set<DateTime>? exDates,
    Set<RecurWeekday>? byDays,
    this.byMonthDay,
  })  : until = until == null ? null : _dateOnly(until),
        exDates = {
          for (final e in (exDates ?? const <DateTime>{})) _dateOnly(e),
        },
        byDays = {...?byDays};

  /// Частота: daily / weekly / monthly.
  final RecurFreq freq;

  /// Включительно последний день, после которого повторов нет. null = бессрочно.
  final DateTime? until;

  /// Исключённые даты (материализованные дни). Сравниваются по Y/M/D.
  final Set<DateTime> exDates;

  /// Дни недели для WEEKLY. Пустой набор => использовать день недели anchor-даты
  /// (вычисляется лениво в [occursOn]). Для daily/monthly игнорируется.
  final Set<RecurWeekday> byDays;

  /// Число месяца (1..31) для MONTHLY. null => использовать день anchor-даты.
  /// Для daily/weekly игнорируется.
  final int? byMonthDay;

  /// Разбирает строку правила. Возвращает null, если это НЕ серия
  /// (нет распознанной `FREQ=`) — тогда строку нельзя считать повторяющейся.
  static RecurrenceRule? parse(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    RecurFreq? freq;
    DateTime? until;
    final exDates = <DateTime>{};
    final byDays = <RecurWeekday>{};
    int? byMonthDay;

    for (final part in trimmed.split(';')) {
      final eq = part.indexOf('=');
      if (eq < 0) continue;
      final key = part.substring(0, eq).trim().toUpperCase();
      final value = part.substring(eq + 1).trim();
      switch (key) {
        case 'FREQ':
          switch (value.toUpperCase()) {
            case 'DAILY':
              freq = RecurFreq.daily;
            case 'WEEKLY':
              freq = RecurFreq.weekly;
            case 'MONTHLY':
              freq = RecurFreq.monthly;
          }
        case 'UNTIL':
          until = _parseUntil(value);
        case 'EXDATE':
          for (final token in value.split(',')) {
            final t = token.trim();
            if (t.isEmpty) continue;
            final parsed = _parseExDate(t);
            if (parsed != null) exDates.add(parsed);
          }
        case 'BYDAY':
          for (final token in value.split(',')) {
            final wd = RecurWeekday.fromToken(token);
            if (wd != null) byDays.add(wd);
          }
        case 'BYMONTHDAY':
          final n = int.tryParse(value);
          if (n != null && n >= 1 && n <= 31) byMonthDay = n;
      }
    }

    // Без поддерживаемой частоты это не серия.
    if (freq == null) return null;
    return RecurrenceRule(
      freq: freq,
      until: until,
      exDates: exDates,
      byDays: byDays,
      byMonthDay: byMonthDay,
    );
  }

  /// Сериализует обратно в строку правила (round-trip с [parse]).
  /// Порядок частей детерминированный: FREQ, BYDAY/BYMONTHDAY, UNTIL, EXDATE.
  /// BYDAY сортируется по дню недели, EXDATE — по возрастанию даты.
  String toRuleString() {
    final freqToken = switch (freq) {
      RecurFreq.daily => 'DAILY',
      RecurFreq.weekly => 'WEEKLY',
      RecurFreq.monthly => 'MONTHLY',
    };
    final sb = StringBuffer('FREQ=$freqToken');

    if (freq == RecurFreq.weekly && byDays.isNotEmpty) {
      final sorted = byDays.toList()
        ..sort((a, b) => a.dartWeekday.compareTo(b.dartWeekday));
      sb.write(';BYDAY=${sorted.map((e) => e.token).join(',')}');
    }
    if (freq == RecurFreq.monthly && byMonthDay != null) {
      sb.write(';BYMONTHDAY=$byMonthDay');
    }
    if (until != null) {
      sb.write(';UNTIL=${_fmtUntil(until!)}');
    }
    if (exDates.isNotEmpty) {
      final sorted = exDates.toList()..sort((a, b) => a.compareTo(b));
      sb.write(';EXDATE=${sorted.map(_fmtExDate).join(',')}');
    }
    return sb.toString();
  }

  /// Копия с заменой полей.
  RecurrenceRule copyWith({
    RecurFreq? freq,
    DateTime? until,
    bool clearUntil = false,
    Set<DateTime>? exDates,
    Set<RecurWeekday>? byDays,
    int? byMonthDay,
    bool clearByMonthDay = false,
  }) {
    return RecurrenceRule(
      freq: freq ?? this.freq,
      until: clearUntil ? null : (until ?? this.until),
      exDates: exDates ?? this.exDates,
      byDays: byDays ?? this.byDays,
      byMonthDay: clearByMonthDay ? null : (byMonthDay ?? this.byMonthDay),
    );
  }

  /// Эффективные дни недели для WEEKLY с учётом [anchorStart]:
  /// если BYDAY задан — он; иначе один день — день недели anchor-даты.
  Set<RecurWeekday> effectiveByDays(DateTime anchorStart) {
    if (byDays.isNotEmpty) return byDays;
    return {RecurWeekday.fromDartWeekday(_dateOnly(anchorStart).weekday)};
  }

  /// Эффективное число месяца для MONTHLY: BYMONTHDAY либо день anchor-даты.
  int effectiveMonthDay(DateTime anchorStart) =>
      byMonthDay ?? _dateOnly(anchorStart).day;
}

/// true, если серия с правилом [rule] и началом [anchorStart] порождает
/// повтор на дату [day]. Сравнение только по Y/M/D.
///
/// Общие условия (для всех частот):
///   • day >= даты anchorStart
///   • until == null ИЛИ day <= until
///   • day не входит в exDates
/// Плюс частото-зависимый фильтр:
///   • daily   — любой день окна;
///   • weekly  — weekday(day) ∈ effectiveByDays;
///   • monthly — day.day == effectiveMonthDay (если такого числа в месяце нет —
///               этот месяц пропускается автоматически).
bool occursOn(RecurrenceRule rule, DateTime anchorStart, DateTime day) {
  final d = _dateOnly(day);
  final start = _dateOnly(anchorStart);
  if (d.isBefore(start)) return false;
  if (rule.until != null && d.isAfter(rule.until!)) return false;
  if (rule.exDates.contains(d)) return false;

  switch (rule.freq) {
    case RecurFreq.daily:
      return true;
    case RecurFreq.weekly:
      final wd = RecurWeekday.fromDartWeekday(d.weekday);
      return rule.effectiveByDays(start).contains(wd);
    case RecurFreq.monthly:
      return d.day == rule.effectiveMonthDay(start);
  }
}

/// Список дат-повторов в диапазоне [fromDay, toDay] включительно (по Y/M/D).
/// Возвращаются нормализованные даты (полночь). Пустой список, если пересечения
/// окна серии с диапазоном нет.
///
/// Реализация эффективна: для weekly шагаем по совпадающим дням недели, для
/// monthly — по месяцам (не перебираем каждый день диапазона для редких частот).
List<DateTime> occurrenceDatesInRange(
  DateTime anchorStart,
  RecurrenceRule rule,
  DateTime fromDay,
  DateTime toDay,
) {
  final from = _dateOnly(fromDay);
  final to = _dateOnly(toDay);
  if (to.isBefore(from)) return const [];

  switch (rule.freq) {
    case RecurFreq.daily:
      return _dailyRange(anchorStart, rule, from, to);
    case RecurFreq.weekly:
      return _weeklyRange(anchorStart, rule, from, to);
    case RecurFreq.monthly:
      return _monthlyRange(anchorStart, rule, from, to);
  }
}

/// DAILY: каждый день окна (через occursOn для единообразия EXDATE/UNTIL/старт).
List<DateTime> _dailyRange(
  DateTime anchorStart,
  RecurrenceRule rule,
  DateTime from,
  DateTime to,
) {
  final result = <DateTime>[];
  var cursor = from;
  var guard = 0;
  const maxGuard = 3700; // ~10 лет
  while (!cursor.isAfter(to) && guard < maxGuard) {
    if (occursOn(rule, anchorStart, cursor)) result.add(cursor);
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    guard++;
  }
  return result;
}

/// WEEKLY: для каждого дня недели из правила находим первое вхождение в окне и
/// шагаем по +7 дней. День добавляется только если occursOn (учитывает старт/
/// UNTIL/EXDATE). Перебор ограничен числом дней недели × неделями диапазона.
List<DateTime> _weeklyRange(
  DateTime anchorStart,
  RecurrenceRule rule,
  DateTime from,
  DateTime to,
) {
  final days = rule.effectiveByDays(_dateOnly(anchorStart));
  final result = <DateTime>[];
  for (final wd in days) {
    // Первый день >= from с нужным днём недели.
    final offset = (wd.dartWeekday - from.weekday + 7) % 7;
    var cursor = DateTime(from.year, from.month, from.day + offset);
    var guard = 0;
    const maxGuard = 600; // ~11 лет недель
    while (!cursor.isAfter(to) && guard < maxGuard) {
      if (occursOn(rule, anchorStart, cursor)) result.add(cursor);
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 7);
      guard++;
    }
  }
  result.sort((a, b) => a.compareTo(b));
  return result;
}

/// MONTHLY: шагаем по месяцам диапазона. В каждом месяце берём целевое число,
/// если оно существует (иначе месяц пропускается). occursOn досеивает старт/
/// UNTIL/EXDATE. Перебор ограничен числом месяцев диапазона.
List<DateTime> _monthlyRange(
  DateTime anchorStart,
  RecurrenceRule rule,
  DateTime from,
  DateTime to,
) {
  final targetDay = rule.effectiveMonthDay(_dateOnly(anchorStart));
  final result = <DateTime>[];
  var year = from.year;
  var month = from.month;
  var guard = 0;
  const maxGuard = 130; // ~10 лет месяцев
  while (guard < maxGuard) {
    final firstOfMonth = DateTime(year, month, 1);
    if (firstOfMonth.isAfter(DateTime(to.year, to.month, to.day))) break;
    // Целевое число существует в этом месяце?
    if (targetDay <= _daysInMonth(year, month)) {
      final candidate = DateTime(year, month, targetDay);
      if (!candidate.isBefore(from) &&
          !candidate.isAfter(to) &&
          occursOn(rule, anchorStart, candidate)) {
        result.add(candidate);
      }
    }
    // Следующий месяц.
    month++;
    if (month > 12) {
      month = 1;
      year++;
    }
    guard++;
  }
  return result;
}

// ---------------------------------------------------------------------------
// Хелперы для модификации строки правила (используются при materialize/cancel)
// ---------------------------------------------------------------------------

/// Добавляет дату [day] в EXDATE правила [raw] и возвращает новую строку.
/// Если [raw] не является серией — возвращает [raw] без изменений.
/// Идемпотентно: повторное добавление той же даты ничего не меняет.
String? addExDateToRule(String? raw, DateTime day) {
  final rule = RecurrenceRule.parse(raw);
  if (rule == null) return raw;
  final next = {...rule.exDates, _dateOnly(day)};
  return rule.copyWith(exDates: next).toRuleString();
}

/// Устанавливает (заменяет) UNTIL в правиле [raw] на дату [until].
/// Если [raw] не серия — возвращает [raw] без изменений.
String? setUntilOnRule(String? raw, DateTime until) {
  final rule = RecurrenceRule.parse(raw);
  if (rule == null) return raw;
  return rule.copyWith(until: until).toRuleString();
}

// ---------------------------------------------------------------------------
// Удобные конструкторы правил (для UI и будущего NL-парсера).
// Парсер фразы вроде «каждый понедельник» может собрать правило этими функциями.
// ---------------------------------------------------------------------------

/// Ежедневное правило (опционально с датой окончания [until]).
RecurrenceRule dailyRule({DateTime? until}) =>
    RecurrenceRule(freq: RecurFreq.daily, until: until);

/// Еженедельное правило по дням недели [days] (например {mo, we, fr}).
/// Пустой [days] => серия повторяется в день недели anchor-даты.
RecurrenceRule weeklyRule(Set<RecurWeekday> days, {DateTime? until}) =>
    RecurrenceRule(freq: RecurFreq.weekly, byDays: days, until: until);

/// Ежемесячное правило на число [monthDay] (1..31).
/// null => серия повторяется в день месяца anchor-даты.
RecurrenceRule monthlyRule({int? monthDay, DateTime? until}) =>
    RecurrenceRule(freq: RecurFreq.monthly, byMonthDay: monthDay, until: until);
