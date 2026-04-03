# Zcreen 全面优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 对 Zcreen macOS 窗口管理工具进行 10 项优化，涵盖性能、代码质量、健壮性和可维护性。

**Architecture:** 新增 Constants.swift 集中管理魔法数字，新增 CoordinateConverter.swift 消除坐标转换重复代码，优化 SnapBarController 轮询策略，拆分 MenuBarView 为子组件，增强 ConfigManager 验证、LayoutSnapshotStore 重试策略，添加单元测试。

**Tech Stack:** Swift 5.9, SwiftUI, SPM, macOS 13.0+, AXUIElement

---

### Task 1: 新增 Constants.swift — 集中管理硬编码常量

**Files:**
- Create: `Sources/Zcreen/Util/Constants.swift`
- Modify: `Sources/Zcreen/Core/SnapBarController.swift`
- Modify: `Sources/Zcreen/Model/LayoutPreset.swift`
- Modify: `Sources/Zcreen/UI/SnapBarPanel.swift`

- [ ] **Step 1: 创建 Constants.swift**

```swift
import Foundation
import CoreGraphics

enum Constants {
    enum SnapBar {
        /// 轮询频率 (Hz)
        static let pollFrequency: TimeInterval = 0.05  // 20 Hz
        /// 触发拖拽的最小移动距离 (pt)
        static let dragThreshold: CGFloat = 12
        /// Title bar 检测高度 (pt)
        static let titleBarHeight: CGFloat = 50
        /// Title bar 检测扩展边距 (pt)
        static let titleBarPadding: CGFloat = 5
        /// Snap 后保存延迟 (s)
        static let snapSaveDelay: TimeInterval = 0.3
        /// Tracking 超时 tick 数
        static let trackingTimeoutTicks: Int = 20
    }

    enum Layout {
        /// 分屏窗口间的间距 (pt)
        static let windowGap: CGFloat = 6
    }

    enum Timing {
        /// 屏幕变化 debounce (ms)
        static let screenChangeDebounceMs: Int = 500
        /// 配置文件变化延迟 (s)
        static let configReloadDelay: TimeInterval = 0.2
        /// App 启动规则延迟 (s)
        static let appLaunchRuleDelay: TimeInterval = 1.0
        /// 快照恢复重试基础延迟 (s)
        static let snapshotRetryBaseDelay: TimeInterval = 1.0
        /// 快照恢复最大重试次数
        static let snapshotMaxRetries: Int = 3
    }
}
```

- [ ] **Step 2: 替换 SnapBarController 中的魔法数字**

替换 `0.05`, `12`, `50`, `5`, `0.3`, `20` 为 Constants 引用。

- [ ] **Step 3: 替换 LayoutPreset 中的 gap 常量**

`private static let gap: CGFloat = 6` → `Constants.Layout.windowGap`

- [ ] **Step 4: 替换 SnapBarPanel 中的 padding 常量**

替换 `22`, `18`, `6` 等硬编码值为 Constants 引用。

- [ ] **Step 5: 验证编译通过**

Run: `cd /Users/dendi/Desktop/Zcreen && swift build 2>&1 | tail -5`

---

### Task 2: 新增 CoordinateConverter.swift — 统一坐标转换

**Files:**
- Create: `Sources/Zcreen/Util/CoordinateConverter.swift`
- Modify: `Sources/Zcreen/Core/SnapBarController.swift`

- [ ] **Step 1: 创建 CoordinateConverter.swift**

```swift
import Cocoa

enum CoordinateConverter {
    /// 主屏幕高度 (用于 NS ↔ CG 坐标转换)
    static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// NS 坐标 (左下原点) → CG 坐标 (左上原点)
    static func nsToCG(_ point: NSPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryScreenHeight - point.y)
    }

    /// NS frame → CG frame
    static func nsToCG(_ frame: NSRect) -> CGRect {
        CGRect(
            x: frame.origin.x,
            y: primaryScreenHeight - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )
    }

    /// CG 坐标 (左上原点) → NS 坐标 (左下原点)
    static func cgToNS(_ point: CGPoint) -> NSPoint {
        NSPoint(x: point.x, y: primaryScreenHeight - point.y)
    }
}
```

- [ ] **Step 2: 替换 SnapBarController 中的坐标转换代码**

`onMouseDown` 和 `applyPreset` 中的手动转换 → 使用 `CoordinateConverter`。

- [ ] **Step 3: 验证编译通过**

---

### Task 3: 优化 SnapBarController 轮询策略

**Files:**
- Modify: `Sources/Zcreen/Core/SnapBarController.swift`

- [ ] **Step 1: 添加 idle 状态低频轮询**

当 `dragState == .idle` 时降低到 4Hz (250ms)，检测到 mouseDown 切换到 20Hz。

- [ ] **Step 2: 实现动态切换逻辑**

```swift
private var isHighFrequency = false

private func switchToHighFrequency() {
    guard !isHighFrequency else { return }
    isHighFrequency = true
    pollTimer?.invalidate()
    let timer = Timer(timeInterval: Constants.SnapBar.pollFrequency, repeats: true) { [weak self] in
        self?.tick()
    }
    RunLoop.main.add(timer, forMode: .common)
    pollTimer = timer
}

private func switchToLowFrequency() {
    guard isHighFrequency else { return }
    isHighFrequency = false
    pollTimer?.invalidate()
    let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] in
        self?.tick()
    }
    RunLoop.main.add(timer, forMode: .common)
    pollTimer = timer
}
```

- [ ] **Step 3: 在状态转换时切换频率**

mouseDown → 高频，mouseUp/idle 后 → 低频。

- [ ] **Step 4: 验证编译通过**

---

