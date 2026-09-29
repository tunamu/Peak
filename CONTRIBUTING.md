# Contributing to Peak

Peak is an open-source project. Contributions are welcome.

## Development Setup

1. Clone: `git clone https://github.com/tunamuswork/peak.git`
2. Open `Peak.xcodeproj` in Xcode 27+ (iOS 27 SDK, deployment target iOS 26.0)
3. Build and run on simulator or device

## Code Style

- **Swift**: SwiftLint (run: `swiftlint`)
- **Format**: swift-format (automatic via pre-commit hook)
- **Tests**: Swift Testing framework (`cd Packages/PeakKit && swift test`)

## Pull Requests

- Base branch: `main`
- Describe what and why (not just what changed)
- Include tests for new features
- Ensure all tests pass (`cd Packages/PeakKit && swift test`)

## License

All contributions are licensed under MIT.
