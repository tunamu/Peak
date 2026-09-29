# 0001. SwiftUI native app, iOS 26.0 deployment target, Xcode 27

- **Status:** Accepted
- **Date:** 2026-09-29

## Context

Liquid Glass and the system components the design relies on are only fully available to native SwiftUI apps. Xcode 27 shipped on 2026-09-14, and App Store uploads require the iOS 27 SDK from April 2027.

## Decision

Build a native SwiftUI app with Xcode 27 (iOS 27 SDK, Swift 6.4). Set the deployment target to iOS 26.0 so users who have not moved to iOS 27 are still covered.

## Consequences

- No cross-platform framework.
- iOS 26 requires iPhone 11 or later; iPhone XS/XR are not supported.
- New iOS 27-only APIs need availability checks.
