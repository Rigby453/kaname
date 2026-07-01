// Чистая (без I/O) категоризация пакетов Android в 6 категорий экранного времени.
// Используется провайдером использования: сопоставляем имя пакета → категорию,
// затем суммируем минуты. Легко тестируется юнит-тестами.
//
// Категории совпадают с ключами screenTimeCategories в screen_time_provider.dart:
//   social, video, games, browsing, messaging, other.

/// Сопоставление известных имён Android-пакетов с нашими категориями.
///
/// Покрывает популярные мировые и российские приложения. Список не может быть
/// исчерпывающим (особенно игры — их десятки тысяч), поэтому неизвестные пакеты
/// роутятся через Android-категорию в один из бакетов, либо в 'other'.
const Map<String, String> kPackageToCategory = <String, String>{
  // --- social ---------------------------------------------------------------
  'com.instagram.android': 'social',
  'com.facebook.katana': 'social',
  'com.facebook.lite': 'social',
  'com.vkontakte.android': 'social',
  'com.twitter.android': 'social', // X (старый пакет)
  'com.snapchat.android': 'social',
  'com.linkedin.android': 'social',
  'com.pinterest': 'social',
  'com.reddit.frontpage': 'social',
  'com.tumblr': 'social',
  'ru.ok.android': 'social', // Одноклассники
  'com.zhiliaoapp.musically.go': 'social',

  // --- video ----------------------------------------------------------------
  'com.google.android.youtube': 'video',
  'com.google.android.apps.youtube.music': 'video',
  'com.google.android.apps.youtube.kids': 'video',
  'com.zhiliaoapp.musically': 'video', // TikTok (global)
  'com.ss.android.ugc.trill': 'video', // TikTok (другой регион)
  'tv.twitch.android.app': 'video',
  'com.netflix.mediaclient': 'video',
  'ru.kinopoisk.yandex': 'video', // Кинопоиск
  'ru.rutube.app': 'video', // RuTube
  'com.amazon.avod.thirdpartyclient': 'video', // Prime Video
  'com.disney.disneyplus': 'video',
  'ru.more.play': 'video', // more.tv / Wink-подобные
  'com.ivi.client': 'video', // ivi

  // --- games ----------------------------------------------------------------
  // Игр слишком много, чтобы перечислить все — здесь только самые популярные.
  // Большинство игр попадут в 'games' через Android CATEGORY_GAME fallback.
  'com.king.candycrushsaga': 'games',
  'com.supercell.clashofclans': 'games',
  'com.supercell.brawlstars': 'games',
  'com.supercell.clashroyale': 'games',
  'com.roblox.client': 'games',
  'com.mojang.minecraftpe': 'games',
  'com.miHoYo.GenshinImpact': 'games',
  'com.HoYoverse.hkrpgoversea': 'games', // Honkai: Star Rail
  'com.activision.callofduty.shooter': 'games',
  'com.dts.freefireth': 'games', // Free Fire
  'com.tencent.ig': 'games', // PUBG Mobile
  'com.pubg.krmobile': 'games',
  'com.epicgames.fortnite': 'games',
  'com.innersloth.spacemafia': 'games', // Among Us
  'com.nianticlabs.pokemongo': 'games',

  // --- browsing -------------------------------------------------------------
  'com.android.chrome': 'browsing',
  'org.mozilla.firefox': 'browsing',
  'com.opera.browser': 'browsing',
  'com.opera.mini.native': 'browsing',
  'com.opera.gx': 'browsing',
  'com.yandex.browser': 'browsing',
  'com.microsoft.emmx': 'browsing', // Edge
  'com.sec.android.app.sbrowser': 'browsing', // Samsung Internet
  'com.brave.browser': 'browsing',
  'com.duckduckgo.mobile.android': 'browsing',
  'com.UCMobile.intl': 'browsing', // UC Browser

  // --- messaging ------------------------------------------------------------
  'org.telegram.messenger': 'messaging',
  'org.telegram.messenger.web': 'messaging',
  'com.whatsapp': 'messaging',
  'com.whatsapp.w4b': 'messaging', // WhatsApp Business
  'com.viber.voip': 'messaging',
  'com.discord': 'messaging',
  'ru.ok.messages': 'messaging', // TamTam
  'com.google.android.apps.messaging': 'messaging', // Google Messages
  'com.facebook.orca': 'messaging', // Messenger
  'com.skype.raider': 'messaging',
  'jp.naver.line.android': 'messaging',
  'com.tencent.mm': 'messaging', // WeChat
  'ru.yandex.mail': 'messaging', // Яндекс.Почта (как канал общения)
};

