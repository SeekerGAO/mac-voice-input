import Foundation

struct AppStrings {
    let language: LanguageOption

    var holdFnTooltip: String {
        switch language {
        case .english: return "Hold Fn to record voice input"
        case .simplifiedChinese: return "按住 Fn 开始语音输入"
        case .traditionalChinese: return "按住 Fn 開始語音輸入"
        case .japanese: return "Fn を押し続けて音声入力"
        case .korean: return "Fn 키를 길게 눌러 음성 입력"
        }
    }

    var listeningPlaceholder: String {
        switch language {
        case .english: return "Listening…"
        case .simplifiedChinese: return "正在聆听…"
        case .traditionalChinese: return "正在聆聽…"
        case .japanese: return "聞き取り中…"
        case .korean: return "듣는 중…"
        }
    }

    var refiningText: String {
        switch language {
        case .english: return "Refining…"
        case .simplifiedChinese: return "正在润色识别结果…"
        case .traditionalChinese: return "正在潤飾辨識結果…"
        case .japanese: return "補正中…"
        case .korean: return "보정 중…"
        }
    }

    var permissionDiagnostics: String {
        switch language {
        case .english: return "Permission Diagnostics"
        case .simplifiedChinese: return "权限诊断"
        case .traditionalChinese: return "權限診斷"
        case .japanese: return "権限診断"
        case .korean: return "권한 진단"
        }
    }

    var permissionAllGood: String {
        switch language {
        case .english: return "All required permissions are ready"
        case .simplifiedChinese: return "所需权限已全部就绪"
        case .traditionalChinese: return "所需權限已全部就緒"
        case .japanese: return "必要な権限はすべて準備完了です"
        case .korean: return "필요한 권한이 모두 준비되었습니다"
        }
    }

    var permissionIssuesFound: String {
        switch language {
        case .english: return "Some permissions still need attention"
        case .simplifiedChinese: return "仍有权限需要处理"
        case .traditionalChinese: return "仍有權限需要處理"
        case .japanese: return "まだ権限の確認が必要です"
        case .korean: return "아직 확인이 필요한 권한이 있습니다"
        }
    }

    var openPrivacySettings: String {
        switch language {
        case .english: return "Open Privacy Settings"
        case .simplifiedChinese: return "打开系统隐私设置"
        case .traditionalChinese: return "打開系統隱私設定"
        case .japanese: return "プライバシー設定を開く"
        case .korean: return "개인정보 보호 설정 열기"
        }
    }

    var openFirstRunGuide: String {
        switch language {
        case .english: return "Open First-Run Guide"
        case .simplifiedChinese: return "打开首次引导"
        case .traditionalChinese: return "打開首次引導"
        case .japanese: return "初回ガイドを開く"
        case .korean: return "첫 실행 가이드 열기"
        }
    }

    var rebuildMonitoring: String {
        switch language {
        case .english: return "Rebuild Monitoring"
        case .simplifiedChinese: return "重建监听"
        case .traditionalChinese: return "重建監聽"
        case .japanese: return "監視を再構築"
        case .korean: return "모니터링 다시 초기화"
        }
    }

    var refreshPermissionState: String {
        switch language {
        case .english: return "Reinitialize Permission State"
        case .simplifiedChinese: return "重新初始化权限状态"
        case .traditionalChinese: return "重新初始化權限狀態"
        case .japanese: return "権限状態を再初期化"
        case .korean: return "권한 상태 다시 초기화"
        }
    }

    var monitoringRebuilt: String {
        switch language {
        case .english: return "Monitoring has been rebuilt."
        case .simplifiedChinese: return "监听已重建。"
        case .traditionalChinese: return "監聽已重建。"
        case .japanese: return "監視を再構築しました。"
        case .korean: return "모니터링을 다시 초기화했습니다."
        }
    }

    var permissionStateRefreshed: String {
        switch language {
        case .english: return "Permission state has been refreshed."
        case .simplifiedChinese: return "权限状态已刷新。"
        case .traditionalChinese: return "權限狀態已重新整理。"
        case .japanese: return "権限状態を更新しました。"
        case .korean: return "권한 상태를 새로 고쳤습니다."
        }
    }

    var languageMenu: String {
        switch language {
        case .english: return "Language"
        case .simplifiedChinese: return "语言"
        case .traditionalChinese: return "語言"
        case .japanese: return "言語"
        case .korean: return "언어"
        }
    }

