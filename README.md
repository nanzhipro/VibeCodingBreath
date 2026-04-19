# VibeCodingBreath

A near-invisible macOS menu-bar companion for mindful breathing while an AI agent (Cursor / Copilot / Claude Code, etc.) is thinking.

> **AI is thinking, you are breathing.**

When your keyboard and mouse stay idle for 5 seconds, a soft breathing halo fades in at the center of the main screen and guides a 4-2-6-2 inhale / hold / exhale / hold cycle. Touch the mouse or press any key and it fades out within 200 ms. Zero notifications, zero onboarding, zero configuration UI.

## Documentation

- [docs/PRD.md](docs/PRD.md) — product requirements, MVP scope, acceptance criteria
- [docs/TECH_PLAN.md](docs/TECH_PLAN.md) — architecture, module boundaries, key design decisions
- [docs/TEST_PLAN.md](docs/TEST_PLAN.md) — test matrix, manual verification checklist

## Commands

```bash
swift test                                                          # unit tests
./Scripts/build-app.sh debug                                        # assemble .app (debug)
./Scripts/release.sh --version <x.y.z> --keychain-profile <profile> # full release pipeline
```

## Requirements

- macOS 14+
- Swift 5.10 / Xcode 15.4+
- No third-party dependencies
- No system permissions required (no Accessibility, no Screen Recording, no Notifications)
