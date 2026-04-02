# MacVoiceInput

MacVoiceInput 是一个基于 Swift 和 Swift Package Manager 开发的 macOS 14+ 菜单栏语音输入应用。

按住 `Fn` 键开始录音，松开后将语音转写结果粘贴到当前聚焦的输入框中。应用使用 Apple Speech 框架进行流式识别，显示实时波形和转写浮窗，并可选接入兼容 OpenAI 的大模型接口对识别结果进行保守纠错。

英文说明见 [README.md](./README.md)。

## 功能特性

- 纯菜单栏应用，启用 `LSUIElement`，不显示 Dock 图标
- 按住 `Fn` 录音，松开后自动注入文本
- 使用 CGEvent tap 全局监听 `Fn`，并吞掉 `Fn` 事件，避免触发表情选择器
- 基于 Apple Speech 的流式语音识别
- 默认识别语言为简体中文 `zh-CN`
- 菜单栏可切换英语、简体中文、繁体中文、日语、韩语
- 菜单、首次引导、浮窗、设置页支持多语言界面文案
- 底部居中的浮动 HUD，显示实时转写文本和波形
- 通过剪贴板 + 模拟 `Cmd+V` 注入文本，并在 CJK 输入法下临时切换到 ASCII 输入源后再恢复
- 提供 LLM Refinement 子菜单，可配置 API Base URL、API Key、Model
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

## 首次运行所需权限

应用正常工作需要以下 macOS 权限：

- 麦克风
- 语音识别
- 辅助功能
- 输入监控

如果没有授予“辅助功能”和“输入监控”，全局 `Fn` 监听和模拟粘贴可能无法正常工作。

菜单栏中的“权限诊断”还提供：

- 整体权限就绪状态
- 每项权限状态指示
- 直接打开系统隐私设置
- 手动触发权限请求操作
- 打开首次引导页

## LLM 纠错说明

菜单栏中提供 `LLM Refinement` 子菜单，可用于：

- 开启或关闭 LLM 纠错
- 打开设置窗口
- 配置 API Base URL、API Key、Model

接口需兼容 OpenAI 风格的 `/chat/completions`。

## 常见问题

- 按下 `Fn` 没反应时，先确认“辅助功能”和“输入监控”权限都已授权；macOS 未及时刷新时，重新打开应用通常更直接。
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
- [`docs/DEVELOPMENT.md`](/Users/seekergao/Code/demo/mac-voice-input/docs/DEVELOPMENT.md)：开发与维护说明
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

但麦克风权限、语音识别、全局 `Fn` 监听、输入法切换、文本注入等运行时行为，仍需要在真实 macOS 环境下完成实际测试。

## 许可证

本项目采用 MIT License，详见 [LICENSE](/Users/seekergao/Code/demo/mac-voice-input/LICENSE)。
