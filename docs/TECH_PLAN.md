# VibeCodingBreath 技术方案与实施计划

> 配套文档：[docs/PRD.md](PRD.md)
> 版本：v0.1
> 状态：可执行（Ready to Build）
> 目标平台：macOS 15 Sequoia 及以上（仅最新系统，**不做向下兼容**）

---

## 1. 技术选型（Tech Stack）

| 维度 | 选型 | 理由 |
|---|---|---|
| 语言 | **Swift 6.0**（开启严格并发：`StrictConcurrency=complete`） | 最新语言，编译期数据竞争检查，配合 actor 模型天然适合状态栏 + 计时器场景。 |
| UI 框架 | **SwiftUI（macOS 15 SDK）** + 必要的 AppKit 桥接 | 呼吸灯动画用 SwiftUI 的 `TimelineView` / `PhaseAnimator` / `KeyframeAnimator` 极简实现；状态栏窗口仍走 AppKit。 |
| 构建系统 | **Swift Package Manager**（`Package.swift`，`executableTarget`） | 不依赖 Xcode 工程，CI / 命令行可重复构建；Bundle 通过脚本组装。 |
| 最低系统 | macOS 15.0 | 直接使用最新 API，无 `#available` 分支。 |
| 自启动 | `ServiceManagement.SMAppService.mainApp` | macOS 13+ 标准方案，15 上完全可用。 |
| 事件检测 | `CGEventSource.secondsSinceLastEventType` | 不需要辅助功能权限。 |
| 全屏检测 | `NSWorkspace` + `NSWindow.occlusionState` + 屏幕 frame 比对 | 三重判断防止误触发。 |
| 国际化 | `String Catalog (.xcstrings)` | macOS 14+ 起的官方标准 i18n 资源。 |
| 包管理 | 零第三方依赖 | 保持隐私、零供应链风险。 |
| 签名与公证 | `codesign` + `notarytool` + `stapler` | 通过 GitHub Actions 或本地脚本完成。 |
| 分发 | `.dmg`（用 `create-dmg` 或自写脚本） | 拖放到 Applications 即可。 |

> 注：项目结构允许后续转 Xcode 工程（仅需补 `.xcodeproj`），但 MVP 全部用 SwiftPM 命令行构建，避免 Xcode workspace 状态污染。

## 2. 模块架构（High-Level Architecture）

```
┌─────────────────────────────────────────────────────────────┐
│                    VibeCodingBreathApp                      │
│           (@main, NSApplicationDelegateAdaptor)              │
└──────────────────────────┬──────────────────────────────────┘
                           │ 持有
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                       AppCoordinator                        │
│   组装并持有：StatusItemController / IdleMonitor /          │
│   ForegroundContextMonitor / OverlayWindowController /      │
│   LoginItemManager / BreathingEngine                        │
└─────┬──────────────┬──────────────┬──────────────┬─────────┘
      │              │              │              │
      ▼              ▼              ▼              ▼
┌──────────┐ ┌─────────────┐ ┌──────────────┐ ┌──────────────┐
│StatusItem│ │ IdleMonitor │ │ Foreground   │ │ Overlay      │
│Controller│ │ (轮询事件)  │ │ Context      │ │ Window       │
│          │ │             │ │ Monitor      │ │ Controller   │
└──────────┘ └─────────────┘ └──────────────┘ └──────┬───────┘
                                                     │
                                                     ▼
                                            ┌──────────────────┐
                                            │ BreathingOverlay │
                                            │ View (SwiftUI)   │
                                            │ ─ BreathingEngine│
                                            └──────────────────┘
```

### 2.1 核心组件职责

