import AppKit
import ApplicationServices
import Foundation

struct PasteboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]
    let changeCount: Int
}

@MainActor
final class TextInjector {
    func inject(_ text: String) async {
        let pasteboard = NSPasteboard.general
        let snapshot = snapshotPasteboard(pasteboard)
        let inputSource = InputSourceManager.temporarilySelectASCIIInputIfNeeded()
        var injectedChangeCount: Int?

        defer {
            InputSourceManager.restore(inputSource)
            restorePasteboard(snapshot, injectedChangeCount: injectedChangeCount, to: pasteboard)
        }

        try? await Task.sleep(for: .milliseconds(60))
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        injectedChangeCount = pasteboard.changeCount

        try? await Task.sleep(for: .milliseconds(120))
        postPasteShortcut()
        try? await Task.sleep(for: .milliseconds(140))
        postPasteShortcut()
        try? await Task.sleep(for: .milliseconds(220))

        guard pasteboard.changeCount == injectedChangeCount else { return }
    }

    private func snapshotPasteboard(_ pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
        return PasteboardSnapshot(items: items, changeCount: pasteboard.changeCount)
    }

    private func restorePasteboard(_ snapshot: PasteboardSnapshot, injectedChangeCount: Int?, to pasteboard: NSPasteboard) {
        guard let injectedChangeCount, pasteboard.changeCount == injectedChangeCount else { return }
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else { return }
        let restoredItems = snapshot.items.map { itemData -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restoredItems)
    }

    private func postPasteShortcut() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let keyCode: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        down?.flags = .maskCommand
        down?.setIntegerValueField(.keyboardEventAutorepeat, value: 0)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        up?.flags = .maskCommand
        up?.setIntegerValueField(.keyboardEventAutorepeat, value: 0)
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