    var llmRefinement: String {
        switch language {
        case .english: return "LLM Refinement"
        case .simplifiedChinese: return "LLM 优化"
        case .traditionalChinese: return "LLM 優化"
        case .japanese: return "LLM 補正"
        case .korean: return "LLM 보정"
        }
    }

    var enableRefinement: String {
        switch language {
        case .english: return "Enable Refinement"
        case .simplifiedChinese: return "启用优化"
        case .traditionalChinese: return "啟用優化"
        case .japanese: return "補正を有効化"
        case .korean: return "보정 사용"
        }
    }

    var settings: String {
        switch language {
        case .english: return "Settings…"
        case .simplifiedChinese: return "设置…"
        case .traditionalChinese: return "設定…"
        case .japanese: return "設定…"
        case .korean: return "설정…"
        }
    }

    var permissionsRequired: String {
        switch language {
        case .english: return "Permissions required before recording works"
        case .simplifiedChinese: return "录音前需要先完成权限授权"
        case .traditionalChinese: return "錄音前需要先完成權限授權"
        case .japanese: return "録音前に権限付与が必要です"
        case .korean: return "녹음 전에 권한 허용이 필요합니다"
        }
    }

    var quit: String {
        switch language {
        case .english: return "Quit"
        case .simplifiedChinese: return "退出"
        case .traditionalChinese: return "退出"
        case .japanese: return "終了"
        case .korean: return "종료"
        }
    }

    var firstRunTitle: String {
        switch language {
        case .english: return "First-Run Guide"
        case .simplifiedChinese: return "首次启动引导"
        case .traditionalChinese: return "首次啟動引導"
        case .japanese: return "初回起動ガイド"
        case .korean: return "첫 실행 안내"
        }
    }

    var firstRunHeadline: String {
        switch language {
        case .english: return "Complete the permissions setup first"
        case .simplifiedChinese: return "首次启动需要完成权限设置"
        case .traditionalChinese: return "首次啟動需要完成權限設定"
        case .japanese: return "最初に権限設定を完了してください"
        case .korean: return "먼저 권한 설정을 완료하세요"
        }
    }

    var firstRunIntro: String {
        switch language {
        case .english: return "After these 3 steps, Fn voice input will be ready to use."
        case .simplifiedChinese: return "完成下面 3 步后，就可以正常使用 Fn 语音输入。"
        case .traditionalChinese: return "完成下面 3 步後，就可以正常使用 Fn 語音輸入。"
        case .japanese: return "次の 3 ステップを完了すると、Fn 音声入力が使えるようになります。"
        case .korean: return "아래 3단계를 완료하면 Fn 음성 입력을 사용할 수 있습니다."
        }
    }

    var apiBaseURLLabel: String {
        switch language {
        case .english: return "API Base URL"
        case .simplifiedChinese: return "API Base URL"
        case .traditionalChinese: return "API Base URL"
        case .japanese: return "API Base URL"
        case .korean: return "API Base URL"
        }
    }

    var apiKeyLabel: String {
        switch language {
        case .english: return "API Key"
        case .simplifiedChinese: return "API Key"
        case .traditionalChinese: return "API Key"
        case .japanese: return "API Key"
        case .korean: return "API Key"
        }
    }

    var clearAPIKey: String {
        switch language {
        case .english: return "Clear API Key"
        case .simplifiedChinese: return "清空 API Key"
        case .traditionalChinese: return "清空 API Key"
        case .japanese: return "API Key を消去"
        case .korean: return "API Key 지우기"
        }
    }

    var confirmClearAPIKeyTitle: String {
        switch language {
        case .english: return "Clear stored API Key?"
        case .simplifiedChinese: return "确认清空已保存的 API Key？"
        case .traditionalChinese: return "確認清空已儲存的 API Key？"
        case .japanese: return "保存済みの API Key を消去しますか？"
        case .korean: return "저장된 API Key를 지우시겠습니까?"
        }
    }

    var confirmClearAPIKeyMessage: String {
        switch language {
        case .english: return "This removes the API Key from the field and from Keychain."
        case .simplifiedChinese: return "这会同时清空输入框中的 API Key，并从钥匙串中删除。"
        case .traditionalChinese: return "這會同時清空輸入欄中的 API Key，並從鑰匙圈中刪除。"
        case .japanese: return "入力欄の API Key とキーチェーン内の保存内容を削除します。"
        case .korean: return "입력 필드의 API Key와 키체인 저장 내용을 함께 삭제합니다."
        }
    }

