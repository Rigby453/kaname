package com.kaizen.app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Точка входа Flutter-активности.
 *
 * MethodChannel "kaizen/widget":
 *   • updateWidget  ← Flutter: сохраняет данные виджета в SharedPreferences и
 *                    шлёт broadcast на обновление всех экземпляров виджета.
 *   • getLaunchAction → Flutter: cold start — возвращает pending action из
 *                    стартового интента виджета (map {action, date?} или null).
 *                    После возврата pending action очищается (read-once).
 *
 * Deep-link flow:
 *   COLD START (приложение не запущено):
 *     1. Widget PendingIntent запускает MainActivity с extra widget_action.
 *     2. Мы сохраняем action в pendingWidgetAction/pendingWidgetDate.
 *     3. Flutter инициализируется, регистрирует handler и вызывает getLaunchAction.
 *     4. Мы возвращаем map {action, date?} и очищаем.
 *
 *   WARM START (приложение уже открыто, singleTop):
 *     1. Widget PendingIntent вызывает onNewIntent (FLAG_ACTIVITY_SINGLE_TOP).
 *     2. Мы сразу зовём channel.invokeMethod("onWidgetAction", map) на уже
 *        инициализированный Flutter движок.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "kaizen/widget"
    private val prefsName = "kaizen_widget"

    // Pending action из cold-start intent (читается ровно один раз через getLaunchAction)
    private var pendingWidgetAction: String? = null
    private var pendingWidgetDate: String? = null

    // Ссылка на канал для вызова invokeMethod в onNewIntent
    private var widgetChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Cold start: читаем extras из launch-интента виджета.
        extractWidgetAction(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Warm start: приложение уже открыто (singleTop) — отправляем действие напрямую.
        val action = intent.getStringExtra("widget_action") ?: return
        val date = intent.getStringExtra("widget_date")
        val payload = mutableMapOf<String, Any>("action" to action)
        if (date != null) payload["date"] = date

        widgetChannel?.invokeMethod("onWidgetAction", payload)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        widgetChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    saveWidgetData(call.arguments as? Map<*, *>)
                    triggerWidgetUpdate()
                    result.success(true)
                }
                // Flutter вызывает getLaunchAction один раз при старте.
                // Возвращаем {action, date?} или null если виджет не запускал приложение.
                "getLaunchAction" -> {
                    val action = pendingWidgetAction
                    if (action != null) {
                        val map = mutableMapOf<String, Any>("action" to action)
                        val date = pendingWidgetDate
                        if (date != null) map["date"] = date
                        // Очищаем pending action — read-once семантика
                        pendingWidgetAction = null
                        pendingWidgetDate = null
                        result.success(map)
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // Извлекает widget_action / widget_date из интента и сохраняет как pending.
    private fun extractWidgetAction(intent: Intent?) {
        if (intent == null) return
        val action = intent.getStringExtra("widget_action") ?: return
        pendingWidgetAction = action
        pendingWidgetDate = intent.getStringExtra("widget_date")
    }

    /**
     * Сохраняет все поля payload в SharedPreferences.
     * Legacy-поле main_progress поддерживается для обратной совместимости.
     */
    private fun saveWidgetData(args: Map<*, *>?) {
        if (args == null) return

        val prefs = getSharedPreferences(prefsName, MODE_PRIVATE).edit()

        // --- Legacy поля (Фаза 1) ---
        (args["main_progress"] as? String)?.let { prefs.putString("main_progress", it) }

        // --- Новые поля (Фаза 2) ---

        // Стрик (строка, например "7")
        (args["streak"] as? String)?.let { prefs.putString("streak", it) }

        // JSON-массив ближайших пунктов дня: [{"time":"14:30","title":"Лекция","type":"event"}]
        (args["next_items"] as? String)?.let { prefs.putString("next_items", it) }

        // Прогресс главных задач
        (args["main_done"] as? Int)?.let { prefs.putInt("main_done", it) }
        (args["main_total"] as? Int)?.let { prefs.putInt("main_total", it) }

        // Эмоция Kai: neutral / success / anxious / away
        (args["kai_emotion"] as? String)?.let { prefs.putString("kai_emotion", it) }

        // Жёсткий тон (суффикс _harsh в имени drawable)
        (args["is_harsh"] as? Boolean)?.let { prefs.putBoolean("is_harsh", it) }

        // Цвета активной темы (hex-строки "#rrggbb")
        (args["theme_accent"] as? String)?.let { prefs.putString("theme_accent", it) }
        (args["theme_bg"] as? String)?.let { prefs.putString("theme_bg", it) }
        (args["theme_surface"] as? String)?.let { prefs.putString("theme_surface", it) }
        (args["theme_text"] as? String)?.let { prefs.putString("theme_text", it) }
        (args["theme_text_muted"] as? String)?.let { prefs.putString("theme_text_muted", it) }

        // Timestamp последнего открытия приложения (ISO 8601) для пересчёта away
        (args["last_opened_at"] as? String)?.let { prefs.putString("last_opened_at", it) }

        prefs.apply()
    }

    /**
     * Шлёт broadcast ACTION_APPWIDGET_UPDATE на все активные экземпляры виджета.
     */
    private fun triggerWidgetUpdate() {
        val manager = AppWidgetManager.getInstance(this)
        val ids = manager.getAppWidgetIds(
            ComponentName(this, KaizenWidgetProvider::class.java)
        )
        val intent = Intent(this, KaizenWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        sendBroadcast(intent)
    }
}