### Task 4: ConfigManager 增加验证和错误提示

**Files:**
- Modify: `Sources/Zcreen/Config/ConfigManager.swift`

- [ ] **Step 1: 添加 configError published 属性**

```swift
@Published private(set) var configError: String?
```

- [ ] **Step 2: 改造 loadConfig 方法，捕获并暴露错误**

解析失败时设置 `configError`，成功时清除。

- [ ] **Step 3: 添加基础 schema 验证**

检查 version 字段、rules 中的 bundleId 和 targetScreen、screens 中的 alias 唯一性。

- [ ] **Step 4: 验证编译通过**

---

### Task 5: LayoutSnapshotStore 指数退避重试

**Files:**
- Modify: `Sources/Zcreen/Core/LayoutSnapshotStore.swift`

- [ ] **Step 1: 重构 restoreSnapshot 使用指数退避**

```swift
func restoreSnapshot(_ snapshot: LayoutSnapshot, windowManager: WindowManager, excludeBundleIds: Set<String>) {
    let missed = doRestore(snapshot: snapshot, windowManager: windowManager, excludeBundleIds: excludeBundleIds)
    if !missed.isEmpty {
        scheduleRetry(snapshot: snapshot, windowManager: windowManager, excludeBundleIds: excludeBundleIds,
                      missed: missed, attempt: 1)
    }
}

private func scheduleRetry(snapshot: LayoutSnapshot, windowManager: WindowManager,
                           excludeBundleIds: Set<String>, missed: [String], attempt: Int) {
    guard attempt <= Constants.Timing.snapshotMaxRetries else {
        Log.snapshot.info("RESTORE: gave up after \(Constants.Timing.snapshotMaxRetries) retries, \(missed.count) apps still inaccessible")
        return
    }
    let delay = Constants.Timing.snapshotRetryBaseDelay * pow(2.0, Double(attempt - 1))
    Log.snapshot.info("RESTORE: \(missed.count) apps missed, retry \(attempt)/\(Constants.Timing.snapshotMaxRetries) in \(delay)s...")
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
        let stillMissed = self?.doRestore(snapshot: snapshot, windowManager: windowManager, excludeBundleIds: excludeBundleIds) ?? []
        if !stillMissed.isEmpty {
            self?.scheduleRetry(snapshot: snapshot, windowManager: windowManager,
                               excludeBundleIds: excludeBundleIds, missed: stillMissed, attempt: attempt + 1)
        }
    }
}
```

- [ ] **Step 2: 验证编译通过**

---

### Task 6: App Launch 轮询等待窗口出现

**Files:**
- Modify: `Sources/Zcreen/Core/Orchestrator.swift`

- [ ] **Step 1: 替换固定 1s 延迟为轮询等待**

```swift
private func waitForWindows(bundleId: String, maxAttempts: Int = 10, interval: TimeInterval = 0.5,
                            attempt: Int = 1, action: @escaping ([WindowManager.WindowInfo]) -> Void) {
    let windows = windowManager.getWindows(bundleId: bundleId)
    if !windows.isEmpty {
        action(windows)
    } else if attempt < maxAttempts {
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.waitForWindows(bundleId: bundleId, maxAttempts: maxAttempts, interval: interval,
                                attempt: attempt + 1, action: action)
        }
    } else {
        Log.rule.info("Launch rule: gave up waiting for windows of \(bundleId) after \(maxAttempts) attempts")
    }
}
```

- [ ] **Step 2: 修改 handleAppLaunch 使用新方法**

- [ ] **Step 3: 移除 setupAppLaunchHandler 中的 `.delay(for: .seconds(1))`**

- [ ] **Step 4: 验证编译通过**

---

### Task 7: 拆分 MenuBarView 为子组件

**Files:**
- Create: `Sources/Zcreen/UI/MenuBarSections/HeaderSection.swift`
- Create: `Sources/Zcreen/UI/MenuBarSections/ScreenListSection.swift`
- Create: `Sources/Zcreen/UI/MenuBarSections/SettingsSection.swift`
- Create: `Sources/Zcreen/UI/MenuBarSections/CaffeinateSection.swift`
- Create: `Sources/Zcreen/UI/MenuBarSections/FooterSection.swift`
- Modify: `Sources/Zcreen/UI/MenuBarView.swift`

- [ ] **Step 1: 创建 MenuBarSections 目录和各子 View 文件**

每个 section 提取为独立 View，接收 orchestrator 引用。

- [ ] **Step 2: 精简 MenuBarView.swift 为组合入口**

MenuBarView body 只保留 VStack + 各 section 组合。

- [ ] **Step 3: 提取共享辅助方法到 MenuBarHelpers.swift**

`sectionDivider`, `screenColor`, `resolutionBadge`, `metaBadge` 等。

- [ ] **Step 4: 验证编译通过**

---

### Task 8: 添加单元测试

**Files:**
- Modify: `Package.swift` (添加 test target)
- Create: `Tests/ZcreenTests/RuleEngineTests.swift`
- Create: `Tests/ZcreenTests/AppMatcherTests.swift`
- Create: `Tests/ZcreenTests/CoordinateConverterTests.swift`
- Create: `Tests/ZcreenTests/ConfigurationTests.swift`

- [ ] **Step 1: 修改 Package.swift 添加 test target**

- [ ] **Step 2: 编写 RuleEngine 测试**

- [ ] **Step 3: 编写 AppMatcher 测试**

- [ ] **Step 4: 编写 CoordinateConverter 测试**

- [ ] **Step 5: 编写 Configuration 测试**

- [ ] **Step 6: 运行测试验证**

Run: `cd /Users/dendi/Desktop/Zcreen && swift test 2>&1 | tail -20`
