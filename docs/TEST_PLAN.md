# VibeCodingBreath 边写边测方案（Build-Test Loop Plan）

> 配套：[PRD.md](PRD.md) · [TECH_PLAN.md](TECH_PLAN.md)
> 目标：**每写一段产品代码，立刻有一条可运行的验证**，让 M0–M5 的每一步推进都带着"绿灯"前进，最终一次性交付可用、稳定、高效的 v1.0。

---

## 1. 核心理念

1. **"红 → 绿 → 重构"在 SwiftPM 内闭环**：业务逻辑全部走 `swift test`，UI/系统集成走可重复的"手动剧本"。
2. **可测核心 + 薄系统外壳**：把不可测部分（NSPanel、NSStatusItem、CGEventSource、SMAppService）压到最薄一层，业务逻辑全部依赖**协议**注入，便于在测试中替换为 fake。
3. **两条测试通道并行**：
   - 通道 A — **自动化**：`Swift Testing`（Swift 6 原生 `@Test`）跑纯逻辑、状态机、定时器调度。
   - 通道 B — **手动剧本**：每个里程碑配一份 `Scripts/smoke/Mx.md`，10 分钟内可走完，结果勾选写回。
4. **每个 Todo 都对应一次 commit**：commit message 模板 `Mx.y: <动作> + <验证方式>`，例如 `M3.2: BreathingEngine 阶段循环 + 4 个 @Test 全绿`。
5. **CI 即守门员**：所有 `swift test` 在 `macos-15` runner 上必须通过，main 分支不接受红灯。

## 2. 测试金字塔

```
            ┌──────────────────────────┐
            │    手动冒烟 (Scripts/    │  ← 真实系统集成（NSPanel 显示、自启）
            │    smoke/M*.md)          │
            ├──────────────────────────┤
            │   集成测试 (少量)         │  ← Coordinator 接线、NotificationCenter
            ├──────────────────────────┤
            │   单元测试 (主体)         │  ← Engine / Monitor / Palette / Constants
            └──────────────────────────┘
```

- **单元测试占比 ≥ 70%**：所有可被 fake 替换系统调用的代码。
- **集成测试占比 ≈ 20%**：Coordinator 用 fake monitor + fake overlay 走完决策流。
- **手动冒烟占比 ≈ 10%**：仅 NSPanel 视觉、菜单栏外观、登录项注册三类必须肉眼确认的事。

## 3. 可测性设计（Design for Testability）

每个系统耦合点都先抽协议，再实现真品 + Fake：

| 耦合点 | 协议 | 真实实现 | 测试替身 |
|---|---|---|---|
| 用户事件时间 | `EventInactivityProvider` | `CGEventInactivityProvider` (调用 `CGEventSource`) | `FakeInactivityProvider`（手动驱动秒数） |
| 定时调度 | `TickScheduler` | `DispatchTickScheduler` | `ManualTickScheduler`（手动 `advance(by:)`） |
| 前台/全屏 | `ForegroundContextProviding` | `WorkspaceContextProvider` | `FakeContextProvider` |
| 自启动 | `LoginItemControlling` | `SMAppServiceLoginItem` | `InMemoryLoginItem` |
| 覆盖窗口 | `OverlayPresenting` | `OverlayWindowController` | `RecordingOverlay`（记录 show/hide 调用） |
| 时钟（用于动画引擎） | `Clock`（Swift 6 标准） | `ContinuousClock` | `TestClock`（自带快进） |

> 这些协议在 `Sources/VibeCodingBreath/Support/Protocols.swift` 集中声明；测试用的 Fake 放 `Tests/VibeCodingBreathTests/Fakes/`。

## 4. 测试栈与工具

- **Swift Testing**（Swift 6 内置）：`@Test`、`@Suite`、`#expect`、参数化 `@Test(arguments:)`。
- **TestClock**：手写一个 `Clock & Sendable` 的 `TestClock`（Swift 标准库提供），用于 `BreathingEngine` 与 `IdleMonitor` 的时间推进；避免任何 `sleep`。
- **`@MainActor` 测试**：UI 相关 actor 用 `@Test @MainActor` 标注。
- **快照 / 视觉**：MVP 不引入快照库；呼吸灯视觉差异通过手动剧本截图归档。
- **覆盖率**：`swift test --enable-code-coverage`，目标核心模块 line coverage ≥ 80%。
- **Lint**：`swift build -Xswiftc -warnings-as-errors`；CI 把警告当错误。

