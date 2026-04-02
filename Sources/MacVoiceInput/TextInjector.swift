import AppKit
import ApplicationServices
import Foundation

struct PasteboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]
}

@MainActor
final class TextInjector {
    func inject(_ text: String) async {
        let pasteboard = NSPasteboard.general
        let snapshot = snapshotPasteboard(pasteboard)
        let inputSource = InputSourceManager.temporarilySelectASCIIInputIfNeeded()

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        try? await Task.sleep(for: .milliseconds(80))
        postPasteShortcut()
        try? await Task.sleep(for: .milliseconds(180))

        InputSourceManager.restore(inputSource)
        restorePasteboard(snapshot, to: pasteboard)
    }

    private func snapshotPasteboard(_ pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
        return PasteboardSnapshot(items: items)
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

    private func postPasteShortcut() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let keyCode: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