    var clearAction: String {
        switch language {
        case .english: return "Clear"
        case .simplifiedChinese: return "清空"
        case .traditionalChinese: return "清空"
        case .japanese: return "消去"
        case .korean: return "지우기"
        }
    }

    var cancelAction: String {
        switch language {
        case .english: return "Cancel"
        case .simplifiedChinese: return "取消"
        case .traditionalChinese: return "取消"
        case .japanese: return "キャンセル"
        case .korean: return "취소"
        }
    }

    var modelLabel: String {
        switch language {
        case .english: return "Model"
        case .simplifiedChinese: return "模型"
        case .traditionalChinese: return "模型"
        case .japanese: return "モデル"
        case .korean: return "모델"
        }
    }

    var apiBaseURLPlaceholder: String {
        "https://api.openai.com/v1"
    }

    var apiKeyPlaceholder: String {
        "sk-..."
    }

    var modelPlaceholder: String {
        switch language {
        case .english: return "gpt-4.1-mini"
        case .simplifiedChinese: return "例如 gpt-4.1-mini"
        case .traditionalChinese: return "例如 gpt-4.1-mini"
        case .japanese: return "例: gpt-4.1-mini"
        case .korean: return "예: gpt-4.1-mini"
        }
    }

    var configureAPISettingsFirst: String {
        switch language {
        case .english: return "Configure API settings first"
        case .simplifiedChinese: return "请先完成 API 配置"
        case .traditionalChinese: return "請先完成 API 設定"
        case .japanese: return "先に API 設定を完了してください"
        case .korean: return "먼저 API 설정을 완료하세요"
        }
    }

    var completePermissionsFirst: String {
        switch language {
        case .english: return "Complete permissions setup first"
        case .simplifiedChinese: return "请先完成权限授权"
        case .traditionalChinese: return "請先完成權限授權"
        case .japanese: return "先に権限設定を完了してください"
        case .korean: return "먼저 권한 설정을 완료하세요"
        }
    }

    var llmTimedOutFallback: String {
        switch language {
        case .english: return "LLM refinement timed out, using raw transcript"
        case .simplifiedChinese: return "LLM 优化超时，已回退到原始识别结果"
        case .traditionalChinese: return "LLM 優化逾時，已回退到原始辨識結果"
        case .japanese: return "LLM 補正がタイムアウトしたため、元の認識結果を使用します"
        case .korean: return "LLM 보정이 시간 초과되어 원본 인식 결과를 사용합니다"
        }
    }

    var llmFailedFallback: String {
        switch language {
        case .english: return "LLM refinement failed, using raw transcript"
        case .simplifiedChinese: return "LLM 优化失败，已回退到原始识别结果"
        case .traditionalChinese: return "LLM 優化失敗，已回退到原始辨識結果"
        case .japanese: return "LLM 補正に失敗したため、元の認識結果を使用します"
        case .korean: return "LLM 보정에 실패하여 원본 인식 결과를 사용합니다"
        }
    }

    var permissionAccessHint: String {
        switch language {
        case .english: return "Grant Accessibility and Input Monitoring"
        case .simplifiedChinese: return "请授予辅助功能和输入监控权限"
        case .traditionalChinese: return "請授予輔助使用與輸入監控權限"
        case .japanese: return "アクセシビリティと入力監視を許可してください"
        case .korean: return "손쉬운 사용 및 입력 모니터링 권한을 허용하세요"
        }
    }

    var requestPermissionsButton: String {
        switch language {
        case .english: return "Request Microphone & Speech Permissions"
        case .simplifiedChinese: return "请求麦克风和语音识别权限"
        case .traditionalChinese: return "請求麥克風與語音辨識權限"
        case .japanese: return "マイクと音声認識の権限を要求"
        case .korean: return "마이크 및 음성 인식 권한 요청"
        }
    }

    var requestMediaPermissionsMenu: String {
        switch language {
        case .english: return "Request Mic & Speech Permissions"
        case .simplifiedChinese: return "请求麦克风和语音识别权限"
        case .traditionalChinese: return "請求麥克風與語音辨識權限"
        case .japanese: return "マイクと音声認識の権限を要求"
        case .korean: return "마이크 및 음성 인식 권한 요청"
        }
    }

    var requestAccessibilityPermissionMenu: String {
        switch language {
        case .english: return "Request Accessibility Permission"
        case .simplifiedChinese: return "请求辅助功能权限"
        case .traditionalChinese: return "請求輔助使用權限"
        case .japanese: return "アクセシビリティ権限を要求"
        case .korean: return "손쉬운 사용 권한 요청"
        }
    }