| 组件 | 类型 | 职责 |
|---|---|---|
| `VibeCodingBreathApp` | `App` | SwiftUI 入口，挂载 `NSApplicationDelegateAdaptor`。 |
| `AppDelegate` | `NSApplicationDelegate` | 应用生命周期；启动时构造 `AppCoordinator`，关闭时清理。 |
| `AppCoordinator` | `@MainActor final class` | 单例式持有所有子模块，串联事件流；唯一的"可变状态枢纽"。 |
| `StatusItemController` | `@MainActor` | 创建并管理 `NSStatusItem`、`NSMenu`，处理"打开 / 退出"动作。 |
| `IdleMonitor` | `@MainActor` | 0.5s 轮询 `secondsSinceLastEventType`，发布 `idle/active` 状态变化。 |
| `ForegroundContextMonitor` | `@MainActor` | 监听前台 App、屏幕参数、空间切换，判断"是否处于全屏/演示模式"。 |
| `OverlayWindowController` | `@MainActor` | 管理透明置顶 `NSPanel` 的生命周期与定位（主屏中央）。 |
| `BreathingOverlayView` | `View` | 呼吸灯 UI，纯 SwiftUI；不持有业务状态。 |
| `BreathingEngine` | `@Observable final class` | 维护呼吸阶段状态机（吸/屏/呼/屏），驱动动画进度。 |
| `LoginItemManager` | `actor` | 包装 `SMAppService`，负责注册/查询自启状态。 |
| `Localization` | `enum` 命名空间 | 集中持有 `String Catalog` key 与帮助方法。 |
| `Constants` | `enum` 命名空间 | 默认参数（`T_idle`、节奏、尺寸、颜色、动画时长）。 |

### 2.2 状态流转（核心状态机）

```
                   ┌──────────────────────────────────────┐
                   │             .hidden                  │◀─────┐
                   └────────────────┬─────────────────────┘      │
              (idle ≥ T_idle && !isFullscreen)                  │
                                    ▼                            │
                   ┌──────────────────────────────────────┐      │
                   │            .showing                  │──────┤
                   │  BreathingEngine.start()             │      │
                   └────────────────┬─────────────────────┘      │
                          (用户交互 / 全屏切换)                  │
                                    ▼                            │
                   ┌──────────────────────────────────────┐      │
                   │           .dismissing                │──────┘
                   │  淡出 200ms → .hidden                │
                   └──────────────────────────────────────┘
```

手动触发（菜单"打开"）：直接进入 `.showing` 并设置 `manualOverride = true`，下一次用户交互时退出 manual override，回归自动模式。

## 3. 关键技术细节

### 3.1 NSPanel 透明覆盖窗口配置

```swift
final class OverlayPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar                       // 高于普通窗口，低于系统弹窗
        ignoresMouseEvents = true                // 点击穿透（核心）
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        collectionBehavior = [
            .canJoinAllSpaces,                   // 所有 Space 都显示
            .stationary,                         // Mission Control 中不抖动
            .ignoresCycle,                       // Cmd+` 不切到它
            .fullScreenAuxiliary                 // 允许覆盖在全屏窗口上（但我们在全屏时不显示）
        ]
        isReleasedWhenClosed = false
        animationBehavior = .none                // 自定义淡入淡出
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

### 3.2 静止检测（不申请权限）

```swift
@MainActor
final class IdleMonitor {
    private var timer: DispatchSourceTimer?
    private(set) var isIdle: Bool = false
    var onChange: ((Bool) -> Void)?

    private let threshold: TimeInterval
    private let pollInterval: TimeInterval
    private let trackedTypes: [CGEventType] = [
        .mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown,
        .leftMouseDragged, .rightMouseDragged, .scrollWheel,
        .keyDown, .flagsChanged
    ]

    init(threshold: TimeInterval = Constants.idleThreshold,
         pollInterval: TimeInterval = Constants.pollInterval) {
        self.threshold = threshold
        self.pollInterval = pollInterval
    }

    func start() {
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + pollInterval, repeating: pollInterval, leeway: .milliseconds(50))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        let secondsSince = trackedTypes
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? .infinity
        let nowIdle = secondsSince >= threshold
        if nowIdle != isIdle {
            isIdle = nowIdle
            onChange?(nowIdle)
        }
    }
}
```

### 3.3 全屏 / 演示模式判断

判断"前台 App 是否处于全屏 Space"：

1. 取主屏 `frame` 与 `visibleFrame`：若 `visibleFrame.height == frame.height`（菜单栏被隐藏），高度大概率代表前台进入沉浸式全屏。
2. 监听 `NSWorkspace.shared.notificationCenter` 的：
   - `NSWorkspace.activeSpaceDidChangeNotification`
   - `NSWorkspace.didActivateApplicationNotification`
3. 组合判断：菜单栏高度差 + 前台 App `activationPolicy == .regular`，触发全屏标志。

> 说明：100% 精准检测全屏需要私有 API；MVP 使用上述启发式判断已覆盖绝大多数场景（Keynote、QuickTime、视频网站全屏等）。

