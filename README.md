# MacVoiceInput

MacVoiceInput is a macOS 14+ menu-bar voice input app built with Swift and Swift Package Manager.

Hold the `Fn` key to record, release it to transcribe speech and paste the final text into the currently focused input field. The app uses Apple's Speech framework for streaming transcription, shows a live floating HUD with waveform metering, and can optionally refine transcription through an OpenAI-compatible API.

For Chinese documentation, see [README.zh-CN.md](./README.zh-CN.md).

## Features

- Menu-bar only app (`LSUIElement`), no Dock icon
- Hold `Fn` to record, release to inject text
- Global `Fn` monitoring through CGEvent tap, with `Fn` event suppression to avoid the emoji picker
- Streaming speech recognition using Apple Speech
- Default language set to Simplified Chinese (`zh-CN`)
- Menu switching for English, Simplified Chinese, Traditional Chinese, Japanese, and Korean
- Localized UI text for menus, onboarding, floating HUD, and settings
- Bottom-centered floating HUD with live transcript and waveform metering
- Clipboard-based paste injection with temporary ASCII input-source switching for CJK IMEs
- Optional LLM refinement with configurable API base URL, API key, and model
- Permission diagnostics menu and first-run onboarding
- API key storage in Keychain

## Screenshot

Replace the placeholder below with a real app screenshot after runtime validation:

```md
![MacVoiceInput Screenshot](./docs/images/screenshot-main.png)
```

Recommended screenshot content:

- Menu bar icon in active state
- Bottom floating HUD while recording
- Real-time transcript text
- LLM refinement or language menu if relevant

## Requirements

- macOS 14 or later
- Xcode 26+ with Swift 6 toolchain available

## Quick Start

```bash
make build
make run
```

Useful commands:

```bash
make build    # Build a signed .app bundle into .build/release/
make run      # Build and launch the app
make install  # Copy the app into /Applications
make clean    # Remove build artifacts
```

Generated app bundle:

```bash
.build/release/MacVoiceInput.app
```

## Permissions

The app needs these macOS permissions to function correctly:

- Microphone
- Speech Recognition
- Accessibility
- Input Monitoring

Without Accessibility and Input Monitoring, global `Fn` monitoring and simulated paste will not work reliably.

The menu bar includes a `Permission Diagnostics` section with:

- Overall readiness summary
- Per-permission status entries
- Direct link to Privacy Settings
- Manual permission request actions
- First-run guide entry

## LLM Refinement

The app includes an `LLM Refinement` submenu in the menu bar:

- Enable or disable refinement
- Open the settings window
- Configure API Base URL, API Key, and model

The API must be OpenAI-compatible and support a `/chat/completions` style endpoint.

## Troubleshooting

- If pressing `Fn` does nothing, confirm Accessibility and Input Monitoring are granted and reopen the app if macOS has not refreshed the event tap yet.
- If recording starts and immediately fails, check Microphone and Speech Recognition permissions first.
- If you are testing a newly built app, make sure you are launching `.build/release/MacVoiceInput.app` or reinstalling with `make install`; otherwise macOS may still be running an older copy from `/Applications`.
- If pasted text looks wrong under a CJK IME, test with the target input field focused and confirm Accessibility permission is still granted.

## Project Structure

- [`Package.swift`](/Users/seekergao/Code/demo/mac-voice-input/Package.swift): SwiftPM package definition
- [`Sources/MacVoiceInput`](/Users/seekergao/Code/demo/mac-voice-input/Sources/MacVoiceInput): app source code
- [`AppBundle/Info.plist`](/Users/seekergao/Code/demo/mac-voice-input/AppBundle/Info.plist): app bundle metadata
- [`AppBundle/AppIcon.icns`](/Users/seekergao/Code/demo/mac-voice-input/AppBundle/AppIcon.icns): app icon
- [`Tools/generate_icon.swift`](/Users/seekergao/Code/demo/mac-voice-input/Tools/generate_icon.swift): icon generation script
- [`docs/README-Screenshot-Template.md`](/Users/seekergao/Code/demo/mac-voice-input/docs/README-Screenshot-Template.md): README screenshot template
- [`docs/DEVELOPMENT.md`](/Users/seekergao/Code/demo/mac-voice-input/docs/DEVELOPMENT.md): development and maintenance notes
- [`Makefile`](/Users/seekergao/Code/demo/mac-voice-input/Makefile): build, run, install, and clean commands

## Repository Hygiene

Recommended files to commit:

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

Ignored locally:

- `.build/`
- `.DS_Store`
- local SwiftPM cache files
- editor temp files

## Validation Status

The project has been verified with:

```bash
make build
```

Runtime behavior still needs to be validated on a real macOS machine with the required permissions granted.

## License

This project is licensed under the MIT License. See [LICENSE](/Users/seekergao/Code/demo/mac-voice-input/LICENSE).
