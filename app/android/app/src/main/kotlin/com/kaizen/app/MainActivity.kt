package com.kaizen.app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Точка входа Flutter-активности.
 * Слушает MethodChannel "kaizen/widget" → метод "updateWidget" и сохраняет
 * весь расширенный payload (Фаза 1+2) в SharedPreferences "kaizen_widget",
 * затем шлёт broadcast на обновление всех экземпляров виджета.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "kaizen/widget"
    private val prefsName = "kaizen_widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "updateWidget") {
                    saveWidgetData(call.arguments as? Map<*, *>)
                    triggerWidgetUpdate()
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
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
