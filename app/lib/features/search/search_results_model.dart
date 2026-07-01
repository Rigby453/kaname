// Модель данных глобального поиска (#17).
// Только данные — никаких user-facing строк (labels/подписи секций рисует UI
// через context.s(), используя поле [kind] и её собственную l10n-карту).
//
// Поиск идёт по 4 сущностям локальной Drift-БД: задачи, дневник, рецепты,
// покупки. Один хит = одна найденная запись; секции группируют хиты по типу.

/// Тип сущности, к которой относится найденная запись.
/// Порядок значений — это и порядок секций по умолчанию (задачи → дневник →
/// рецепты → покупки); UI может переопределить порядок отображения.
enum SearchHitKind { task, diary, recipe, shopping }

/// Одна находка глобального поиска.
///
/// Навигация: UI-слой использует ([kind], [id], [date]) чтобы построить переход
/// — например, kind=task → открыть Plan на [date] и выделить задачу [id];
/// kind=diary → открыть Diary на [date]; kind=recipe → открыть редактор рецепта
/// [id]; kind=shopping → открыть список покупок (id не нужен для навигации,
/// но передаётся для консистentности / потенциального выделения строки).
/// Отдельного поля "route" не заводим: (kind, id, date) полностью описывают
/// целевой экран, а сам роут строит UI-слой (здесь его нет и не должно быть).
class GlobalSearchHit {
  /// UUID записи в исходной таблице (items.id / day_logs.id / recipes.id /
  /// shopping_items.id) — используется UI для навигации/выделения.
  final String id;

  /// Что показать в первой строке результата.
  /// - task: item.title
  /// - diary: короткий фрагмент note вокруг совпадения (в day_logs нет
  ///   отдельного поля "заголовок")
  /// - recipe: recipe.name
  /// - shopping: shopping_item.name
  final String title;

  /// Что показать во второй строке (опционально) — короткий фрагмент вокруг
  /// совпадения в description (для recipe, когда совпадение НЕ в name).
  /// null, если для этого хита нет отдельного текста для второй строки.
  final String? snippet;

  /// Тип сущности — какая секция и как формировать навигацию.
  final SearchHitKind kind;

  /// Дата, связанная с записью (scheduledAt задачи / день дневника), или null
  /// (у рецептов/покупок собственной "даты" нет — createdAt для сортировки не
  /// принципиален для этой фичи). Используется для сортировки/показа и для
  /// навигации на нужный день (Plan/Diary).
  final DateTime? date;

  const GlobalSearchHit({
    required this.id,
    required this.title,
    required this.kind,
    this.snippet,
    this.date,
  });

  @override
  String toString() =>
      'GlobalSearchHit(kind: $kind, id: $id, title: $title, snippet: $snippet, date: $date)';

  @override
  bool operator ==(Object other) =>
      other is GlobalSearchHit &&
      other.id == id &&
      other.title == title &&
      other.snippet == snippet &&
      other.kind == kind &&
      other.date == date;

  @override
  int get hashCode => Object.hash(id, title, snippet, kind, date);
}

/// Результаты глобального поиска, сгруппированные по секциям (сущностям).
class GlobalSearchResults {
  final List<GlobalSearchHit> tasks;
  final List<GlobalSearchHit> diary;
  final List<GlobalSearchHit> recipes;
  final List<GlobalSearchHit> shopping;

  const GlobalSearchResults({
    this.tasks = const [],
    this.diary = const [],
    this.recipes = const [],
    this.shopping = const [],
  });

  /// Пустой результат — например, для пустого/пробельного запроса.
  const GlobalSearchResults.empty() : this();

  bool get isEmpty =>
      tasks.isEmpty && diary.isEmpty && recipes.isEmpty && shopping.isEmpty;

  int get totalCount =>
      tasks.length + diary.length + recipes.length + shopping.length;
}