    var requestInputMonitoringPermissionMenu: String {
        switch language {
        case .english: return "Request Input Monitoring Permission"
        case .simplifiedChinese: return "请求输入监控权限"
        case .traditionalChinese: return "請求輸入監控權限"
        case .japanese: return "入力監視の権限を要求"
        case .korean: return "입력 모니터링 권한 요청"
        }
    }

    var refreshingPermissions: String {
        switch language {
        case .english: return "Refreshing permission state…"
        case .simplifiedChinese: return "正在刷新权限状态…"
        case .traditionalChinese: return "正在重新整理權限狀態…"
        case .japanese: return "権限状態を更新中…"
        case .korean: return "권한 상태를 새로 고치는 중…"
        }
    }

    func errorMessage(for error: Error) -> String {
        if let speechError = error as? SpeechRecognizerError {
            return speechError.message(for: language)
        }
        if let llmError = error as? LLMRefinerError {
            return llmError.message(for: language)
        }
        if let keychainError = error as? KeychainStoreError {
            return keychainError.message(for: language)
        }
        return formatUnknownErrorDetail(error.localizedDescription)
    }

    private func formatUnknownErrorDetail(_ detail: String) -> String {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackDetail = trimmed.isEmpty ? unknownErrorFallbackDetail : trimmed
        return "\(unknownErrorSummary)\n\(unknownErrorDetailPrefix): \(fallbackDetail)"
    }

    private var unknownErrorSummary: String {
        switch language {
        case .english: return "Something went wrong. Please try again."
        case .simplifiedChinese: return "操作出现问题，请重试。"
        case .traditionalChinese: return "操作出現問題，請重試。"
        case .japanese: return "問題が発生しました。もう一度お試しください。"
        case .korean: return "문제가 발생했습니다. 다시 시도하세요."
        }
    }

    private var unknownErrorDetailPrefix: String {
        switch language {
        case .english: return "Details"
        case .simplifiedChinese: return "详情"
        case .traditionalChinese: return "詳情"
        case .japanese: return "詳細"
        case .korean: return "상세 정보"
        }
    }

    private var unknownErrorFallbackDetail: String {
        switch language {
        case .english: return "No additional details."
        case .simplifiedChinese: return "没有更多详细信息。"
        case .traditionalChinese: return "沒有更多詳細資訊。"
        case .japanese: return "追加の詳細情報はありません。"
        case .korean: return "추가 상세 정보가 없습니다."
        }
    }
}

extension PermissionState {
    func title(for language: LanguageOption) -> String {
        switch (language, self) {
        case (_, .granted):
            switch language {
            case .english: return "Granted"
            case .simplifiedChinese: return "已授权"
            case .traditionalChinese: return "已授權"
            case .japanese: return "許可済み"
            case .korean: return "허용됨"
            }
        case (_, .denied):
            switch language {
            case .english: return "Denied"
            case .simplifiedChinese: return "已拒绝"
            case .traditionalChinese: return "已拒絕"
            case .japanese: return "拒否"
            case .korean: return "거부됨"
            }
        case (_, .notDetermined):
            switch language {
            case .english: return "Not Determined"
            case .simplifiedChinese: return "未决定"
            case .traditionalChinese: return "未決定"
            case .japanese: return "未決定"
            case .korean: return "미결정"
            }
        }
    }
}

extension SpeechRecognizerError {
    func message(for language: LanguageOption) -> String {
        switch (self, language) {
        case (.speechAuthorizationDenied, .english): return "Speech recognition permission was denied."
        case (.speechAuthorizationDenied, .simplifiedChinese): return "语音识别权限被拒绝。"
        case (.speechAuthorizationDenied, .traditionalChinese): return "語音辨識權限被拒絕。"
        case (.speechAuthorizationDenied, .japanese): return "音声認識の権限が拒否されました。"
        case (.speechAuthorizationDenied, .korean): return "음성 인식 권한이 거부되었습니다."

        case (.microphoneAuthorizationDenied, .english): return "Microphone permission was denied."
        case (.microphoneAuthorizationDenied, .simplifiedChinese): return "麦克风权限被拒绝。"
        case (.microphoneAuthorizationDenied, .traditionalChinese): return "麥克風權限被拒絕。"
        case (.microphoneAuthorizationDenied, .japanese): return "マイクの権限が拒否されました。"
        case (.microphoneAuthorizationDenied, .korean): return "마이크 권한이 거부되었습니다."

        case (.recognizerUnavailable, .english): return "Speech recognizer is unavailable for the selected language."
        case (.recognizerUnavailable, .simplifiedChinese): return "当前所选语言的语音识别不可用。"
        case (.recognizerUnavailable, .traditionalChinese): return "目前所選語言的語音辨識不可用。"
        case (.recognizerUnavailable, .japanese): return "選択した言語では音声認識を利用できません。"
        case (.recognizerUnavailable, .korean): return "선택한 언어에서는 음성 인식을 사용할 수 없습니다."
        }
    }
}

