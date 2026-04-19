# VibeCodingBreath — Product Requirements

## Problem

While an AI coding agent is thinking, the user is often staring at a loader. Rather than context-switching to Twitter, the user should breathe. VibeCodingBreath fills those idle seconds with an invisible, never-intrusive mindfulness cue.

## MVP Principles

1. **Zero-touch.** No onboarding, no configuration UI, no notifications.
2. **Zero-permission.** No Accessibility, no Screen Recording, no Notifications prompts — ever.
3. **Zero-friction.** The halo only shows when the user is obviously waiting, and disappears at the slightest input.
4. **One idea.** A soft breathing halo. No bars, no waveforms, no text labels, no audio.

## User Experience

- App lives entirely in the macOS menu bar (`LSUIElement = true`).
- Status-bar icon (template, light/dark adaptive) with a single two-item menu:
  - **Open VibeCodingBreath** — manually force-show the halo, ignoring idle judgment, until the next user input.
  - **Quit** — terminate cleanly.
- While the user is idle at the desktop for ≥ 5 seconds, a soft breathing halo fades in (0.4 s) at the center of the main screen and drives a 4-2-6-2 inhale / hold / exhale / hold cycle.
- Any mouse movement or keypress fades the halo out within 200 ms.
- The halo is always click-through.
- If the frontmost app is in true fullscreen (Keynote, video, etc.) the halo is suppressed entirely.
- App auto-launches at login after first run (via `SMAppService.mainApp.register()`).
- Only a single instance runs at a time.

## Acceptance Criteria

- [ ] No Dock icon; status-bar template icon appears.
- [ ] Status menu contains exactly two items, localized in the system language (zh-Hans / en).
- [ ] 5 s of no input on the desktop → halo fades in at the center of the main screen with the 4-2-6-2 rhythm.
- [ ] Any mouse move or key press fades the halo out within 200 ms.
- [ ] The halo never intercepts clicks (Finder icons under it are clickable).
- [ ] Frontmost fullscreen app suppresses the halo entirely.
- [ ] After macOS reboot the app auto-launches into the menu bar.
- [ ] Quit terminates the process and leaves nothing behind.
- [ ] Idle CPU < 1%, resident memory < 80 MB.
- [ ] No system permission prompts ever appear.

## Non-Goals (MVP)

- No history, streaks, stats, or persistence of any kind.
- No audio, haptics, or system notifications.
- No per-display/per-Space configuration UI.
- No integration with Claude Code / Cursor / Copilot signals — this release uses only idle time as a proxy for "AI is thinking".
- No support for macOS < 14.