/// Маппинг Android ApplicationInfo.category (int) → наша категория.
///
/// Значения констант Android:
///   CATEGORY_GAME        = 0
///   CATEGORY_AUDIO       = 1
///   CATEGORY_VIDEO       = 2
///   CATEGORY_IMAGE       = 3
///   CATEGORY_SOCIAL      = 4
///   CATEGORY_NEWS        = 5
///   CATEGORY_MAPS        = 6
///   CATEGORY_PRODUCTIVITY = 7
///   CATEGORY_UNDEFINED   = -1
String? androidCategoryToOurCategory(int androidCategory) {
  switch (androidCategory) {
    case 0: // CATEGORY_GAME
      return 'games';
    case 1: // CATEGORY_AUDIO
      return 'video'; // аудио → video-бакет (музыка/подкасты)
    case 2: // CATEGORY_VIDEO
      return 'video';
    case 3: // CATEGORY_IMAGE
      return null; // фото-галереи → other (нет подходящего бакета)
    case 4: // CATEGORY_SOCIAL
      return 'social';
    case 5: // CATEGORY_NEWS
      return 'browsing'; // новости близки к браузингу
    case 6: // CATEGORY_MAPS
      return null; // карты → other
    case 7: // CATEGORY_PRODUCTIVITY
      return null; // продуктивность → other (не отвлекающий)
    default: // CATEGORY_UNDEFINED (-1) и всё остальное
      return null; // → other
  }
}

/// Суммирует минуты использования по пакетам в наши 6 категорий.
///
/// [perPackageMinutes] — карта `packageName → minutes`.
/// [userOverrides] — наивысший приоритет: пользователь вручную переопределил
///   категорию для конкретных пакетов. Хранится в SharedPreferences.
/// [androidCategoryOverrides] — карта `packageName → ourCategory` от Android
///   (CATEGORY_GAME → games и т.д.). Применяется для пакетов, НЕ найденных
///   в [kPackageToCategory] и не имеющих [userOverrides].
///
/// Приоритет: userOverrides > whitelist > androidCategoryOverrides > 'other'.
///
/// Возвращает карту со всеми 6 категориями (отсутствующие — 0). Чистая функция: без I/O.
Map<String, int> categorizeUsageMinutes(
  Map<String, int> perPackageMinutes, {
  Map<String, String> androidCategoryOverrides = const <String, String>{},
  Map<String, String> userOverrides = const <String, String>{},
}) {
  final result = <String, int>{
    'social': 0,
    'video': 0,
    'games': 0,
    'browsing': 0,
    'messaging': 0,
    'other': 0,
  };
  perPackageMinutes.forEach((package, minutes) {
    if (minutes <= 0) return;

    // 1. Пользовательское переопределение (наивысший приоритет).
    final userCat = userOverrides[package];
    if (userCat != null) {
      result[userCat] = (result[userCat] ?? 0) + minutes;
      return;
    }

    // 2. Ищем в нашем явном whitelist (наиболее точная классификация).
    final whitelistCategory = kPackageToCategory[package];
    if (whitelistCategory != null) {
      result[whitelistCategory] = (result[whitelistCategory] ?? 0) + minutes;
      return;
    }

    // 3. Ищем в переопределениях от Android (CATEGORY_GAME → games и т.д.)
    final overrideCategory = androidCategoryOverrides[package];
    if (overrideCategory != null) {
      result[overrideCategory] = (result[overrideCategory] ?? 0) + minutes;
      return;
    }

    // 4. Неизвестный пакет — в 'other' (минуты не теряются).
    result['other'] = (result['other'] ?? 0) + minutes;
  });
  return result;
}

