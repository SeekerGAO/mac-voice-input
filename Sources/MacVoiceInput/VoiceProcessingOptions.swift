import Foundation

enum VoiceOutputMode: String, CaseIterable, Codable, Identifiable {
    case rawTranscript
    case conservativeCorrection
    case polishedMessage
    case email
    case bulletList
    case translation
    case editSelectedText

    var id: String { rawValue }

    var requiresLLM: Bool {
        self != .rawTranscript
    }

    func title(for language: LanguageOption) -> String {
        switch (self, language) {
        case (.rawTranscript, .english): return "Raw Transcript"
        case (.rawTranscript, .simplifiedChinese): return "原始转写"
        case (.rawTranscript, .traditionalChinese): return "原始轉寫"
        case (.rawTranscript, .japanese): return "元の文字起こし"
        case (.rawTranscript, .korean): return "원본 받아쓰기"

        case (.conservativeCorrection, .english): return "Light Correction"
        case (.conservativeCorrection, .simplifiedChinese): return "轻度纠错"
        case (.conservativeCorrection, .traditionalChinese): return "輕度糾錯"
        case (.conservativeCorrection, .japanese): return "軽い補正"
        case (.conservativeCorrection, .korean): return "가벼운 교정"

        case (.polishedMessage, .english): return "Polished Message"
        case (.polishedMessage, .simplifiedChinese): return "润色成消息"
        case (.polishedMessage, .traditionalChinese): return "潤飾成訊息"
        case (.polishedMessage, .japanese): return "自然なメッセージ"
        case (.polishedMessage, .korean): return "다듬은 메시지"

        case (.email, .english): return "Email Tone"
        case (.email, .simplifiedChinese): return "邮件语气"
        case (.email, .traditionalChinese): return "郵件語氣"
        case (.email, .japanese): return "メール文体"
        case (.email, .korean): return "이메일 문체"

        case (.bulletList, .english): return "Bullet List"
        case (.bulletList, .simplifiedChinese): return "项目符号/步骤"
        case (.bulletList, .traditionalChinese): return "項目符號/步驟"
        case (.bulletList, .japanese): return "箇条書き"
        case (.bulletList, .korean): return "글머리 기호"

        case (.translation, .english): return "Translation"
        case (.translation, .simplifiedChinese): return "翻译"
        case (.translation, .traditionalChinese): return "翻譯"
        case (.translation, .japanese): return "翻訳"
        case (.translation, .korean): return "번역"

        case (.editSelectedText, .english): return "Edit Selected Text"
        case (.editSelectedText, .simplifiedChinese): return "编辑选中文本"
        case (.editSelectedText, .traditionalChinese): return "編輯選中文本"
        case (.editSelectedText, .japanese): return "選択テキストを編集"
        case (.editSelectedText, .korean): return "선택한 텍스트 편집"
        }
    }
}

struct VoiceProcessingOptions {
    let outputMode: VoiceOutputMode
    let sourceLanguage: LanguageOption
    let translationTarget: LanguageOption
    let personalDictionaryTerms: [String]
    let selectedText: String?

    func withSelectedText(_ selectedText: String?) -> VoiceProcessingOptions {
        VoiceProcessingOptions(
            outputMode: outputMode,
            sourceLanguage: sourceLanguage,
            translationTarget: translationTarget,
            personalDictionaryTerms: personalDictionaryTerms,
            selectedText: selectedText
        )
    }
}
