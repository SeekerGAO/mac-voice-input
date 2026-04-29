import AppKit
import Foundation

struct AppContext {
    enum Category {
        case chat
        case email
        case code
        case terminal
        case notes
        case browser
        case generic
    }

    let appName: String
    let bundleIdentifier: String?
    let category: Category

    static var current: AppContext? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let appName = app.localizedName else {
            return nil
        }
        let bundleIdentifier = app.bundleIdentifier
        return AppContext(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            category: category(for: appName, bundleIdentifier: bundleIdentifier)
        )
    }

    private static func category(for appName: String, bundleIdentifier: String?) -> Category {
        let haystack = "\(bundleIdentifier ?? "") \(appName)".lowercased()
        if containsAny(haystack, ["mail", "outlook", "superhuman", "spark"]) {
            return .email
        }
        if containsAny(haystack, ["slack", "discord", "teams", "wechat", "weixin", "telegram", "whatsapp", "messages"]) {
            return .chat
        }
        if containsAny(haystack, ["xcode", "cursor", "visualstudiocode", "vscode", "jetbrains", "intellij", "pycharm", "webstorm", "sublime"]) {
            return .code
        }
        if containsAny(haystack, ["terminal", "iterm", "warp"]) {
            return .terminal
        }
        if containsAny(haystack, ["notes", "notion", "obsidian", "bear", "evernote", "onenote"]) {
            return .notes
        }
        if containsAny(haystack, ["safari", "chrome", "firefox", "edge", "arc"]) {
            return .browser
        }
        return .generic
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }
}
