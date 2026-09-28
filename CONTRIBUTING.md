# Contributing

Thanks for wanting to help! Bug reports, translations and small focused pull requests are the most useful.

## Before you start

- For anything bigger than a small fix, open an [issue](https://github.com/devopscodepro/macaffeine/issues) or an [Ideas discussion](https://github.com/devopscodepro/macaffeine/discussions/categories/ideas) first, so we can agree on the approach.
- Macaffeine stays small on purpose: no dependencies, no network, no privileged helpers. Features that need any of those are unlikely to be merged.

## Branches

- `dev` is where work happens. **Open pull requests against `dev`.**
- `main` only gets tested releases, each one tagged `vX.Y.Z`.

## Building and testing

You need Xcode 16 or later, no Apple Developer account.

```sh
xcodebuild -project Macaffeine.xcodeproj -scheme Macaffeine -derivedDataPath build build
xcodebuild -project Macaffeine.xcodeproj -scheme Macaffeine -derivedDataPath build test
open build/Build/Products/Debug/Macaffeine.app
```

Logs are in Console.app, or:

```sh
log stream --predicate 'subsystem == "pro.devopscode.Macaffeine"' --info
```

## Code

- Swift 6, AppKit for the menu bar, SwiftUI for Settings.
- Keep types small and the logic testable — the core (`AwakeManager`, `SafetyRules`, `AwakeCommand`) is covered by unit tests, please add tests for changes there.
- Comments only where the *why* isn't obvious.
- No new warnings.

## Commits and changelog

- Small commits, one change each, short imperative subject: `Fix timer not cancelled on manual off`.
- Add a line to `CHANGELOG.md` under `[Unreleased]` for anything users will notice.

## Translations

All strings live in `Macaffeine/Resources/Localizable.xcstrings`. The easiest way to add or fix a language is to open the project in Xcode, select the string catalog and fill in the column for your language. Keep placeholders like `%@` and `%lld` exactly as they are.

Currently: English, German, Korean, Simplified Chinese, Thai, Arabic, Russian.

## License

By contributing you agree that your work is released under the [MIT License](LICENSE).