### 3.4 呼吸引擎（节奏状态机）

```swift
enum BreathPhase: Int, CaseIterable, Sendable {
    case inhale, holdAfterInhale, exhale, holdAfterExhale

    var duration: Double {
        switch self {
        case .inhale: return 4.0
        case .holdAfterInhale: return 2.0
        case .exhale: return 6.0
        case .holdAfterExhale: return 2.0
        }
    }

    var targetScale: Double {        // 1.0 = min, 2.0 = max
        switch self {
        case .inhale: return 2.0
        case .holdAfterInhale: return 2.0
        case .exhale: return 1.0
        case .holdAfterExhale: return 1.0
        }
    }
}

@MainActor
@Observable
final class BreathingEngine {
    private(set) var phase: BreathPhase = .exhale
    private var task: Task<Void, Never>?

    func start() {
        stop()
        task = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                for next in BreathPhase.allCases {
                    self.phase = next
                    try? await Task.sleep(for: .seconds(next.duration))
                    if Task.isCancelled { return }
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
```

视图层用 SwiftUI 的 `withAnimation(.easeInOut(duration: phase.duration)) { scale = phase.targetScale }`：

```swift
struct BreathingOverlayView: View {
    @State private var scale: CGFloat = 1.0
    let engine: BreathingEngine
    let palette: BreathPalette
    let labels: BreathLabels

    var body: some View {
        ZStack {
            Circle()
                .fill(palette.gradient)
                .blur(radius: 24)
                .frame(width: Constants.minDiameter, height: Constants.minDiameter)
                .scaleEffect(scale)
            Text(labels.text(for: engine.phase))
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(.secondary)
                .offset(y: Constants.maxDiameter / 2 + 24)
        }
        .onChange(of: engine.phase, initial: true) { _, newPhase in
            withAnimation(.easeInOut(duration: newPhase.duration)) {
                scale = newPhase.targetScale
            }
        }
    }
}
```

### 3.5 自启动（Login Item）

```swift
actor LoginItemManager {
    private let service = SMAppService.mainApp
    var isEnabled: Bool { service.status == .enabled }

    func enableIfNeeded() {
        guard service.status != .enabled else { return }
        do { try service.register() } catch { /* 静默失败，下次启动重试 */ }
    }

    func disable() {
        try? service.unregister()
    }
}
```

> 第一次启动时自动调用 `enableIfNeeded()`；不弹任何 UI。

### 3.6 单实例保证

App 启动时检查同 bundle id 进程是否已存在：

```swift
let running = NSWorkspace.shared.runningApplications
    .filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
if running.count > 1 { NSApp.terminate(nil) }
```

## 4. 项目目录结构

```
VibeCodingBreath/
├── Package.swift
├── README.md
├── docs/
│   ├── PRD.md
│   └── TECH_PLAN.md          ← 本文
├── Sources/
│   └── VibeCodingBreath/
│       ├── App/
│       │   ├── VibeCodingBreathApp.swift
│       │   ├── AppDelegate.swift
│       │   └── AppCoordinator.swift
│       ├── Status/
│       │   └── StatusItemController.swift
│       ├── Idle/
│       │   ├── IdleMonitor.swift
│       │   └── ForegroundContextMonitor.swift
│       ├── Overlay/
│       │   ├── OverlayPanel.swift
│       │   ├── OverlayWindowController.swift
│       │   └── BreathingOverlayView.swift
│       ├── Breathing/
│       │   ├── BreathPhase.swift
│       │   └── BreathingEngine.swift
│       ├── System/
│       │   └── LoginItemManager.swift
│       ├── Support/
│       │   ├── Constants.swift
│       │   ├── Palette.swift
│       │   └── Logger+App.swift
│       └── Resources/
│           ├── Localizable.xcstrings
│           ├── Assets.xcassets/
│           │   ├── AppIcon.appiconset/
│           │   └── StatusBarIcon.imageset/
│           └── Info.plist
├── Scripts/
│   ├── build-app.sh           ← swift build → 组装 .app bundle
│   ├── codesign.sh            ← 签名 + 公证 + stapler
│   └── make-dmg.sh            ← 打包 DMG
└── Tests/
    └── VibeCodingBreathTests/
        ├── BreathingEngineTests.swift
        ├── IdleMonitorTests.swift
        └── ConstantsTests.swift
```

## 5. Info.plist 关键配置

