// AppDelegate для Kaizen Runner.
// Регистрирует MethodChannel 'kaizen/widget' → методы для виджета.
//
// [iOS-UNVERIFIED] — не проверено без Mac/Xcode.
//
// Методы MethodChannel:
//   • updateWidget   ← Flutter: все поля §8 WIDGET.md → App Group UserDefaults
//                     + WidgetCenter.shared.reloadAllTimelines().
//   • getLaunchAction → Flutter: cold start — возвращает {action, date?} или nil
//                     (если запущены через URL scheme kaizen:// из виджета).
//                     Read-once: после возврата pending action сбрасывается.
//
// Deep-link flow:
//   COLD START (приложение не запущено):
//     1. WidgetKit вызывает widgetURL/Link → открывает Runner с URL kaizen://...
//     2. application(_:open:options:) сохраняет action/date как pending.
//     3. Flutter стартует, вызывает getLaunchAction → получает pending и очищает.
//
//   WARM START (приложение уже открыто):
//     1. WidgetKit вызывает widgetURL/Link → вызывает application(_:open:options:).
//     2. Мы сразу зовём channel.invokeMethod("onWidgetAction", map).
//
// URL scheme: kaizen://
//   kaizen://widget/today     → open_today
//   kaizen://widget/day?date= → open_day + date
//   kaizen://add-task         → add_task
//   (любой другой path)       → open_today (фоллбэк)
//
// Требования к Xcode-проекту:
//   - Runner target: URL Type, identifier com.kaizen.app, scheme kaizen.
//   - App Groups: group.com.kaizen.app (Runner + KaizenWidget Extension).
//   (Подробнее: docs/SETUP-ios-widget.md)

import Flutter
import UIKit
import WidgetKit   // [iOS-UNVERIFIED] WidgetKit доступен с iOS 14+

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    // Suite name App Group — должен совпадать с Provider.swift в KaizenWidget extension.
    private let kAppGroupSuiteName = "group.com.kaizen.app"
    private let kChannelName       = "kaizen/widget"

    // Pending action из cold-start URL (читается ровно один раз через getLaunchAction).
    // [iOS-UNVERIFIED]
    private var pendingAction: String? = nil
    private var pendingDate: String?   = nil

    // Ссылка на канал для invokeMethod при warm start.
    private var widgetChannel: FlutterMethodChannel? = nil

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Проверяем URL из launchOptions (cold start через URL scheme)
        // [iOS-UNVERIFIED]
        if let url = launchOptions?[.url] as? URL {
            parseWidgetURL(url, warm: false)
        }
        let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        return result
    }

    // Обработка URL scheme kaizen:// при открытии из виджета.
    // Вызывается и при cold start (через launchOptions выше) и при warm start (здесь).
    // [iOS-UNVERIFIED]
    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        parseWidgetURL(url, warm: widgetChannel != nil)
        return true
    }

    // [iOS-UNVERIFIED] FlutterImplicitEngineBridge вызывается после инициализации движка.
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }
        let channel = FlutterMethodChannel(
            name: kChannelName,
            binaryMessenger: controller.binaryMessenger
        )
        widgetChannel = channel

        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "updateWidget":
                self.handleUpdateWidget(call: call, result: result)
            case "getLaunchAction":
                // Cold start: возвращаем pending action и очищаем (read-once).
                // [iOS-UNVERIFIED]
                if let action = self.pendingAction {
                    var map: [String: Any] = ["action": action]
                    if let date = self.pendingDate { map["date"] = date }
                    self.pendingAction = nil
                    self.pendingDate   = nil
                    result(map)
                } else {
                    result(nil)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Парсинг URL kaizen://

    // [iOS-UNVERIFIED]
    // Примеры URL из виджета:
    //   kaizen://widget/today           → open_today
    //   kaizen://widget/day?date=2026-06-20 → open_day
    //   kaizen://add-task               → add_task
    private func parseWidgetURL(_ url: URL, warm: Bool) {
        guard url.scheme == "kaizen" else { return }

        let host = url.host ?? ""
        let path = url.path  // e.g. "/today", "/day", ""

        var action: String
        var date: String? = nil

        if host == "add-task" {
            action = "add_task"
        } else if host == "widget" {
            if path.hasPrefix("/day") {
                action = "open_day"
                // Парсим ?date= из query
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                date = components?.queryItems?.first(where: { $0.name == "date" })?.value
            } else {
                // /today или любой другой путь → open_today
                action = "open_today"
            }
        } else {
            // Неизвестный host → open_today как фоллбэк
            action = "open_today"
        }

        if warm, let channel = widgetChannel {
            // Warm start: сразу передаём во Flutter.
            var map: [String: Any] = ["action": action]
            if let d = date { map["date"] = d }
            channel.invokeMethod("onWidgetAction", arguments: map)
        } else {
            // Cold start: сохраняем pending.
            pendingAction = action
            pendingDate   = date
        }
    }

    // MARK: - Обработчик 'updateWidget'

    // [iOS-UNVERIFIED] Записывает поля §8 WIDGET.md в App Group UserDefaults,
    // затем просит WidgetKit перезагрузить все timelines.
    private func handleUpdateWidget(call: FlutterMethodCall, result: FlutterResult) {
        guard
            let args = call.arguments as? [String: Any],
            let ud = UserDefaults(suiteName: kAppGroupSuiteName)
        else {
            result(FlutterError(
                code: "WIDGET_ERROR",
                message: "App Group UserDefaults not available: \(kAppGroupSuiteName)",
                details: nil
            ))
            return
        }

        // Записываем все поля из payload §8 WIDGET.md.
        // Тип каждого поля зафиксирован в dart/widget_service.dart:
        //   String-поля: next_items, streak, kai_emotion, theme_*, last_opened_at, main_progress
        //   Int-поля:    main_done, main_total, is_harsh (0/1)

        let stringKeys = [
            "next_items", "streak", "kai_emotion",
            "theme_accent", "theme_bg", "theme_surface", "theme_text", "theme_text_muted",
            "last_opened_at", "main_progress",
        ]
        for key in stringKeys {
            if let val = args[key] as? String {
                ud.set(val, forKey: key)
            }
        }

        let intKeys = ["main_done", "main_total", "is_harsh"]
        for key in intKeys {
            if let val = args[key] as? Int {
                ud.set(val, forKey: key)
            }
        }

        ud.synchronize()

        // Перезагружаем timeline виджета — без этого WidgetKit не увидит новые данные.
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }

        result(nil) // успех
    }
}
