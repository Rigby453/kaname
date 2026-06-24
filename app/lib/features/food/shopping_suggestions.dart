// Чистая функция «предложений для списка покупок» на основе истории еды.
// Без БД, без ИИ, без сети — только частотный анализ foodLogs за последние 30 дней.
// Может быть протестирована изолированно без виджетов и провайдеров.

/// Минимальная частота появления продукта за период, чтобы попасть в предложения.
const kMinFrequency = 3;

/// Максимальное количество предложений в секции.
const kMaxSuggestions = 10;

/// Количество дней истории для анализа.
const kSuggestionDays = 30;

/// Входная запись: имя продукта + дата (для tie-break по свежести).
class FoodLogEntry {
  const FoodLogEntry({required this.name, required this.date});

  final String name;
  final DateTime date;
}

/// Вычисляет предложения на основе истории питания.
///
/// [logs] — записи за последние [kSuggestionDays] дней (name + date).
/// [basketNames] — имена позиций, уже находящихся в корзине (case-insensitive исключение).
///
/// Алгоритм:
/// 1. Нормализуем имя: trim + lowercase → ключ дедупликации.
/// 2. Считаем частоту (каждое вхождение в лог = +1, не уникальные дни).
/// 3. Для каждой нормализованной группы сохраняем «чистое» имя с наибольшей
///    частотой (наиболее употребляемое написание) и дату последнего вхождения.
/// 4. Отфильтровываем: частота < [kMinFrequency] и имена из [basketNames].
/// 5. Сортируем: по частоте убыванием; при равенстве — по дате убыванием (свежее выше).
/// 6. Возвращаем не более [kMaxSuggestions] чистых имён.
List<String> computeShoppingSuggestions({
  required List<FoodLogEntry> logs,
  required Set<String> basketNames,
}) {
  // Нормализованные имена корзины для быстрого поиска
  final basketNorm = basketNames.map(_normalize).toSet();

  // freq[normKey] = count
  final freq = <String, int>{};
  // latestDate[normKey] = самая свежая дата
  final latestDate = <String, DateTime>{};
  // displayName[normKey] = имя с наибольшей встречаемостью; при ничьей — первое
  // Храним: normKey → { rawName → count }
  final nameCounts = <String, Map<String, int>>{};

  for (final entry in logs) {
    final norm = _normalize(entry.name);
    if (norm.isEmpty) continue;

    freq[norm] = (freq[norm] ?? 0) + 1;

    // Обновляем самую свежую дату
    final prev = latestDate[norm];
    if (prev == null || entry.date.isAfter(prev)) {
      latestDate[norm] = entry.date;
    }

    // Учитываем варианты написания
    nameCounts.putIfAbsent(norm, () => {})[entry.name] =
        (nameCounts[norm]![entry.name] ?? 0) + 1;
  }

  // Строим список кандидатов
  final candidates = <_Candidate>[];
  for (final norm in freq.keys) {
    final count = freq[norm]!;
    if (count < kMinFrequency) continue;
    if (basketNorm.contains(norm)) continue;

    // Выбираем написание с наибольшим count; при ничьей — лексикографически первое
    final variants = nameCounts[norm]!;
    String bestName = '';
    int bestCount = -1;
    for (final e in variants.entries) {
      if (e.value > bestCount ||
          (e.value == bestCount && e.key.compareTo(bestName) < 0)) {
        bestCount = e.value;
        bestName = e.key;
      }
    }

    candidates.add(_Candidate(
      name: bestName,
      freq: count,
      latest: latestDate[norm]!,
    ));
  }

  // Сортировка: freq DESC, затем latest DESC
  candidates.sort((a, b) {
    final cmp = b.freq.compareTo(a.freq);
    if (cmp != 0) return cmp;
    return b.latest.compareTo(a.latest);
  });

  return candidates
      .take(kMaxSuggestions)
      .map((c) => c.name)
      .toList();
}

/// Нормализация: trim + lowercase.
String _normalize(String name) => name.trim().toLowerCase();

class _Candidate {
  const _Candidate({
    required this.name,
    required this.freq,
    required this.latest,
  });

  final String name;
  final int freq;
  final DateTime latest;
}