```xml
<key>LSUIElement</key>
<true/>
<key>LSMinimumSystemVersion</key>
<string>15.0</string>
<key>CFBundleIdentifier</key>
<string>pro.nanzhi.VibeCodingBreath</string>
<key>CFBundleName</key>
<string>VibeCodingBreath</string>
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
<key>CFBundleVersion</key>
<string>1</string>
<key>NSHumanReadableCopyright</key>
<string>© 2026 nanzhi. All rights reserved.</string>
<key>NSAppTransportSecurity</key>
<dict><key>NSAllowsArbitraryLoads</key><false/></dict>
```

## 6. 实施 Todo List（事无巨细，可顺序执行）

> 编号规则：`MX.Y` 对应 PRD 里程碑 M1~M5；`Y` 为子任务序号。
> 每个任务勾选完即可进入下一项；建议每个 M 完成后跑一次手动冒烟测试。

### M0 — 仓库与脚手架

- [ ] M0.1 在仓库根新建 `Package.swift`，声明 `swift-tools-version: 6.0`，`platforms: [.macOS(.v15)]`，单一 `executableTarget` 名为 `VibeCodingBreath`。
- [ ] M0.2 创建目录结构（参考第 4 节），各目录放置 `.gitkeep` 占位。
- [ ] M0.3 新建 `Sources/VibeCodingBreath/Resources/Info.plist`（参考第 5 节），并在 `Package.swift` 中通过 `resources: [.process("Resources")]` 引入。
- [ ] M0.4 新建 `Sources/VibeCodingBreath/Resources/Localizable.xcstrings`，预置 key：`status.menu.open`、`status.menu.quit`、`breath.phase.inhale`、`breath.phase.hold`、`breath.phase.exhale`，提供 `zh-Hans` / `en` 两套字符串。
- [ ] M0.5 新建 `Assets.xcassets`：
  - `AppIcon.appiconset`（即使 `LSUIElement=true` 也建议留一套，公证需要）
  - `StatusBarIcon.imageset`：18×18 / 36×36（@2x）/ 54×54（@3x）三尺寸 PDF 或 PNG，模板图（Template）属性开启。
- [ ] M0.6 新建 `.swiftformat` / `.swiftlint.yml`（可选），统一风格；至少在 `Package.swift` 启用 `.enableExperimentalFeature("StrictConcurrency")` 与 `-warnings-as-errors`。

### M1 — 应用骨架（启动 + 状态栏 + 自启）

- [ ] M1.1 `Support/Constants.swift`：定义 `idleThreshold = 5`、`pollInterval = 0.5`、`fadeIn = 0.4`、`fadeOut = 0.2`、`minDiameter = 120`、`maxDiameter = 320`、`primaryHex = "#7FB3D5"`。
- [ ] M1.2 `Support/Logger+App.swift`：基于 `os.Logger`，分 `subsystem = bundle id`、`category = ["app","idle","overlay","status","login"]`。
- [ ] M1.3 `Support/Palette.swift`：定义 `BreathPalette`（`gradient: RadialGradient`，深浅色模式各一套）。
- [ ] M1.4 `App/VibeCodingBreathApp.swift`：`@main struct`，仅声明 `Settings { EmptyView() }` Scene（避免出现默认窗口）；挂 `@NSApplicationDelegateAdaptor(AppDelegate.self)`。
- [ ] M1.5 `App/AppDelegate.swift`：实现 `applicationDidFinishLaunching`，构造 `AppCoordinator`；`applicationShouldTerminateAfterLastWindowClosed` 返回 `false`；处理单实例检查。
- [ ] M1.6 `App/AppCoordinator.swift`：`@MainActor final class`，持有所有子模块字段（先用占位 stub），暴露 `start()` / `stop()`。
- [ ] M1.7 `Status/StatusItemController.swift`：创建 `NSStatusItem`，设置模板图标（`StatusBarIcon`），构建 `NSMenu`：
  - 第 1 项 "打开 VibeCodingBreath"（`status.menu.open`），target = coordinator，selector = `openManually`。
  - 第 2 项 "退出"（`status.menu.quit`），target = `NSApp`，selector = `terminate:`。
- [ ] M1.8 `System/LoginItemManager.swift`：包装 `SMAppService.mainApp`；`AppCoordinator.start()` 中调用 `enableIfNeeded()`，失败仅日志。
- [ ] M1.9 验证 M1：`swift run` 启动后，Dock 无图标、菜单栏出现图标，菜单两项可点，"退出"能终止进程。重启系统后自动启动。

