# VibeCodingBreath — Test Plan

## Automated (`swift test`)

| Suite | What it guards |
|---|---|
| `BreathPhaseTests` | `allCases` order is `inhale → holdAfterInhale → exhale → holdAfterExhale`; durations are exactly 4/2/6/2; `targetScale` is 2.0/2.0/1.0/1.0; localization keys match the .strings files. |
| `BreathingEngineTests` | Initial phase is `.exhale`; `start()` enters `.inhale` first; repeated `start()` does not spawn multiple tasks (`taskSpawnCount` stays at 1); `stop()` halts phase changes; `start()` after `stop()` spawns a new task. |
| `IdleMonitorTests` | With an injected `FakeIdleSource`, edges fire once per transition (not on repeated same-state ticks); the 5-second boundary is inclusive (`seconds >= threshold`). |
| `AppCoordinatorTests` | Exhaustive `(idle, fullscreen, manualOverride)` truth table — only `!fullscreen && (idle ∨ manualOverride)` shows the overlay. Fullscreen always wins, even over manual override. `manualOverride` clears on the next active edge. `start()` installs the status item; `stop()` uninstalls. |
| `ConstantsTests` | All tunables are pinned to their documented values. |
| `LocalizationTests` | Every menu + phase key resolves in both `en.lproj` and `zh-Hans.lproj` (case-insensitive directory lookup because SwiftPM 5.10 normalizes `zh-Hans.lproj` → `zh-hans.lproj`). |

24 test cases total; target runtime < 2 s.

## Manual Acceptance Checklist

Run on a clean macOS 14 install, fresh user account:

- [ ] Launch the app → no Dock icon, no Cmd+Tab entry, a template icon appears in the menu bar.
- [ ] Click the menu icon → exactly two items appear. In a zh-Hans system they read "打开 VibeCodingBreath" / "退出"; in en they read "Open VibeCodingBreath" / "Quit".
- [ ] At the desktop, stop all input → within ~5 s the halo fades in at the center of the main screen and begins pulsing on the 4-2-6-2 rhythm.
- [ ] Move the mouse → the halo fades out in ≤ 200 ms.
- [ ] Press any key while the halo is visible → the halo fades out in ≤ 200 ms.
- [ ] With the halo visible, click through it onto a Finder icon underneath → the click lands on Finder, not on the halo.
- [ ] Enter fullscreen in Keynote / Quick Look / a YouTube video → the halo never appears, even after > 5 s idle.
- [ ] Choose "Open VibeCodingBreath" from the menu → halo appears immediately (unless fullscreen).
- [ ] After any input, "Open VibeCodingBreath"'s effect clears.
- [ ] Reboot macOS → the app is back in the menu bar after login without manual launch.
- [ ] Launch a second copy of the `.app` → the second process terminates; the first continues to run.
- [ ] Choose "Quit" → status item disappears, process exits, nothing lingers in Activity Monitor.
- [ ] Activity Monitor over 10 minutes idle: CPU < 1%, memory < 80 MB.
- [ ] No OS permission prompts (Accessibility, Screen Recording, Notifications) appear at any point.

## Regression Watch-list

Known edge cases that deserve a focused look on each release:

- External display attach / detach while the halo is visible → recenter via `NSApplication.didChangeScreenParametersNotification`.
- Lid close / sleep / wake while the halo is visible → hide on `willSleep`, re-evaluate on `didWake`.
- Space change into a fullscreen-containing Space while the halo is visible → halo must hide.
- Manual "Open" while already idle → halo shows; subsequent input clears both idle and manualOverride.
