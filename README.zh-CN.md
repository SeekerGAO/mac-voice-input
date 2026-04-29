# MacVoiceInput

MacVoiceInput 是一个基于 Swift 和 Swift Package Manager 开发的 macOS 14+ 菜单栏语音输入应用。

使用已配置的触发键开始录音，然后将语音转写结果粘贴到当前聚焦的输入框中。应用使用 Apple Speech 框架进行流式识别，显示实时波形和转写浮窗，并可选接入兼容 OpenAI 的大模型接口对识别结果进行保守纠错。

英文说明见 [README.md](./README.md)。

## 功能特性

- 纯菜单栏应用，启用 `LSUIElement`，不显示 Dock 图标
- 可配置触发键：`Fn`、右 Option、右 Control
- 支持按住录音和按一下开始/结束的免按住模式
- 使用 CGEvent tap 全局监听修饰键，并吞掉触发键事件
- 基于 Apple Speech 的流式语音识别
- 默认识别语言为简体中文 `zh-CN`
- 菜单栏可切换英语、简体中文、繁体中文、日语、韩语
- 菜单、首次引导、浮窗、设置页支持多语言界面文案
- 底部居中的浮动 HUD，显示实时转写文本和波形
- 通过剪贴板 + 模拟 `Cmd+V` 注入文本，并在 CJK 输入法下临时切换到 ASCII 输入源后再恢复
- 提供 LLM Refinement 子菜单，可配置 API Base URL、API Key、Model
- 支持 AI 输出模式：原始转写、轻度纠错、润色成消息、邮件语气、项目符号/步骤、翻译
- 支持选中文本语音编辑，可改写、缩短、翻译或按口述要求修改高亮文本
- 支持个人词典，将人名、产品名、缩写和技术词同时用于语音识别上下文与 LLM 优化提示
- 支持翻译模式，可选择目标语言后直接把语音转换为译文
- 支持本地语音输入历史记录，可复制和清空
- 提供权限诊断菜单和首次启动引导
- API Key 存储在钥匙串中

## 首页截图

运行验证完成后，可以把 README 中的占位内容替换为真实截图：

```md
![MacVoiceInput Screenshot](./docs/images/screenshot-main.png)
```

建议截图内容包含：

- 菜单栏图标
- 正在录音时的底部浮窗
- 实时转写文本
- 如有需要，可展示语言菜单或 LLM 设置

## 环境要求

- macOS 14 及以上
- 已安装 Xcode 26+ / Swift 6 工具链

## 快速开始

```bash
make build
make run
```

常用命令：

```bash
make build    # 构建签名后的 .app 到 .build/release/
make run      # 构建并启动应用
make install  # 安装到 /Applications
make clean    # 清理构建产物
```

生成的应用路径：

```bash
.build/release/MacVoiceInput.app
```

## 从开发到发布的工作流

这个仓库已经包含完整的 GitHub Actions 流程，覆盖日常开发校验、持续发布和正式版本发布：

- `CI` 工作流：在 `push main` 和 `pull_request` 时执行，使用 `make build` 构建应用，并上传 CI 构建产物
- `Continuous Release` 工作流：在每次推送到 `main` 时执行，自动构建可安装的 `.dmg` 和 `.zip`，并更新一个固定的滚动预发布版本，方便用户始终下载最新构建
- `Release` 工作流：在推送类似 `v1.0.0` 的 tag 时执行，自动打正式包、生成校验文件，并发布到 GitHub Releases

典型正式发布流程：

```bash
git checkout main
git pull
# 完成功能开发
git push origin main
git tag v1.0.0
git push origin v1.0.0
```

持续发布流程：

```bash
git push origin main
```

每次推送到 `main` 后，GitHub 都会自动更新 `main-latest` 这个滚动预发布版本，并附上最新安装包。

生成的发布产物：

```bash
dist/MacVoiceInput-v1.0.0.dmg
dist/MacVoiceInput-v1.0.0.dmg.sha256
dist/MacVoiceInput-v1.0.0.zip
dist/MacVoiceInput-v1.0.0.zip.sha256
```

用户可以直接在 GitHub Release 页面下载。推荐下载 `.dmg`，打开后把 `MacVoiceInput.app` 拖到 `Applications` 即可安装。

`main` 最新提交对应的滚动预发布地址：

```text
https://github.com/SeekerGAO/mac-voice-input/releases/tag/main-latest
```

### 可选的签名与公证

如果希望其他用户安装时获得更平滑的 macOS 体验，建议在 GitHub 仓库中配置这些 secrets：

