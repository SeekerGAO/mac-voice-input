import ApplicationServices
import Foundation

enum RecordingMode: String, CaseIterable, Identifiable {
    case holdToRecord
    case toggleToRecord

    var id: String { rawValue }

    func title(for language: LanguageOption) -> String {
        switch (self, language) {
        case (.holdToRecord, .english): return "Hold to Record"
        case (.holdToRecord, .simplifiedChinese): return "按住录音"
        case (.holdToRecord, .traditionalChinese): return "按住錄音"
        case (.holdToRecord, .japanese): return "押している間だけ録音"
        case (.holdToRecord, .korean): return "누르는 동안 녹음"

        case (.toggleToRecord, .english): return "Tap to Start/Stop"
        case (.toggleToRecord, .simplifiedChinese): return "按一下开始/结束"
        case (.toggleToRecord, .traditionalChinese): return "按一下開始/結束"
        case (.toggleToRecord, .japanese): return "押して開始/停止"
        case (.toggleToRecord, .korean): return "눌러서 시작/중지"
        }
    }
}

enum ActivationHotkey: String, CaseIterable, Identifiable {
    case fn
    case rightOption
    case rightControl

    var id: String { rawValue }

    var keyCode: Int64 {
        switch self {
        case .fn: return 63
        case .rightOption: return 61
        case .rightControl: return 62
        }
    }

    var activeFlag: CGEventFlags {
        switch self {
        case .fn: return .maskSecondaryFn
        case .rightOption: return .maskAlternate
        case .rightControl: return .maskControl
        }
    }

    func title(for language: LanguageOption) -> String {
        switch (self, language) {
        case (.fn, _): return "Fn"
        case (.rightOption, .english): return "Right Option"
        case (.rightOption, .simplifiedChinese): return "右 Option"
        case (.rightOption, .traditionalChinese): return "右 Option"
        case (.rightOption, .japanese): return "右 Option"
        case (.rightOption, .korean): return "오른쪽 Option"

        case (.rightControl, .english): return "Right Control"
        case (.rightControl, .simplifiedChinese): return "右 Control"
        case (.rightControl, .traditionalChinese): return "右 Control"
        case (.rightControl, .japanese): return "右 Control"
        case (.rightControl, .korean): return "오른쪽 Control"
        }
    }
}