## 5. 边写边测工作流（Inner Loop）

每条 Todo 推荐流程（≤ 15 分钟一轮）：

1. **写测试先行**（适用于 Engine / Monitor / Coordinator 等纯逻辑）：
   - 在对应 `*Tests.swift` 中加 `@Test func ...`，先让它编译失败或断言失败。
2. **最小实现**：写够让测试转绿的代码即可。
3. **`swift test --filter`** 只跑当前 Suite，秒级反馈。
4. **重构**：在绿灯下整理命名、抽常量。
5. **跑全量** `swift test` 防止回归。
6. **对应手动剧本里勾掉一条**（如果该 Todo 涉及系统集成）。
7. **commit**：`Mx.y: <动作>`，附测试条数。

> 系统外壳（NSPanel、StatusItem、SMAppService）用"先写真实实现 → 立即跑对应手动剧本"的方式验证，不强求自动化。

## 6. 具体 Todo 与对应测试映射

> 与 [TECH_PLAN.md §6](TECH_PLAN.md#6-实施-todo-list事无巨细可顺序执行) 一一对应；列出每条 Todo 的"测试动作"。

### M0 脚手架阶段

| Todo | 测试动作 |
|---|---|
| M0.1 `Package.swift` | `swift build` 通过；新增空 `@Test func packageBuilds() {}` 让 `swift test` 也能跑通管线。 |
| M0.3 `Info.plist` 接入 | 写 `InfoPlistTests`：`#expect(Bundle.module.infoDictionary?["LSUIElement"] as? Bool == true)`、`LSMinimumSystemVersion == "15.0"`。 |
| M0.4 `Localizable.xcstrings` | `LocalizationTests`：`#expect(String(localized: "status.menu.quit", bundle: .module) != "status.menu.quit")`，覆盖 zh-Hans / en。 |

### M1 应用骨架阶段

| Todo | 测试动作 |
|---|---|
| M1.1 `Constants` | `ConstantsTests`：守护默认值（`idleThreshold == 5`，节奏总时长 `4+2+6+2 == 14`）。 |
| M1.3 `Palette` | `PaletteTests`：浅/深色模式各返回非 nil 渐变；主色 hex 解析正确。 |
| M1.6 `AppCoordinator` | `CoordinatorWiringTests`：用全套 Fake 注入构造 coordinator，调用 `start()`，断言：登录项被注册一次、IdleMonitor 已 start、StatusItem 出现两个菜单项。 |
| M1.7 `StatusItemController` | `StatusMenuTests`：构造后 `menu.items.count == 2`，第一项 action 触发 `coordinator.openManually()`（用 Recording fake 验证）。 |
| M1.8 `LoginItemManager` | `LoginItemManagerTests`：用 `InMemoryLoginItem` 验证 `enableIfNeeded` 幂等；失败时不抛异常、记日志。 |
| M1.9 系统集成 | 手动剧本 `smoke/M1.md`：①Dock 无图标 ②菜单栏出现图标 ③重启后自启 ④"退出"立即结束。 |

### M2 检测阶段

| Todo | 测试动作 |
|---|---|
| M2.1 `IdleMonitor` | `IdleMonitorTests`（关键）：注入 `FakeInactivityProvider` + `ManualTickScheduler`：<br>- `@Test` 跨越阈值由 active→idle 触发一次回调<br>- 状态去抖：连续 3 个 idle tick 只回调一次<br>- 任意事件回到 active 立刻回调<br>- 阈值边界值（4.99 / 5.0 / 5.01）参数化 |
| M2.2 `ForegroundContextMonitor` | `ContextMonitorTests`：用 `FakeContextProvider` 模拟 spaceChange / activate / 全屏标志切换，验证 `onChange` 回调次数与值。 |
| M2.3 接线 `evaluate()` | `EvaluateDecisionTests`：参数化 `(idle, fullscreen, manualOverride) → expectedAction(show/hide/skip)`，覆盖 8 种组合。 |
| M2.5 系统集成 | 手动剧本 `smoke/M2.md`：①静止 5s 触发日志 ②打开 QuickTime 全屏后不触发 ③Cmd+Tab 切换不抖动。 |

### M3 呼吸灯阶段

| Todo | 测试动作 |
|---|---|
| M3.1 `BreathPhase` | `BreathPhaseTests`：所有 4 个 case 的 `duration > 0`、`targetScale ∈ [1, 2]`、`localizedKey` 能解析出非 key 字符串。 |
| M3.2 `BreathingEngine` | `BreathingEngineTests`（关键，使用 `TestClock`）：<br>- 启动后阶段顺序为 inhale → hold → exhale → hold → inhale ...<br>- 每阶段在 `clock.advance(by: phase.duration)` 后才切换<br>- `stop()` 后 phase 不再变化、内部 task 已 cancel<br>- 重复 `start()` 不产生并发 task（用计数器断言） |
| M3.3 `OverlayPanel` | `OverlayPanelTests`（@MainActor）：构造后 `ignoresMouseEvents == true`、`level == .statusBar`、`canBecomeKey == false`、`backgroundColor == .clear`。 |
| M3.4 `BreathingOverlayView` | `OverlayViewTests`（@MainActor）：用 `ViewInspector` 风格的轻量自检（仅断言子视图存在 + 文案 key 命中）；视觉留给手动剧本。 |
| M3.5 `OverlayWindowController` | `OverlayControllerTests`：注入 fake screen provider，`show()` 后窗口 frame 居中且大小 = `maxDiameter+64`；`hide()` 后 `engine.stop()` 被调用。 |
| M3.6 手动触发 | `CoordinatorManualTests`：调用 `openManually()`，断言 `overlay.show()` 被调用 1 次；随后任意 active 事件清除 override。 |
| M3.7 系统集成 | 手动剧本 `smoke/M3.md`：①静止后呼吸灯出现并按 4-2-6-2 缩放 ②鼠标动 200ms 内消失 ③点击穿透：在 Finder 桌面上点击图标可被选中。 |

### M4 健壮性阶段

| Todo | 测试动作 |
|---|---|
| M4.1 全屏屏蔽 | 扩充 `EvaluateDecisionTests`：`(manualOverride=true, fullscreen=true) → skip`。 |
| M4.2 多显示器 | `OverlayControllerTests` 加 case：fake 屏幕拔除返回 nil → `hide()` 被调用且不抛异常。 |
| M4.3 休眠 | `SleepWakeTests`：发送 `NSWorkspace.willSleepNotification` → 断言 `engine.stop()` + `overlay.hide()` 被调用。 |
| M4.5 性能 | 手动：Instruments 5 分钟空闲态截图，CPU<1%、RSS<80MB；写回 `smoke/M4.md`。 |
| M4.6 释放 | `ShutdownTests`：调用 `coordinator.stop()` 后断言所有子模块 `stop()` 各被调用一次（用 Recording fake 计数）。 |
| M4.7 i18n | 扩充 `LocalizationTests`：参数化 `Locale(identifier: "zh-Hans" | "en")` 各跑一次，断言 4 个呼吸阶段文案非空且不等于 key。 |

### M5 发布阶段

| Todo | 测试动作 |
|---|---|
| M5.1–M5.3 完善单元测试 | `swift test --enable-code-coverage` 输出 `coverage.json`，核心目录 ≥ 80%，写入 `Scripts/smoke/M5.md`。 |
| M5.4 `build-app.sh` | 脚本最后 `lipo -info` 验证 universal binary；`codesign --verify --strict` 通过。 |
| M5.5 `codesign.sh` | `notarytool history` 出现 `Accepted`；`stapler validate` 通过。 |
| M5.7 GitHub Actions | workflow 包含 `swift test` + `swift build -c release`；首次 PR 即跑通。 |
| M5.9 PRD §12 验收 | 手动剧本 `smoke/Release.md`，逐条勾选 + 截图。 |

## 7. 关键测试代码骨架（参考实现）

> 仅为示意，进入 M2/M3 前按此模板落地。

```swift
// Tests/.../Fakes/FakeInactivityProvider.swift
final class FakeInactivityProvider: EventInactivityProvider {
    var seconds: TimeInterval = 0
    func secondsSinceLastUserEvent() -> TimeInterval { seconds }
}

// Tests/.../IdleMonitorTests.swift
@Suite("IdleMonitor")
@MainActor
struct IdleMonitorTests {
    @Test("跨越阈值触发一次 idle 回调")
    func crossesThreshold() async {
        let provider = FakeInactivityProvider()
        let scheduler = ManualTickScheduler()
        let monitor = IdleMonitor(provider: provider,
                                  scheduler: scheduler,
                                  threshold: 5,
                                  pollInterval: 0.5)
        var changes: [Bool] = []
        monitor.onChange = { changes.append($0) }
        monitor.start()

        provider.seconds = 4.9; scheduler.tick()
        provider.seconds = 5.0; scheduler.tick()
        provider.seconds = 5.5; scheduler.tick()   // 不重复回调

        #expect(changes == [true])
    }

    @Test("回到活跃时再次回调")
    func backToActive() async {
        // ...
    }
}

// Tests/.../BreathingEngineTests.swift
@Suite("BreathingEngine")
@MainActor
struct BreathingEngineTests {
    @Test("阶段顺序与时长")
    func phaseSequence() async {
        let clock = TestClock()
        let engine = BreathingEngine(clock: clock)
        engine.start()

        #expect(engine.phase == .inhale)
        await clock.advance(by: .seconds(4))
        #expect(engine.phase == .holdAfterInhale)
        await clock.advance(by: .seconds(2))
        #expect(engine.phase == .exhale)
        await clock.advance(by: .seconds(6))
        #expect(engine.phase == .holdAfterExhale)
        await clock.advance(by: .seconds(2))
        #expect(engine.phase == .inhale)

        engine.stop()
    }
}
```

## 8. 手动冒烟剧本模板

`Scripts/smoke/Mx.md`：

```markdown
# Mx 冒烟剧本

环境：macOS 15.x · 主屏 + 副屏 · 浅色 / 深色

| # | 步骤 | 期望 | 结果 (✅/❌) | 截图/备注 |
|---|------|------|------|------|
| 1 | `swift run` 启动 | Dock 无图标，菜单栏图标出现 | | |
| 2 | 不动鼠标 5 秒 | 屏幕中央淡入呼吸灯 | | |
| 3 | 移动鼠标 | 呼吸灯 200ms 内淡出 | | |
| ... |  |  |  |  |

执行人：__  日期：__  结论：__
```

每个里程碑结束必须把对应剧本填满 + 提交。

## 9. CI 工作流（GitHub Actions 片段）

```yaml
name: ci
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with: { xcode-version: latest-stable }
      - run: swift --version
      - run: swift build -Xswiftc -warnings-as-errors
      - run: swift test --enable-code-coverage
      - run: |
          xcrun llvm-cov export -format=lcov \
            .build/debug/VibeCodingBreathPackageTests.xctest/Contents/MacOS/VibeCodingBreathPackageTests \
            -instr-profile .build/debug/codecov/default.profdata > coverage.lcov
      - uses: actions/upload-artifact@v4
        with: { name: coverage, path: coverage.lcov }
```

## 10. 退出标准（"边写边测"完成判定）

- [ ] 每条 §6 的 Todo 在 commit 中能找到对应测试或冒烟勾选。
- [ ] `swift test` 在 macos-15 上全绿，核心模块覆盖率 ≥ 80%。
- [ ] 所有 `Mx` 冒烟剧本均已填写 ✅。
- [ ] CI workflow 在 main 分支至少跑过一次绿灯。
- [ ] PRD §12 的 10 条验收项 100% 勾选。

---

> 本方案确保进入实施阶段后，**每写一段代码立刻有一条测试或冒烟反馈**；任何破坏既有行为的改动会在数秒内被发现，从而支撑"一次性写出可用、稳定、高效"的目标。
