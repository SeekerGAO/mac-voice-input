import AppKit
import ApplicationServices
import Foundation

@MainActor
final class SelectedTextReader {
    func readSelectedText() async -> String? {
        let pasteboard = NSPasteboard.general
        let snapshot = snapshotPasteboard(pasteboard)
        let originalChangeCount = pasteboard.changeCount

        postCopyShortcut()
        try? await Task.sleep(for: .milliseconds(180))

        let selectedText = pasteboard.changeCount != originalChangeCount
            ? pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        restorePasteboard(snapshot, to: pasteboard)

        guard let selectedText, !selectedText.isEmpty else { return nil }
        return selectedText
    }

    private func snapshotPasteboard(_ pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
        return PasteboardSnapshot(items: items, changeCount: pasteboard.changeCount)
    }

    private func restorePasteboard(_ snapshot: PasteboardSnapshot, to pasteboard: NSPasteboard) {
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

    private func postCopyShortcut() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let keyCode: CGKeyCode = 8
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