### M2 — 静止 / 上下文检测

- [ ] M2.1 `Idle/IdleMonitor.swift`：按第 3.2 节实现；提供 `start/stop/onChange`；阈值与轮询间隔从 `Constants` 注入。
- [ ] M2.2 `Idle/ForegroundContextMonitor.swift`：
  - 监听 `NSWorkspace.activeSpaceDidChangeNotification` / `didActivateApplicationNotification`。
  - 暴露 `var isFullscreenContext: Bool`，按第 3.3 节启发式判断。
  - 暴露 `onChange: ((Bool) -> Void)?`。
- [ ] M2.3 在 `AppCoordinator` 中接线：
  - `idleMonitor.onChange = { [weak self] idle in self?.evaluate() }`
  - `contextMonitor.onChange = { [weak self] _ in self?.evaluate() }`
  - `evaluate()` 决定是否调用 `overlayController.show()` / `hide()`。
- [ ] M2.4 加日志：进入/退出 idle、上下文变化、最终决策（show/hide/skip）。
- [ ] M2.5 验证 M2：通过日志确认 5s 静止触发、任意操作中断、全屏视频时不触发。

### M3 — 呼吸灯渲染

- [ ] M3.1 `Breathing/BreathPhase.swift`：定义 `enum BreathPhase`，含 `duration`、`targetScale`、`localizedKey`。
- [ ] M3.2 `Breathing/BreathingEngine.swift`：按第 3.4 节用 `Task` + `Task.sleep(for:)` 实现循环；`start/stop` 幂等。
- [ ] M3.3 `Overlay/OverlayPanel.swift`：按第 3.1 节实现 `NSPanel` 子类。
- [ ] M3.4 `Overlay/BreathingOverlayView.swift`：实现 SwiftUI 视图（圆形径向渐变 + 模糊 + scale 动画 + 可选文案）；颜色取自 `Palette`，自动响应 `@Environment(\.colorScheme)`。
- [ ] M3.5 `Overlay/OverlayWindowController.swift`：
  - 持有 `OverlayPanel` 与 `NSHostingView<BreathingOverlayView>`。
  - `show()`：计算主屏 `screen.frame.center`，定位窗口（窗口大小 = `maxDiameter + 64` 留余量），`alphaValue = 0` → 启动 `engine.start()` → 用 `NSAnimationContext` 在 `Constants.fadeIn` 内淡入到 1。
  - `hide()`：`NSAnimationContext` 在 `Constants.fadeOut` 内淡出到 0 → `engine.stop()` → `orderOut`。
  - 监听 `NSApplication.didChangeScreenParametersNotification`，重新定位。
- [ ] M3.6 在 `StatusItemController` 的"打开 VibeCodingBreath" action 中：调用 `coordinator.openManually()`，coordinator 设置 `manualOverride = true` 并强制 `overlayController.show()`；下一次 `idleMonitor` 报告 `active` 时清除 override 并隐藏。
- [ ] M3.7 验证 M3：5s 静止 → 屏幕中央出现柔和呼吸灯，按 4-2-6-2 节奏缩放；移动鼠标 200ms 内消失；点击穿透到下层 App（在 Finder 上点击应该选中 Finder 图标）。

### M4 — 联调、边界、健壮性

- [ ] M4.1 全屏屏蔽：在 `evaluate()` 中，若 `isFullscreenContext == true` 则永远 `hide()`，并在 `manualOverride` 模式下也尊重该规则（避免破坏全屏体验）。
- [ ] M4.2 多显示器：仅使用 `NSScreen.main`；监听屏幕参数变化重定位；当主屏被拔除时，捕获 `nil` 并暂时 `hide()`。
- [ ] M4.3 系统休眠：监听 `NSWorkspace.willSleepNotification` → `hide()` + `engine.stop()`；`didWakeNotification` 后回到 `evaluate()`。
- [ ] M4.4 应用切换 / Mission Control：通过 `OverlayPanel.collectionBehavior` 已覆盖；手动验证 Mission Control / `Cmd+Tab` / 多 Space 切换无残影。
- [ ] M4.5 性能 check：用 Instruments `Time Profiler` 跑 5 分钟空闲态，确保 CPU < 1%；用 `Activity Monitor` 确认常驻 RSS < 80MB。
- [ ] M4.6 资源释放：`AppDelegate.applicationWillTerminate` 中显式 `coordinator.stop()`（停 timer、cancel task、关闭 panel、移除 status item）。
- [ ] M4.7 i18n 验证：在系统语言切到英文 / 中文时，菜单与呼吸阶段文案正确切换。
- [ ] M4.8 浅色 / 深色模式验证：呼吸灯亮度自适应，菜单栏图标始终清晰。

