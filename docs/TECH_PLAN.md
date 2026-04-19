# VibeCodingBreath — Technical Plan

## Runtime Shape

- Single SwiftPM `executableTarget` (no `.xcodeproj`).
- `LSUIElement = true` (menu-bar only, no Dock icon, no Cmd+Tab presence).
- `@main struct VibeCodingBreathApp: App` with `Settings { EmptyView() }` and an `@NSApplicationDelegateAdaptor`.
- All UI types are `@MainActor`. Cross-actor hops go through `Task { @MainActor in ... }` rather than `DispatchQueue.main.async`.
- Strict concurrency is enabled (`StrictConcurrency=complete`).

## Module Layout

```
Sources/VibeCodingBreath/
├── App/
│   ├── VibeCodingBreathApp.swift     @main App, Settings{EmptyView()}
│   ├── AppDelegate.swift             Single-instance check, sleep/wake observers
│   └── AppCoordinator.swift          State machine + dependency wiring
├── Status/
│   └── StatusItemController.swift    NSStatusItem + 2-item menu
├── Idle/
│   ├── IdleMonitor.swift             CGEventSource polling, 500 ms Task loop
│   └── ForegroundContextMonitor.swift Heuristic fullscreen detection
├── Overlay/
│   ├── OverlayPanel.swift            Borderless non-activating NSPanel subclass
│   ├── OverlayWindowController.swift Fade in/out + recenter on screen change
│   └── BreathingOverlayView.swift    SwiftUI halo
├── Breathing/
│   ├── BreathPhase.swift             enum w/ duration + targetScale + l10n key
│   └── BreathingEngine.swift         @Observable @MainActor phase sequencer
├── System/
│   └── LoginItemManager.swift        SMAppService.mainApp.register()
├── Support/
│   ├── Constants.swift               All tunables, plus AppResources.bundle
│   ├── Palette.swift                 Primary color + halo gradient stops
│   ├── Logger+App.swift              os.Logger categories
│   └── Protocols.swift               Injection seams for tests
└── Resources/
    ├── en.lproj/Localizable.strings
    └── zh-Hans.lproj/Localizable.strings
```

## Key Design Decisions

### Idle detection — no permissions

Poll every 500 ms via `CGEventSource.secondsSinceLastEventType(.combinedSessionState, …)` over the union of mouse movement, all mouse buttons, drags, scroll wheel, `.keyDown`, `.flagsChanged`. The **minimum** across those event types is "seconds since last user input". Crossing the 5 s threshold fires an edge on `IdleProviding.onChange`. `CGEventSource` requires no Accessibility or Screen Recording permission.

### Fullscreen suppression — no permissions

`ForegroundContextMonitor` listens for `activeSpaceDidChange` and `didActivateApplication` via `NSWorkspace.notifications(named:)` async sequences (MainActor tasks, not `@Sendable` block observers). Fullscreen is inferred from the menu-bar-hidden frame heuristic combined with the frontmost app's `activationPolicy == .regular`.

### Overlay — click-through, always-on-top

`OverlayPanel` subclass of `NSPanel` with `styleMask: [.borderless, .nonactivatingPanel]`, `level = .statusBar`, `ignoresMouseEvents = true`, `collectionBehavior: [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]`. It is centered on `NSScreen.main.frame` (full frame, including the menu-bar band). A `NSHostingView` hosts the SwiftUI halo.

### Breathing engine — a single task, canonical rhythm

```swift
Task { @MainActor in
    while !Task.isCancelled {
        for p in BreathPhase.allCases {
            self.phase = p
            try? await Task.sleep(for: .seconds(p.duration))
        }
    }
}
```

4-2-6-2 (inhale / hold / exhale / hold) = 14-second cycle. `start()` / `stop()` are idempotent; `taskSpawnCount` is exposed for tests to verify no double-spawn on repeated `start()`.

### Coordinator — a three-variable truth table

```
show  ⇔  !isFullscreen && (isIdle || manualOverride)
```

`manualOverride` is set by the "Open VibeCodingBreath" menu item and is cleared on the next active edge (idle → false). Fullscreen always wins.

### Strict concurrency workarounds

- `AppDelegate` is `@MainActor final class` so `[weak self]` in nested `Task { @MainActor in ... }` compiles.
- Notification observers use `NSWorkspace.shared.notificationCenter.notifications(named:)` (async sequences) instead of block-based `addObserver(forName:queue:using:)`, because the block form is `@Sendable` and fights with `@MainActor` captures.
- `IdleMonitor` polls via a cancellable `Task` loop rather than `Timer.scheduledTimer`, for the same reason.
- `AppLogger` static `Logger` properties are marked `nonisolated(unsafe)` to silence the 5.10 strict-concurrency warning without affecting behavior.
- **Swift 5.10 IRGen workaround:** no `@MainActor final class` has a designated `init` with an `@escaping` closure as a default-value parameter. Closures are assigned via properties (`onOpen`, `onQuit`, `onChange`) after construction.

## Resources and Bundle Assembly

- `Info.plist` lives in `Bundle/Info.plist` (outside `Sources/`, since SwiftPM 5.10 forbids it as a top-level resource).
- Localizations use legacy `Resources/<lang>.lproj/Localizable.strings` files (not `.xcstrings`, which SwiftPM 5.10 does not compile).
- `Scripts/build-app.sh` calls `swift build`, then assembles `Contents/{MacOS,Resources,Info.plist}` and embeds the SwiftPM-generated `VibeCodingBreath_VibeCodingBreath.bundle` under `Contents/Resources/` so `Bundle.module` resolves at runtime. Each embedded `.bundle` is `codesign`'d separately before the outer `.app` is signed.

## Injection Seams (Testability)

Protocols in `Support/Protocols.swift`:

- `IdleTimeSource` — injectable "seconds since last event" provider.
- `IdleProviding`, `ForegroundContextProviding`, `OverlayControlling`, `StatusItemControlling` — all `@MainActor`, all used by `AppCoordinator`. Fakes live in `Tests/VibeCodingBreathTests/Fakes/Fakes.swift`.

## Performance Budget

- Idle ticking is a `Task.sleep` loop on MainActor, 2 hops / second, zero allocations in the steady state.
- Overlay hidden → no window, no SwiftUI host, engine is stopped.
- Target: idle CPU < 1%, RSS < 80 MB.
