# Contributing to Peak

Peak is an open-source project. Contributions are welcome.

## Development Setup

1. Clone: `git clone https://github.com/tunamu/Peak.git`
2. Install SwiftLint: `brew install swiftlint` (swift-format ships with Xcode)
3. Open `Peak.xcodeproj` in Xcode 27+ (iOS 27 SDK, deployment target iOS 26.0)
4. Build and run on simulator or device

## Code Style

- **Format**: swift-format owns layout (`.swift-format`). In Xcode: Editor > Structure > Format File (⌃⇧I).
- **Lint**: SwiftLint (`.swiftlint.yml`) runs on every Xcode build and shows warnings inline.
- **Editor**: `.editorconfig` sets indentation and whitespace; Xcode reads it.
- **Tests**: Swift Testing framework (`cd Packages/PeakKit && swift test`)

Before opening a PR, both must pass:

```bash
swiftlint lint --strict
xcrun swift-format lint --strict --recursive \
  Peak Packages/PeakKit/Package.swift Packages/PeakKit/Sources Packages/PeakKit/Tests
```

## Branches and commits

- One task per branch and pull request. Branch names carry the task ID from [docs/STATUS.md](docs/STATUS.md):
  `feat/F5-02-today-card`, `fix/F7-03-csv-dates`, `chore/F0-05-ci`.
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org): `feat(home): …`,
  `fix(import): …`, `docs: …`, `chore(ci): …`.
- Pull requests are squash-merged into `main`.

## Pull requests

- Base branch: `main`. CI (lint, build, tests) must be green.
- Describe what and why, not only what changed. The template has the checklist:
  tests · `docs/STATUS.md` · dark and light screenshots for UI · English and Turkish strings · accessibility labels ·
  `CHANGELOG.md` entry.
- New user-facing strings need a Turkish translation in `Peak/Resources/Localizable.xcstrings`.
- Architectural changes come with a decision record in [docs/adr/](docs/adr/README.md).

## Good first issues

Issues labelled `good first issue` are small and self-contained, with the files to touch listed in the issue. Comment
on the issue before you start so work is not duplicated.

## Code of Conduct

Everyone taking part follows the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

All contributions are licensed under MIT.