// ---------------------------------------------------------------------------
// Исключение «не настоящего» использования (#8 — неверный «Всего сегодня»)
// ---------------------------------------------------------------------------
//
// Android считает домашний экран (launcher) и часть системных компонентов
// «в фокусе» почти всё время, пока пользователь не открыл стороннее приложение
// (между переключениями, на заблокированном экране и т.д.) — это артефакт
// UsageStatsManager, а не реальное использование. Если не отфильтровать такие
// пакеты ДО агрегации, они почти всегда оказываются самым крупным «приложением»
// (часто многочасовым) и искусственно завышают «Всего сегодня» в разы, хотя
// каждое настоящее приложение (Instagram, YouTube…) по отдельности посчитано
// верно. Это и была причина бага «11ч 22м при реальных ~2ч использования».

/// Пакеты лаунчеров основных производителей + системный UI/«android».
/// Список не претендует на полноту (десятки OEM-лаунчеров), но покрывает
/// самые массовые случаи. Полное решение (определение лаунчера по умолчанию
/// через PackageManager) — TODO на платформенной стороне (MainActivity.kt).
const Set<String> kExcludedSystemPackages = <String>{
  'android', // системный пакет уровня платформы
  'com.android.systemui',
  'com.android.settings',
  'com.android.launcher3',
  'com.google.android.apps.nexuslauncher', // Pixel
  'com.miui.home', // MIUI / HyperOS (Xiaomi/Redmi/POCO)
  'com.mi.android.globallauncher',
  'com.sec.android.app.launcher', // Samsung One UI
  'com.huawei.android.launcher',
  'com.hihonor.android.launcher',
  'com.oppo.launcher',
  'com.coloros.launcher',
  'com.vivo.launcher',
  'com.bbk.launcher2',
  'com.oneplus.launcher',
  'com.lge.launcher3',
  'com.asus.launcher',
  'com.sonyericsson.home',
  'com.motorola.launcher3',
  'com.transsion.XOSLauncher', // Tecno / Infinix / itel
  'com.realme.launcher',
};

/// Убирает пакеты из [kExcludedSystemPackages] перед агрегацией минут.
///
/// Чистая функция (без I/O) — применяется к сырой карте `packageName → minutes`
/// ДО [categorizeUsageMinutes], чтобы лаунчер/systemui не попадали ни в одну
/// категорию (включая 'other') и не искажали суммарный итог «Всего сегодня».
Map<String, int> filterTrackedPackages(Map<String, int> perPackageMinutes) {
  if (perPackageMinutes.isEmpty) return perPackageMinutes;
  final result = <String, int>{};
  perPackageMinutes.forEach((package, minutes) {
    if (kExcludedSystemPackages.contains(package)) return;
    result[package] = minutes;
  });
  return result;
}

/// Определяет эффективную категорию одного пакета по той же цепочке приоритетов,
/// что и [categorizeUsageMinutes]. Используется при построении per-app breakdown.
///
/// Приоритет: userOverrides > whitelist > androidCategoryOverrides > 'other'.
String resolvePackageCategory(
  String packageName, {
  Map<String, String> androidCategoryOverrides = const <String, String>{},
  Map<String, String> userOverrides = const <String, String>{},
}) {
  return userOverrides[packageName] ??
      kPackageToCategory[packageName] ??
      androidCategoryOverrides[packageName] ??
      'other';
}

// ---------------------------------------------------------------------------
// Реконструкция foreground-времени из сырых событий (fix «~8ч сразу после
// полуночи»)
// ---------------------------------------------------------------------------
//
// UsageStats.queryAndAggregateUsageStats(midnight, now) возвращает ЦЕЛИКОМ
// totalTimeInForeground дневного (INTERVAL_DAILY) бакета для ЛЮБОГО пакета,
// чей бакет пересекается с окном [midnight, now) — БЕЗ клиппинга к границам
// запроса. Сразу после полуночи всё ещё «текущий» дневной бакет хранит
// вчерашнее использование, и оно целиком утекает в «сегодня» (баг ~8ч сразу
// после полуночи при реальном использовании ~0). Чиним, реконструируя
// foreground-интервалы из сырых событий UsageStats.queryEvents(), пары
// FOREGROUND→BACKGROUND, с явным клиппингом к [start, end].

/// Android `UsageEvents.Event` FOREGROUND (`MOVE_TO_FOREGROUND` /
/// `ACTIVITY_RESUMED`).
const int kEventTypeForeground = 1;

