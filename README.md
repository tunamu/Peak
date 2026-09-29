# Peak

[![CI](https://github.com/tunamu/Peak/actions/workflows/ci.yml/badge.svg)](https://github.com/tunamu/Peak/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Minimal, open-source iOS app for strength training with progressive overload, plus daily steps, water and energy.

```
Routine → Today's workout → Log set by set → Next target set automatically → Repeat
```

No accounts, no servers, no analytics. Your data stays on your device and in your own iCloud.

## Features

✅ done · 🔶 in progress · ⬜ planned

| Feature | Status |
| --- | --- |
| Progressive overload targets per set | 🔶 engine done, used in the workout screen (F6) |
| Routines with rotation (weekdays or every N days, several at once) | ✅ |
| Home: week strip, today's workout, steps, water, Energy Level | ✅ |
| Workout session: strength sets and walking cardio | ⬜ |
| Import JSON, Excel and CSV; export JSON | ⬜ |
| Apple Health: steps, sleep, HRV, water, workouts | 🔶 all but workouts (F6) |
| iCloud sync | ⬜ |
| Widgets and Live Activity | ⬜ |
| English and Turkish | 🔶 |
| Dark and light themes | ✅ |

Detailed progress: [docs/STATUS.md](docs/STATUS.md) · Timeline: [docs/ROADMAP.md](docs/ROADMAP.md)

## Requirements

- iPhone with iOS 26.0 or later
- To build: Xcode 27 (iOS 27 SDK, Swift 6.4) and SwiftLint (`brew install swiftlint`)

## Getting started

```bash
git clone https://github.com/tunamu/Peak.git
cd Peak
open Peak.xcodeproj
```

Pick an iPhone simulator and press Run (⌘R). Details: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Documentation

| Topic | File |
| --- | --- |
| Build, lint, project layout | [DEVELOPMENT.md](docs/DEVELOPMENT.md) |
| Modules and data flow | [ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Decision records | [adr/](docs/adr/README.md) |
| Data model and iCloud rules | [DATA_MODEL.md](docs/DATA_MODEL.md) |
| Import and export format | [IMPORT_FORMAT.md](docs/IMPORT_FORMAT.md) |
| Progressive overload · routines · Energy Level | [PROGRESSIVE_OVERLOAD.md](docs/PROGRESSIVE_OVERLOAD.md) · [ROUTINES.md](docs/ROUTINES.md) · [ENERGY_LEVEL.md](docs/ENERGY_LEVEL.md) |
| Design system | [DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) |
| Apple Health | [HEALTHKIT.md](docs/HEALTHKIT.md) |
| Testing · release | [TESTING.md](docs/TESTING.md) · [RELEASE.md](docs/RELEASE.md) |
| Privacy policy | [privacy.md](docs/privacy.md) |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md). Security issues:
[SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE). Third-party code: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