- `APPLE_CERTIFICATE_BASE64`：Developer ID Application 证书（`.p12`）的 base64 内容
- `APPLE_CERTIFICATE_PASSWORD`：证书密码
- `APPLE_KEYCHAIN_PASSWORD`：GitHub Actions 中临时 keychain 的密码
- `APPLE_SIGNING_IDENTITY`：完整签名身份，例如 `Developer ID Application: Your Name (TEAMID)`
- `APPLE_TEAM_ID`：Apple Developer 团队 ID
- `APPLE_ID`：用于公证的 Apple ID
- `APPLE_APP_SPECIFIC_PASSWORD`：用于公证的 app-specific password

如果不配置这些 secrets，工作流仍会发布 `.dmg` 和 `.zip`，但用户首次打开时可能需要手动在 Gatekeeper 中放行。

## 首次运行所需权限

应用正常工作需要以下 macOS 权限：

- 麦克风
- 语音识别
- 辅助功能
- 输入监控

如果没有授予“辅助功能”和“输入监控”，全局触发键监听和模拟粘贴可能无法正常工作。

菜单栏中的“权限诊断”还提供：

- 整体权限就绪状态
- 每项权限状态指示
- 直接打开系统隐私设置
- 手动触发权限请求操作
- 打开首次引导页

## LLM 纠错说明

菜单栏中提供 `LLM Refinement` 子菜单，可用于：

- 开启或关闭 LLM 纠错
- 切换 AI 输出模式
- 设置翻译目标语言
- 打开设置窗口
- 配置 API Base URL、API Key、Model
- 维护个人词典

菜单栏还提供录音模式、触发快捷键和历史记录子菜单。

接口需兼容 OpenAI 风格的 `/chat/completions`。

## 常见问题

- 按下触发键没反应时，先确认“辅助功能”和“输入监控”权限都已授权；macOS 未及时刷新时，重新打开应用通常更直接。
- 如果开始录音后立刻失败，先检查“麦克风”和“语音识别”权限。
- 如果你刚构建了新版本，务必确认自己运行的是 `.build/release/MacVoiceInput.app`，或者执行 `make install` 覆盖 `/Applications` 中的旧版本。
- 如果在中日韩输入法下粘贴异常，先确认目标输入框已聚焦，并再次检查辅助功能权限是否仍然有效。

## 项目结构

- [`Package.swift`](/Users/seekergao/Code/demo/mac-voice-input/Package.swift)：SwiftPM 包定义
- [`Sources/MacVoiceInput`](/Users/seekergao/Code/demo/mac-voice-input/Sources/MacVoiceInput)：应用源码
- [`AppBundle/Info.plist`](/Users/seekergao/Code/demo/mac-voice-input/AppBundle/Info.plist)：应用 Bundle 信息
- [`AppBundle/AppIcon.icns`](/Users/seekergao/Code/demo/mac-voice-input/AppBundle/AppIcon.icns)：应用图标
- [`Tools/generate_icon.swift`](/Users/seekergao/Code/demo/mac-voice-input/Tools/generate_icon.swift)：图标生成脚本
- [`docs/README-Screenshot-Template.md`](/Users/seekergao/Code/demo/mac-voice-input/docs/README-Screenshot-Template.md)：README 截图模板
- [`docs/DEVELOPMENT.md`](/Users/seekergao/Code/demo/mac-voice-input/docs/DEVELOPMENT.md)：英文开发与维护说明
- [`docs/DEVELOPMENT.zh-CN.md`](/Users/seekergao/Code/demo/mac-voice-input/docs/DEVELOPMENT.zh-CN.md)：中文开发与维护说明
- [`Makefile`](/Users/seekergao/Code/demo/mac-voice-input/Makefile)：构建、运行、安装命令

## 仓库整理建议

建议提交的文件：

- `Sources/`
- `AppBundle/`
- `Tools/`
- `docs/`
- `Package.swift`
- `Makefile`
- `.gitignore`
- `README.md`
- `README.zh-CN.md`
- `LICENSE`

建议忽略的文件：

- `.build/`
- `.DS_Store`
- 本地 SwiftPM 缓存
- 编辑器临时文件

## 当前状态

项目已通过以下命令完成构建验证：

```bash
make build
```

GitHub Actions 也会在 macOS 环境中自动校验构建，并在 tag 或 `main` 推送时发布可下载安装包。

但麦克风权限、语音识别、全局 `Fn` 监听、输入法切换、文本注入等运行时行为，仍需要在真实 macOS 环境下完成实际测试。

## 许可证

本项目采用 MIT License，详见 [LICENSE](/Users/seekergao/Code/demo/mac-voice-input/LICENSE)。