/// Android `UsageEvents.Event` BACKGROUND (`MOVE_TO_BACKGROUND` /
/// `ACTIVITY_PAUSED`).
const int kEventTypeBackground = 2;

/// Плоское (без зависимости от плагина) представление одного usage-события —
/// нужно, чтобы логика склейки/клиппинга ниже была чистой функцией и легко
/// тестировалась без usage_stats и платформенных каналов.
///
/// [type] — см. [kEventTypeForeground] / [kEventTypeBackground]. Другие типы
/// событий [computeForegroundMinutesFromEvents] игнорирует.
class UsageEventRecord {
  const UsageEventRecord({
    required this.package,
    required this.type,
    required this.timestampMs,
  });

  /// Имя пакета (packageName).
  final String package;

  /// Тип события — Android `UsageEvents.Event` integer constant.
  final int type;

  /// Момент события, epoch-миллисекунды.
  final int timestampMs;
}

/// Реконструирует минуты в foreground по пакетам за интервал [start, end) из
/// сырых событий (см. блок выше — зачем это нужно вместо агрегированных
/// дневных бакетов).
///
/// Логика: сортируем события по времени, пары FOREGROUND→BACKGROUND
/// суммируем как длительность сессии, КЛИПОВАННУЮ к [start, end]:
///  - сессия целиком внутри окна — считается полностью;
///  - сессия, начавшаяся ДО [start] (FOREGROUND до границы, включая случай,
///    когда в списке событий вообще нет FOREGROUND — сессия открылась ещё
///    раньше окна выборки), считается только с [start] — время ДО start не
///    утекает;
///  - пакет, всё ещё в foreground на момент [end] (незакрытый FOREGROUND без
///    парного BACKGROUND), считается до [end] (обычно «сейчас»).
///
/// Возвращает `packageName → minutes` (ceiling мс/60000 — короткая сессия
/// <60с всё равно считается за 1 мин, как и раньше при работе с бакетами).
/// Чистая функция: без I/O, легко тестируется.
Map<String, int> computeForegroundMinutesFromEvents(
  List<UsageEventRecord> events,
  DateTime start,
  DateTime end,
) {
  final startMs = start.millisecondsSinceEpoch;
  final endMs = end.millisecondsSinceEpoch;
  if (endMs <= startMs || events.isEmpty) return const <String, int>{};

  // Сортируем по времени — источник обычно уже упорядочен, но не полагаемся.
  final sorted = [...events]
    ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

  final openedAtMs = <String, int>{}; // package → момент открытия foreground
  final totalMsByPackage = <String, int>{};

  void addClippedDuration(String package, int fromMs, int toMs) {
    final clippedFrom = fromMs < startMs ? startMs : fromMs;
    final clippedTo = toMs > endMs ? endMs : toMs;
    if (clippedTo <= clippedFrom) return;
    totalMsByPackage[package] =
        (totalMsByPackage[package] ?? 0) + (clippedTo - clippedFrom);
  }

  for (final event in sorted) {
    if (event.type == kEventTypeForeground) {
      // Если для пакета уже есть открытая сессия (дубль FOREGROUND без
      // промежуточного BACKGROUND) — не перезаписываем момент открытия,
      // защитная мера от двойного счёта.
      openedAtMs.putIfAbsent(event.package, () => event.timestampMs);
    } else if (event.type == kEventTypeBackground) {
      final openedAt = openedAtMs.remove(event.package);
      if (openedAt != null) {
        addClippedDuration(event.package, openedAt, event.timestampMs);
      } else {
        // Нет парного FOREGROUND в списке — сессия началась ДО этого списка
        // событий (обычно: до границы окна выборки). Считаем пакет открытым
        // с [start] до этого BACKGROUND — так реальное «сегодняшнее»
        // использование после полуночи засчитывается, а часть ДО [start]
        // не утекает (граница клипуется в addClippedDuration).
        addClippedDuration(event.package, startMs, event.timestampMs);
      }
    }
  }

  // Пакеты, всё ещё в foreground на момент end ("сейчас") — клипуем до end.
  openedAtMs.forEach((package, openedAt) {
    addClippedDuration(package, openedAt, endMs);
  });

  final result = <String, int>{};
  totalMsByPackage.forEach((package, ms) {
    if (ms <= 0) return;
    result[package] = (ms / 60000).ceil();
  });
  return result;
}
