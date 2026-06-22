// Чистая (без I/O) категоризация пакетов Android в 5 категорий экранного времени.
// Используется провайдером использования: сопоставляем имя пакета → категорию,
// затем суммируем минуты. Легко тестируется юнит-тестами.
//
// Категории совпадают с ключами screenTimeCategories в screen_time_provider.dart:
//   social, video, games, browsing, messaging.

/// Сопоставление известных имён Android-пакетов с нашими 5 категориями.
///
/// Покрывает популярные мировые и российские приложения. Список не может быть
/// исчерпывающим (особенно игры — их десятки тысяч), поэтому неизвестные пакеты
/// просто игнорируются в [categorizeUsageMinutes].
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
  // Большинство игр останутся неучтёнными (известное ограничение).
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

/// Суммирует минуты использования по пакетам в наши 5 категорий.
///
/// [perPackageMinutes] — карта `packageName → minutes`. Неизвестные пакеты
/// (отсутствующие в [kPackageToCategory]) игнорируются. Возвращает карту со
/// всеми 5 категориями (отсутствующие — 0). Чистая функция: без I/O.
Map<String, int> categorizeUsageMinutes(Map<String, int> perPackageMinutes) {
  final result = <String, int>{
    'social': 0,
    'video': 0,
    'games': 0,
    'browsing': 0,
    'messaging': 0,
  };
  perPackageMinutes.forEach((package, minutes) {
    final category = kPackageToCategory[package];
    if (category == null) return; // неизвестный пакет — игнорируем
    if (minutes <= 0) return;
    result[category] = (result[category] ?? 0) + minutes;
  });
  return result;
}
