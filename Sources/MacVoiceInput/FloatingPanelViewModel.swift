import AppKit
import Foundation

@MainActor
final class FloatingPanelViewModel: ObservableObject {
    enum Status {
        case listening
        case refining
        case message(String)
    }

    @Published var transcript: String = ""
    @Published var barLevels: [CGFloat] = Array(repeating: 0.2, count: 5)
    @Published var status: Status = .listening

    var displayText: String {
        switch status {
        case .listening:
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "正在聆听…" : trimmed
        case .refining:
            return "Refining…"
        case .message(let text):
            return text
        }
    }

    func estimatedWidth() -> CGFloat {
        let font = NSFont.systemFont(ofSize: 17, weight: .medium)
        let width = (displayText as NSString).size(withAttributes: [.font: font]).width
        return min(max(width + 120, 160), 560)
    }
}
