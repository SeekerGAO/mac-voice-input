# Development Notes

## Build Targets

- `make build`: compile the SwiftPM executable, package the `.app`, and apply ad-hoc signing
- `make run`: build and launch the generated app bundle
- `make install`: copy the app bundle into `/Applications`
- `./scripts/release_package.sh v1.0.0`: build distributable `.dmg` and `.zip` packages plus checksums in `dist/`

## CI/CD

- `.github/workflows/ci.yml`: builds the app on macOS for pushes to `main` and pull requests, then uploads a CI artifact
- `.github/workflows/release.yml`: builds and publishes a tagged release to GitHub Releases
- `scripts/release_package.sh`: shared packaging script used by the release workflow

## Release Process

1. Merge tested changes into `main`
2. Create and push a semantic version tag such as `v1.0.0`
3. Wait for the `Release` GitHub Actions workflow to finish
4. Download the generated assets from GitHub Releases and smoke-test the packaged app

Release output:

- `MacVoiceInput-<tag>.dmg`
- `MacVoiceInput-<tag>.dmg.sha256`
- `MacVoiceInput-<tag>.zip`
- `MacVoiceInput-<tag>.zip.sha256`

Optional Apple signing and notarization can be enabled through GitHub repository secrets for a smoother end-user install flow.

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
