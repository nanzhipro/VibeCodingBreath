# 一键复刻提示词

> 把这段提示词喂给 Claude Code（或同类编程 Agent），即可从零生成整个 App。

请实现一款名为 **VibeCodingBreath** 的 macOS 菜单栏正念呼吸伴侣应用（Swift 5.10、macOS 14+、Apple Silicon + Intel 通用二进制），具体要求如下：

1. 这是一款近乎隐形的状态栏小工具，核心理念只有一句话：「AI 在思考，你在呼吸。」当用户在等待 AI Agent（Cursor / Copilot / Claude Code 等）处理任务时，如果键鼠在 5 秒内没有任何操作，App 会在主屏幕中央淡入一圈柔和的呼吸光环，引导一小段正念呼吸；一旦用户触碰鼠标或键盘，光环在 200 ms 内淡出。MVP 阶段零通知、零引导页、零配置界面。

2. 以纯菜单栏 Agent 方式运行：`LSUIElement = true`，不出现在 Dock、不参与 Cmd+Tab 切换、不创建默认窗口。Bundle ID `pro.nanzhi.VibeCodingBreath`，`LSMinimumSystemVersion = 14.0`。启动时通过 `NSWorkspace.runningApplications` 检查同 Bundle ID 进程，保证单实例。首次启动调用 `SMAppService.mainApp.register()` 注册开机自启动；失败时仅静默记录日志，下次启动重试——永远不弹 UI。

3. 状态栏：一个模板 `NSStatusItem`（自动适配明/暗模式），菜单恰好包含两项，均完整本地化：
   - 「打开 VibeCodingBreath」（`status.menu.open`）——手动强制显示光环，忽略空闲判断，直到下次用户输入。
   - 「退出」（`status.menu.quit`）——`NSApp.terminate(_:)`，不残留任何窗口或状态栏图标。

4. 空闲/上下文检测（不需要辅助功能、屏幕录制、通知权限）：
   - 每 500 ms 轮询 `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType:)`，事件类型并集为：`.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .leftMouseDragged, .rightMouseDragged, .scrollWheel, .keyDown, .flagsChanged`。取所有类型中「距上次事件秒数」的最小值；超过 5 秒阈值则发出 `idle = true`，否则 `false`。去重处理，确保变更回调仅在真正的边沿触发。
   - `ForegroundContextMonitor` 监听 `NSWorkspace.activeSpaceDidChangeNotification` 与 `NSWorkspace.didActivateApplicationNotification`，通过启发式检测（菜单栏隐藏的 frame 检查 + 前台 App 的 `activationPolicy == .regular`）暴露 `isFullscreenContext`。为 `true` 时光环绝对不能出现，即使用户手动选了「打开 VibeCodingBreath」。

5. 呼吸光环叠层窗口——透明穿透点击的 `NSPanel` 子类：
   - `styleMask = [.borderless, .nonactivatingPanel]`，`isOpaque = false`，`backgroundColor = .clear`，`hasShadow = false`，`level = .statusBar`，`ignoresMouseEvents = true`，`animationBehavior = .none`，`isReleasedWhenClosed = false`，`canBecomeKey = false`，`canBecomeMain = false`。
   - `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]`。
   - 居中于 `NSScreen.main.frame`；窗口尺寸 = `maxDiameter (320) + padding (64)`。监听 `NSApplication.didChangeScreenParametersNotification` 重新居中。主屏幕消失时隐藏。
   - 显示：`alphaValue = 0` → `orderFrontRegardless()` → 启动引擎 → `NSAnimationContext` 在 0.4 秒内淡入至 1.0。
   - 隐藏：`NSAnimationContext` 在 0.2 秒内淡出至 0 → 停止引擎 → `orderOut`。光环始终穿透点击（可通过点击其下方的 Finder 图标验证）。

6. 呼吸节奏引擎——`@MainActor @Observable final class BreathingEngine`，驱动严格的 4-2-6-2 循环（吸气 4 秒 → 屏气 2 秒 → 呼气 6 秒 → 屏气 2 秒，一轮共 14 秒），核心为单个 `Task { while !Task.isCancelled { for phase in BreathPhase.allCases { self.phase = phase; try? await Task.sleep(for: .seconds(phase.duration)) } } }`。`start()` / `stop()` 幂等。定义 `enum BreathPhase: Int, CaseIterable, Sendable { case inhale, holdAfterInhale, exhale, holdAfterExhale }`，提供 `duration` 和 `targetScale`（呼气/静止时 1.0，吸气/峰值时 2.0）。