extension LLMRefinerError {
    func message(for language: LanguageOption) -> String {
        switch self {
        case .invalidBaseURL:
            switch language {
            case .english: return "Invalid API Base URL."
            case .simplifiedChinese: return "API Base URL 无效。"
            case .traditionalChinese: return "API Base URL 無效。"
            case .japanese: return "API Base URL が無効です。"
            case .korean: return "API Base URL이 올바르지 않습니다."
            }
        case .insecureBaseURL:
            switch language {
            case .english: return "Only HTTPS API endpoints are allowed, except localhost for local development."
            case .simplifiedChinese: return "除本地开发的 localhost 外，只允许使用 HTTPS 接口。"
            case .traditionalChinese: return "除本地開發的 localhost 外，只允許使用 HTTPS 介面。"
            case .japanese: return "ローカル開発の localhost を除き、HTTPS のみ利用できます。"
            case .korean: return "로컬 개발용 localhost를 제외하면 HTTPS 엔드포인트만 허용됩니다."
            }
        case .unsupportedBaseURLComponents:
            switch language {
            case .english: return "API Base URL must not include embedded credentials, query parameters, or fragments."
            case .simplifiedChinese: return "API Base URL 不能包含内嵌凭据、查询参数或片段。"
            case .traditionalChinese: return "API Base URL 不能包含內嵌憑證、查詢參數或片段。"
            case .japanese: return "API Base URL に埋め込み認証情報、クエリ、フラグメントは含められません。"
            case .korean: return "API Base URL에는 내장 자격 증명, 쿼리 파라미터, 프래그먼트를 포함할 수 없습니다."
            }
        case .badStatus(let statusCode):
            switch language {
            case .english: return "Server returned HTTP \(statusCode)."
            case .simplifiedChinese: return "服务端返回 HTTP \(statusCode)。"
            case .traditionalChinese: return "伺服器返回 HTTP \(statusCode)。"
            case .japanese: return "サーバーが HTTP \(statusCode) を返しました。"
            case .korean: return "서버가 HTTP \(statusCode)를 반환했습니다."
            }
        case .emptyResponse:
            switch language {
            case .english: return "Model response was empty."
            case .simplifiedChinese: return "模型返回内容为空。"
            case .traditionalChinese: return "模型返回內容為空。"
            case .japanese: return "モデルの応答が空でした。"
            case .korean: return "모델 응답이 비어 있습니다."
            }
        case .transcriptTooLong:
            switch language {
            case .english: return "Transcript is too long for refinement."
            case .simplifiedChinese: return "识别文本过长，无法进行优化。"
            case .traditionalChinese: return "辨識文字過長，無法進行優化。"
            case .japanese: return "認識結果が長すぎるため補正できません。"
            case .korean: return "인식 텍스트가 너무 길어 보정할 수 없습니다."
            }
        }
    }
}

extension KeychainStoreError {
    func message(for language: LanguageOption) -> String {
        switch self {
        case .unexpectedData:
            switch language {
            case .english: return "Stored Keychain data was invalid."
            case .simplifiedChinese: return "钥匙串中的数据无效。"
            case .traditionalChinese: return "鑰匙圈中的資料無效。"
            case .japanese: return "キーチェーン内のデータが無効です。"
            case .korean: return "키체인 데이터가 올바르지 않습니다."
            }
        case .unhandled(let status):
            switch language {
            case .english: return "Keychain operation failed with status \(status)."
            case .simplifiedChinese: return "钥匙串操作失败，状态码 \(status)。"
            case .traditionalChinese: return "鑰匙圈操作失敗，狀態碼 \(status)。"
            case .japanese: return "キーチェーン操作に失敗しました。ステータス \(status)。"
            case .korean: return "키체인 작업에 실패했습니다. 상태 코드 \(status)."
            }
        }
    }
}
