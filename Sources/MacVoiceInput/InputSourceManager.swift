import Carbon
import Foundation

struct InputSourceSnapshot {
    let source: TISInputSource
}

enum InputSourceManager {
    static func currentInputSource() -> InputSourceSnapshot? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        return InputSourceSnapshot(source: source)
    }

    static func temporarilySelectASCIIInputIfNeeded() -> InputSourceSnapshot? {
        guard let current = currentInputSource() else { return nil }
        guard isCJKInputSource(current.source) else { return current }
        guard let ascii = asciiInputSource() else { return current }
        TISSelectInputSource(ascii)
        return current
    }

    static func restore(_ snapshot: InputSourceSnapshot?) {
        guard let snapshot else { return }
        TISSelectInputSource(snapshot.source)
    }

    private static func isCJKInputSource(_ source: TISInputSource) -> Bool {
        let languages = propertyValue(kTISPropertyInputSourceLanguages, for: source, as: [String].self) ?? []
        if languages.contains(where: { $0.hasPrefix("zh") || $0.hasPrefix("ja") || $0.hasPrefix("ko") }) {
            return true
        }
        let sourceID = propertyValue(kTISPropertyInputSourceID, for: source, as: String.self) ?? ""
        return ["Pinyin", "Kotoeri", "Japanese", "Hangul", "SCIM", "TCIM"].contains(where: sourceID.localizedCaseInsensitiveContains)
    }

    private static func asciiInputSource() -> TISInputSource? {
        let properties = [
            kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as Any,
            kTISPropertyInputSourceIsSelectCapable as String: true
        ] as CFDictionary
        guard let list = TISCreateInputSourceList(properties, false)?.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }
        if let abc = list.first(where: { source in
            propertyValue(kTISPropertyInputSourceID, for: source, as: String.self) == "com.apple.keylayout.ABC"
        }) {
            return abc
        }
        return list.first(where: { source in
            let sourceID = propertyValue(kTISPropertyInputSourceID, for: source, as: String.self) ?? ""
            return sourceID == "com.apple.keylayout.US"
        })
    }

    private static func propertyValue<T>(_ key: CFString, for source: TISInputSource, as _: T.Type) -> T? {
        guard let rawPointer = TISGetInputSourceProperty(source, key) else {
            return nil
        }
        return Unmanaged<AnyObject>.fromOpaque(rawPointer).takeUnretainedValue() as? T
    }
}
