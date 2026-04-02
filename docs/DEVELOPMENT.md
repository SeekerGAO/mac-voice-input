# Development Notes

## Build Targets

- `make build`: compile the SwiftPM executable, package the `.app`, and apply ad-hoc signing
- `make run`: build and launch the generated app bundle
- `make install`: copy the app bundle into `/Applications`

## Runtime Architecture

- `AppDelegate.swift`: menu bar lifecycle, permission flow, capture state machine
- `SpeechRecognizerService.swift`: speech authorization, audio engine, streaming recognition
- `HotkeyMonitor.swift`: global `Fn` key event tap
- `TextInjector.swift`: clipboard snapshot, temporary pasteboard swap, synthetic paste shortcut
- `FloatingPanel*`: recording HUD model, view, and panel hosting
- `SettingsStore.swift` and `KeychainStore.swift`: persisted settings and API key storage

## Local Validation Checklist

- Build succeeds with `make build`
- App launches from `.build/release/MacVoiceInput.app`
- Permissions can be granted from the diagnostics menu
- Holding `Fn` shows the floating panel and starts recognition
- Releasing `Fn` stops recognition and injects text into a focused input
- Optional LLM refinement works with a valid OpenAI-compatible endpoint

## Known Constraints

- Global hotkey monitoring depends on macOS Accessibility and Input Monitoring permissions
- Speech recognition behavior must be validated on a real machine; CI-style verification is not enough
- Because the app is ad-hoc signed locally, testing the wrong app copy can easily look like a code regression

## Recommended Next Improvements

- Add a repeatable manual QA checklist for permission flows on a clean macOS account
- Capture real screenshots and store them under `docs/images/`
- Add lightweight unit coverage for non-AppKit logic such as settings parsing and permission state mapping
- Consider a dedicated release script if the app will be distributed outside local development