7. 光环视觉（SwiftUI）：一个 `Circle()`，填充 `RadialGradient`（默认色板 `#7FB3D5`，透明度断点根据 `ColorScheme` 调整——浅色：0.65 → 0.35 → 0；深色：0.55 → 0.30 → 0），`.blur(radius: 24)`，基础尺寸 120 pt，在 1.0× 到 2.0× 之间缩放，视觉直径从 120 到 240 pt，永不超过屏幕短边的 25%。通过 `onChange(of: engine.phase)` 驱动 `withAnimation(.easeInOut(duration: phase.duration)) { scale = phase.targetScale }`。`accessibilityHidden(true)`。MVP 阶段不要任何进度条、波形图、文字标签——只有那圈柔和的呼吸光环。View 不持有任何业务状态，只观察引擎。

8. 架构——单可执行目标，所有 UI 类型标记 `@MainActor`，禁用 `DispatchQueue.main.async`（改用 `Task { @MainActor in ... }`）：
   - `App/VibeCodingBreathApp.swift`：`@main struct`，仅包含 `Settings { EmptyView() }` 和 `@NSApplicationDelegateAdaptor(AppDelegate.self)`。
   - `App/AppDelegate.swift`：在 `applicationDidFinishLaunching` 中构建 `AppCoordinator`，`applicationShouldTerminateAfterLastWindowClosed` 返回 `false`，执行单实例检查，在 `applicationWillTerminate` 中调用 `coordinator.stop()`，监听 `NSWorkspace.willSleepNotification` 时隐藏、`didWakeNotification` 时重新评估。
   - `App/AppCoordinator.swift`：持有 `StatusItemController`、`IdleMonitor`、`ForegroundContextMonitor`、`OverlayWindowController`、`LoginItemManager`、`BreathingEngine`。对外暴露 `start() / stop() / openManually()`。状态机 `.hidden → .showing → .dismissing → .hidden`；`evaluate()` 根据 `(isIdle, isFullscreenContext, manualOverride)` 决定 `show()` 或 `hide()`；`manualOverride` 由「打开 VibeCodingBreath」设为 `true`，下次活跃边沿时清除。
   - `Status/StatusItemController.swift`、`Idle/{IdleMonitor,ForegroundContextMonitor}.swift`、`Overlay/{OverlayPanel,OverlayWindowController,BreathingOverlayView}.swift`、`Breathing/{BreathPhase,BreathingEngine}.swift`、`System/LoginItemManager.swift`、`Support/{Constants,Palette,Logger+App,Protocols}.swift`。
   - `Support/Constants`：`idleThreshold = 5.0`、`pollInterval = 0.5`、`minDiameter = 120`、`maxDiameter = 320`、`overlayPadding = 64`、`fadeIn = 0.4`、`fadeOut = 0.2`、`primaryHex = "#7FB3D5"`、`bundleIdentifier = "pro.nanzhi.VibeCodingBreath"`。
   - `Support/Logger+App`：`os.Logger`，subsystem = Bundle ID，categories 为 `app / idle / overlay / status / login`。
   - `Support/Protocols.swift`：`@MainActor` 协议（如 `ForegroundContextProviding`），用于在测试中注入假实现。

9. 仅使用 Swift Package Manager——无 `.xcodeproj`。使用 `// swift-tools-version: 5.10`、`defaultLocalization: "en"`、`platforms: [.macOS(.v14)]`，单个 `executableTarget`（`path: "Sources/VibeCodingBreath"`、`resources: [.process("Resources")]`），`swiftSettings` 包含：`.enableUpcomingFeature("BareSlashRegexLiterals")`、`.enableUpcomingFeature("ConciseMagicFile")`、`.enableExperimentalFeature("StrictConcurrency=complete")`。测试目标 `VibeCodingBreathTests`（使用 XCTest，因为 Swift 5.10 尚无 Swift Testing）。零第三方依赖。需绕过两个 SwiftPM 5.10 的已知限制：(a) `Info.plist` 不能作为 SwiftPM 的顶层资源，必须放在 `Sources/` 之外（置于 `Bundle/Info.plist`，由构建脚本组装）；(b) SwiftPM 5.10 不编译 `.xcstrings`——使用传统的 `Resources/<lang>.lproj/Localizable.strings` 文件。至少提供 `en` 和 `zh-Hans` 两种语言。

