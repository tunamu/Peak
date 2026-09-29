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

## Pull Requests

- Base branch: `main`
- Describe what and why (not just what changed)
- Include tests for new features
- Ensure all tests pass (`cd Packages/PeakKit && swift test`)

## License

All contributions are licensed under MIT.