### M5 — 测试 / 打包 / 发布

- [ ] M5.1 单元测试 `BreathingEngineTests`：验证阶段顺序、`stop()` 后 `phase` 不再变更、重复 `start()` 不会启动多个 task。
- [ ] M5.2 单元测试 `IdleMonitorTests`：注入假时钟（自定义 `secondsSince` provider），验证阈值跨越触发回调；状态去抖（同状态不重复回调）。
- [ ] M5.3 单元测试 `ConstantsTests` + `PaletteTests`：守护默认值不被无意修改。
- [ ] M5.4 `Scripts/build-app.sh`：
  ```bash
  swift build -c release --arch arm64 --arch x86_64
  组装 .app（创建 Contents/{MacOS,Resources}）
  拷贝可执行文件、Info.plist、Assets.car、xcstrings 编译产物
  ```
- [ ] M5.5 `Scripts/codesign.sh`：`codesign --deep --options runtime --timestamp --sign "Developer ID Application: ..."` → `xcrun notarytool submit --wait` → `xcrun stapler staple`。
- [ ] M5.6 `Scripts/make-dmg.sh`：生成 `.dmg`，含 Applications 软链。
- [ ] M5.7 GitHub Actions（可选 v1.0.1）：`macos-15` runner，跑 `swift test` + 产物上传。
- [ ] M5.8 README 更新：安装、首次授权（仅自启提示）、使用说明、卸载方式。
- [ ] M5.9 走一遍 PRD §12 的 10 条验收标准并打勾，截图存档。
- [ ] M5.10 创建 GitHub Release `v1.0.0`，附 `.dmg` + SHA256。

## 7. 编码规范要点

- 所有 UI 相关组件标注 `@MainActor`；后台逻辑用 `actor` 或 `async`。
- 不使用 `DispatchQueue.main.async`，统一用 `Task { @MainActor in ... }`。
- `weak self` 闭包默认开启，避免 timer / NotificationCenter 持有循环。
- 任何 `try?` 必须配合 `Logger.error` 记录原因。
- 不出现魔法数字，全部沉淀到 `Constants`。
- 国际化字符串必须走 `String(localized:)`，禁止硬编码中文/英文。

## 8. 风险与缓解（实施层面）

| 风险 | 缓解 |
|---|---|
| `secondsSinceLastEventType` 在某些键盘事件下不更新 | 同时轮询多种 EventType（鼠标 + 键盘 + 修饰键），取最小值。 |
| SwiftUI 动画在窗口刚显示时第一帧不平滑 | `show()` 中先 `panel.alphaValue = 0` → 显示窗口 → 下一 RunLoop tick 再 `engine.start()` 并淡入。 |
| `NSPanel` 在某些 Space 行为异常 | `.canJoinAllSpaces + .stationary + .fullScreenAuxiliary` 组合已验证；如再有问题，退化为每次 Space 切换重新 `orderFrontRegardless`。 |
| 公证因 hardened runtime 报错 | 启用 `--options runtime`；不需要任何额外 entitlement（无网络、无文件访问、无相机麦克风）。 |
| 用户误以为 App 没启动（找不到入口） | 状态栏图标使用清晰可识别的"呼吸圆环"模板图；README 加截图说明。 |

## 9. 完成标志（Definition of Done）

1. M0~M5 所有 todo 勾选完成。
2. PRD §12 全部验收项通过。
3. 单元测试全绿，`swift test` 退出码 0。
4. `.dmg` 在干净 macOS 15 上双击安装，菜单栏图标出现，5 秒静止后呼吸灯出现，行为符合 PRD。
5. Release `v1.0.0` 在 GitHub 发布。

---

> 本技术方案为可执行版本。按 §6 的 todo 顺序推进，每完成一个 Mx 立即冒烟验证，可一次性产出可用、稳定、高效的 v1.0 代码。
