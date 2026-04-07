# 开发说明

## 构建目标

- `make build`：编译 SwiftPM 可执行文件，打包 `.app`，并进行 ad-hoc 签名
- `make run`：构建并启动生成的应用
- `make install`：将应用复制到 `/Applications`
- `./scripts/release_package.sh v1.0.0`：在 `dist/` 中生成可分发的 `.dmg`、`.zip` 及其校验文件

## CI/CD

- `.github/workflows/ci.yml`：在 `push main` 和 `pull_request` 时构建应用，并上传 CI 构建产物
- `.github/workflows/continuous-release.yml`：在每次推送到 `main` 时构建 DMG，并更新一个可直接下载的滚动预发布版本
- `.github/workflows/release.yml`：在推送 tag 时构建并发布正式版本到 GitHub Releases
- `scripts/release_package.sh`：发布工作流共用的打包脚本

## 发布流程

1. 将验证通过的代码合并到 `main`
2. 创建并推送语义化版本 tag，例如 `v1.0.0`
3. 等待 `Release` GitHub Actions 工作流完成
4. 从 GitHub Releases 下载生成的安装包，并做一次冒烟测试

正式版本产物：

- `MacVoiceInput-<tag>.dmg`
- `MacVoiceInput-<tag>.dmg.sha256`
- `MacVoiceInput-<tag>.zip`
- `MacVoiceInput-<tag>.zip.sha256`

滚动预发布产物：

- `MacVoiceInput-main-latest.dmg`
- `MacVoiceInput-main-latest.dmg.sha256`
- `MacVoiceInput-main-latest.zip`
- `MacVoiceInput-main-latest.zip.sha256`

如需提供更顺滑的终端用户安装体验，可以通过 GitHub 仓库 secrets 启用 Apple 签名和公证。

## 运行时架构

- `AppDelegate.swift`：菜单栏生命周期、权限流程、录音状态机
- `SpeechRecognizerService.swift`：语音权限、音频引擎、流式识别
- `HotkeyMonitor.swift`：全局 `Fn` 键监听
- `TextInjector.swift`：剪贴板快照、临时替换、模拟粘贴快捷键
- `FloatingPanel*`：录音 HUD 的模型、视图和面板宿主
- `SettingsStore.swift` 与 `KeychainStore.swift`：配置持久化与 API Key 存储

## 本地验证清单

- `make build` 构建成功
- 应用可从 `.build/release/MacVoiceInput.app` 正常启动
- 能从权限诊断菜单中完成授权
- 按住 `Fn` 时显示录音浮窗并开始识别
- 松开 `Fn` 时停止识别并向当前输入框注入文本
- 配置有效的 OpenAI 兼容接口后，LLM 纠错可以正常工作

## 已知限制

- 全局热键监听依赖 macOS 的“辅助功能”和“输入监控”权限
- 语音识别效果必须在真实机器上验证，不能只依赖 CI
- 本地构建默认使用 ad-hoc 签名，如果误打开旧的应用副本，容易误判为代码问题

## 后续建议

- 为首次授权流程增加可重复执行的人工 QA 清单
- 采集真实截图并保存到 `docs/images/`
- 为设置解析、权限状态映射等非 AppKit 逻辑增加轻量级单元测试
