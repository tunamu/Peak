# Performance

Measured for F10-04 on 2026-10-01: iPhone 13 Pro Max, iOS 26, a Release build signed for development, the
maintainer's real data (22 sessions, 17 movements, 6 workouts), a workout running. Instruments' App Launch template
with `xcrun xctrace`, three launches in a row.

## Launch

| Launch | Process start → first frame | UIKit initialization | First frame rendering |
| --- | --- | --- | --- |
| 1 (cold) | 930 ms | 311 ms | 227 ms |
| 2 | 690 ms | 337 ms | 201 ms |
| 3 (warm) | 293 ms | 66 ms | 120 ms |

Peak's own code on the main thread during the cold launch (868 ms of samples):

| Where | Time |
| --- | --- |
| `PeakApp.init` (of which opening the store: 22 ms) | 36 ms |
| Home's first `body` (day plan and Energy Level) | 46 ms |
| Everything else in Peak | under 10 ms |

The rest is the system. In the slow launches about 200 ms of UIKit initialization was iOS loading its accessibility
settings bundle (`GuidedAccessManager`), which an app cannot avoid.

## Idle

With a workout running and Home on screen, the main thread was busy for 3 ms over 9.5 s: the running clock redraws
only its text, not the screen.

## Glass

Home draws 11 glass surfaces (week strip, today's card and its button, steps card and button, the Energy and Water
tiles and their parts) inside `GlassEffectContainer`s where they sit together, as Apple recommends.

## How to measure again

```bash
# A Release build on the device
xcodebuild build -project Peak.xcodeproj -scheme Peak -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build/release -allowProvisioningUpdates
xcrun devicectl device install app --device <UDID> build/release/Build/Products/Release-iphoneos/Peak.app

# A launch trace, then the life-cycle table
xcrun xctrace record --template "App Launch" --device <UDID> --time-limit 12s --output launch.trace \
  --launch -- com.tunamu.peak
xcrun xctrace export --input launch.trace \
  --xpath '//trace-toc/run[@number="1"]/data/table[@schema="life-cycle-period"]'
```

## Still to check by hand

Scrolling and the sheets need touches, so hitches are checked on a device with the Animation Hitches template while
scrolling Home, Settings and a workout with every set filled.