10. 规避已知的 Swift 5.10 IRGen 崩溃（'SmallVector unable to grow'）：如果 `@MainActor final class` 的指定初始化器有一个参数，且其默认值是 `@escaping` 闭包，编译器会崩溃。解决方法是使用一个 `Bool` 标记位，在 `start()` 内部构造闭包，而非作为默认参数。

11. Bundle 组装 + 签名——`Scripts/` 下三个脚本：
    - `Scripts/build-app.sh [debug|release]`：运行 `swift build`（release 模式使用 `--arch arm64 --arch x86_64` 生成通用二进制），然后将 `.build/<config>/VibeCodingBreath.app` 组装为标准结构：`Contents/MacOS/VibeCodingBreath`、`Contents/Info.plist`（复制自 `Bundle/Info.plist`）、`Contents/Resources/AppIcon.icns`（由 `Bundle/Resources/AppIcon.iconset` 通过 `iconutil` 生成），以及 SwiftPM 产出的 `*_VibeCodingBreath.bundle` 放入 `Contents/Resources/`。每个内嵌 `.bundle` 必须在外层 `.app` 签名之前单独 `codesign`。
    - `Scripts/codesign.sh`：`codesign --deep --options runtime --timestamp --entitlements Bundle/VibeCodingBreath.entitlements --sign "Developer ID Application: ..."`，然后 `xcrun notarytool submit --wait --keychain-profile <profile>`，再 `xcrun stapler staple`。Entitlements 不请求网络、文件、摄像头/麦克风权限——仅启用强化运行时。
    - `Scripts/release.sh --version <x.y.z> --keychain-profile <profile>`：完整流水线 `swift test` → `build-app.sh release` → `codesign.sh` → `create-dmg`，输出 `dist/VibeCodingBreath-<version>-<arch>.dmg`。

12. 测试位于 `Tests/VibeCodingBreathTests/`（XCTest，`swift test` 全部通过）：
    - `BreathingEngineTests`：阶段顺序为 `inhale → holdAfterInhale → exhale → holdAfterExhale`；`stop()` 停止后续阶段变更；重复调用 `start()` 不会产生多个 Task。
    - `BreathPhaseTests`：持续时间和 `targetScale` 严格等于 4/2/6/2 和 2.0/2.0/1.0/1.0。
    - `IdleMonitorTests`：注入假的「距上次事件秒数」提供者后，超过 5 秒阈值时回调恰好触发一次；同状态的 tick 不重复触发。
    - `AppCoordinatorTests`：`(idle, fullscreen, manualOverride)` 真值表——仅 `(idle && !fullscreen) || (manualOverride && !fullscreen)` 导致显示；全屏始终优先。
    - `ConstantsTests`：守卫默认值，防止被静默修改。
    - `LocalizationTests`：每个菜单 / 阶段本地化 key 在 `en` 和 `zh-Hans` 中均可解析。
    - 提供 `Tests/VibeCodingBreathTests/Fakes/Fakes.swift`，实现 `Support/Protocols.swift` 中的 `@MainActor` 协议，用于确定性测试。

13. 验收标准（以下各项在全新 macOS 14 安装上均可观察到）：
    - 无 Dock 图标；状态栏出现模板图标。
    - 状态栏菜单恰好两项，跟随系统语言在 zh-Hans / en 之间切换。
    - 桌面上 5 秒无输入 → 光环在主屏幕中央淡入，按 4-2-6-2 节奏缩放。
    - 任何鼠标移动或按键立即让光环在 200 ms 内淡出。
    - 光环绝不拦截点击（点击可穿透到 Finder / 底层应用）。
    - 前台应用进入真全屏（Keynote / 视频等）时完全抑制光环。
    - macOS 重启后自动以菜单栏方式启动。
    - 「退出」终止进程，不残留任何东西。
    - 空闲 CPU < 1%，常驻内存 < 80 MB。
    - 永远不弹出系统权限提示。

14. 提供简洁的顶层 `README.md`，链接到 `docs/PRD.md`、`docs/TECH_PLAN.md`、`docs/TEST_PLAN.md`（不要把规格内联——遵循项目约定，README 只做高层索引），并列出三条核心命令：`swift test`、`./Scripts/build-app.sh debug`、`./Scripts/release.sh --version <x.y.z> --keychain-profile <profile>`。
