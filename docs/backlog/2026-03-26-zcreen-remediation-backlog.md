# Zcreen 整改 Backlog

最后更新：2026-03-30

## 目标

本轮整改优先解决 Zcreen 当前最核心的问题：`零配置自动保存并恢复多屏布局` 的承诺还没有完全兑现。

执行原则：

- 先保主链路可靠性，再补行为一致性，最后做工程化。
- 优先做会直接影响用户成功率的改动，不先做样式抛光和功能扩张。
- 每个 issue 必须有明确的验收标准，不做“看起来差不多”式收尾。

## 里程碑

| Milestone | 范围 | 目标 |
| --- | --- | --- |
| M1 | P0 | 让自动保存/恢复真正稳定可用 |
| M2 | P1 | 统一规则、坐标、过滤与设置行为 |
| M3 | P2 | 补架构、文档、发布自动化 |

## 当前进展

| Issue | 状态 | 说明 |
| --- | --- | --- |
| ZRN-001 | 已完成 | 补了定时自动保存、事件后延迟保存和手动保存/恢复入口 |
| ZRN-002 | 已完成 | 恢复从顺序匹配改成标题/角色/尺寸综合匹配，并新增 matcher 单测 |
| ZRN-003 | 已完成 | 快照新增物理屏幕 key 和相对坐标，恢复优先按物理屏幕相对布局 |
| ZRN-004 | 已完成 | 菜单栏补了可见的配置/快照入口，并暴露 app launch 自动应用开关 |
| ZRN-005 | 已完成 | 核心链路支持依赖注入，补了 Orchestrator 等高层回归测试 |
| ZRN-006 | 已完成 | 统一了 batch/manual/fallback/app launch 的规则匹配语义 |
| ZRN-007 | 已完成 | 修正 AX 与 NSScreen 的多屏坐标转换，覆盖堆叠屏和主屏切换 |
| ZRN-008 | 已完成 | 新增默认窗口过滤和 config 排除策略，跳过浮窗/对话框/最小化窗口 |
| ZRN-009 | 已完成 | 菜单设置改为持久化，配置错误支持字段定位、修复建议和快速打开 |
| ZRN-010 | 已完成 | Orchestrator 拆为 snapshot / screen session / rule apply / menu state，收敛为协调层 |
| ZRN-011 | 已完成 | 补齐模块索引、核心模块文档，以及快照/显示器识别/已知限制维护参考 |

## Backlog

### P0

#### ZRN-001 自动保存主链路补齐

- 优先级：P0
- 目标：让用户即使从未使用 Snap Bar，也能自动建立有效快照。
- 现状问题：
  - 当前主要只有 Snap Bar 成功吸附后才会保存布局。
  - 预变更快照逻辑已被禁用。
  - 注释提到的 periodic auto-save 实际不存在。
- 范围：
  - `Sources/Zcreen/Core/Orchestrator.swift`
  - `Sources/Zcreen/Core/ScreenDetector.swift`
  - `Sources/Zcreen/UI/MenuBarView.swift`
  - `Sources/Zcreen/UI/MenuBarSections/SettingsSection.swift`
- 交付：
  - 增加屏幕稳定后的自动快照。
  - 增加应用启动后一段时间内的延迟快照或合并快照。
  - 菜单栏增加“立即保存布局”“立即恢复当前布局”入口。
  - 自动保存要有节流，避免高频写盘。
- 验收标准：
  - 用户手动摆窗但不使用 Snap Bar，拔插同一组显示器后能恢复。
  - 连续插拔、休眠唤醒、重新连接显示器等场景不会生成空快照覆盖有效快照。
  - 日志可以区分手动保存、自动保存、恢复触发来源。
- 依赖：无

#### ZRN-002 快照身份与恢复匹配重做

- 优先级：P0
- 目标：修复多窗口应用恢复错位问题。
- 现状问题：
  - 当前恢复按 `bundleId + 数组顺序` 直接配对。
  - 已保存的 `windowTitle`、`screenName` 没有真正参与匹配。
- 范围：
  - `Sources/Zcreen/Core/LayoutSnapshotStore.swift`
  - `Sources/Zcreen/Core/WindowManager.swift`
  - `Sources/Zcreen/Model/WindowSnapshot.swift`
- 交付：
  - 为窗口快照增加更稳定的身份字段或匹配策略。
  - 恢复时优先按标题、屏幕、尺寸特征等进行匹配。
  - 当无法确定对应窗口时，选择保守策略而不是强行乱配。
- 验收标准：
  - Chrome、Finder、Xcode 等多窗口应用恢复结果稳定。
  - 同一应用窗口数量变化时，不会大面积串位。
  - 无法精确匹配的窗口会被明确记录到日志。
- 依赖：ZRN-001

#### ZRN-003 显示器拓扑感知与相对恢复

- 优先级：P0
- 目标：解决“同一套屏幕，不同主屏/左右顺序/方向”导致的恢复失真。
- 现状问题：
  - 当前 profile key 只包含显示器硬件 ID。
  - 快照保存的是绝对坐标，恢复时原样回放。
- 范围：
  - `Sources/Zcreen/Core/ScreenDetector.swift`
  - `Sources/Zcreen/Core/LayoutSnapshotStore.swift`
  - `Sources/Zcreen/Core/WindowManager.swift`
  - `Sources/Zcreen/Model/ScreenInfo.swift`
- 交付：
  - 补充拓扑相关信息，如主屏、相对顺序、方向、可视区域。
  - 快照支持“显示器唯一键 + 相对区域”的恢复方式。
  - 为同一物理显示器组合但不同拓扑场景定义清晰策略。
- 验收标准：
  - 左右顺序变化、主屏切换、竖屏切换后恢复结果仍合理。
  - 不再因为旧绝对坐标直接回放而把窗口扔到错误区域。
- 依赖：ZRN-002

#### ZRN-004 菜单栏补可见控制与兜底能力

- 优先级：P0
- 目标：让用户在自动化失手时仍能自救。
- 现状问题：
  - 没有显式的保存/恢复入口。
  - 配置目录入口隐藏在图标五连击里。
  - `autoApplyOnAppLaunch` 有实现但没有 UI。
- 范围：
  - `Sources/Zcreen/UI/MenuBarView.swift`
  - `Sources/Zcreen/UI/MenuBarSections/HeaderSection.swift`
  - `Sources/Zcreen/UI/MenuBarSections/SettingsSection.swift`
  - `Sources/Zcreen/UI/MenuBarSections/FooterSection.swift`
  - `Sources/Zcreen/Config/ConfigManager.swift`
- 交付：
  - 增加“立即保存布局”“立即恢复布局”“打开配置”“打开快照目录”“打开日志目录”。
  - 显式暴露 “Auto-apply on app launch”。
  - 删除或降级隐藏操作入口，避免关键功能藏得太深。
- 验收标准：
  - 首次使用用户可以在菜单里找到所有关键控制。
  - 恢复失败时，用户不用猜内部路径就能排查。
- 依赖：ZRN-001

#### ZRN-005 核心链路测试与依赖注入

- 优先级：P0
- 目标：让核心保存/恢复逻辑可验证、可回归。
- 现状问题：
  - 现有测试主要覆盖模型和工具函数。
  - `Orchestrator` 直接构造所有依赖，难以替换。
- 范围：
  - `Sources/Zcreen/Core/Orchestrator.swift`
  - `Tests/ZcreenTests/`
- 交付：
  - 为 `Orchestrator`、`LayoutSnapshotStore`、`ScreenDetector` 等引入可替换依赖。
  - 增加自动保存、恢复重试、多窗口匹配、屏幕变更测试。
- 验收标准：
  - 至少覆盖：空快照保护、重复恢复、重试、同应用多窗口、屏幕切换。
  - 新增测试可以在不依赖真实显示器变化的情况下运行。
- 依赖：ZRN-001, ZRN-002, ZRN-003

### P1

#### ZRN-006 统一规则系统语义

- 优先级：P1
- 目标：消除“启动时生效、手动应用或换屏时失效”的规则割裂。
- 范围：
  - `Sources/Zcreen/Core/RuleEngine.swift`
  - `Sources/Zcreen/Core/Orchestrator.swift`
  - `Tests/ZcreenTests/RuleEngineTests.swift`
- 交付：
  - 统一 `bundleId` / `nameContains` 的匹配语义。
  - 统一手动应用、应用启动、换屏 fallback 三条路径。
- 验收标准：
  - 同一条规则在三条路径上的行为一致。
- 依赖：ZRN-005

#### ZRN-007 多显示器坐标转换修正

- 优先级：P1
- 目标：修复上下堆叠屏、负坐标、主屏切换下的 Snap Bar 坐标风险。
- 范围：
  - `Sources/Zcreen/Util/CoordinateConverter.swift`
  - `Sources/Zcreen/Core/SnapBarController.swift`
  - `Tests/ZcreenTests/CoordinateConverterTests.swift`
- 交付：
  - 删除对“主屏高度”的单一依赖。
  - 按具体目标屏幕做坐标换算。
- 验收标准：
  - 至少覆盖横向、纵向、上下堆叠、主屏切换四类场景。
- 依赖：无

#### ZRN-008 窗口过滤与排除策略

- 优先级：P1
- 目标：避免把工具窗、弹窗、临时窗纳入保存与恢复。
- 范围：
  - `Sources/Zcreen/Core/WindowManager.swift`
  - `Sources/Zcreen/Core/LayoutSnapshotStore.swift`
- 交付：
  - 增加窗口角色、尺寸、可见性等过滤条件。
  - 支持按应用或窗口类型排除。
- 验收标准：
  - 保存结果更接近用户认知中的“主窗口集合”。
- 依赖：ZRN-002

#### ZRN-009 设置持久化与配置体验增强

- 优先级：P1
- 目标：让用户设置和配置错误提示真正可用。
- 范围：
  - `Sources/Zcreen/UI/MenuBarView.swift`
  - `Sources/Zcreen/UI/MenuBarSections/ConfigErrorBanner.swift`
  - `Sources/Zcreen/Config/ConfigManager.swift`
  - `Sources/Zcreen/Util/LoginItemManager.swift`
- 交付：
  - 持久化菜单栏设置。
  - 为配置错误增加字段定位、修复建议、快速打开配置。
- 验收标准：
  - 应用重启后设置不丢失。
  - 配置文件错误时用户能快速定位问题。
- 依赖：ZRN-004

### P2

#### ZRN-010 编排层拆分与职责收敛

- 优先级：P2
- 目标：降低 `Orchestrator` 的耦合度与测试成本。
- 范围：
  - `Sources/Zcreen/Core/Orchestrator.swift`
  - 相关核心服务
- 交付：
  - 拆出 snapshot service、screen session service、rule apply service、menu state。
- 验收标准：
  - `Orchestrator` 只保留组合与协调职责。
- 依赖：ZRN-005, ZRN-006

#### ZRN-011 模块索引与文档治理补齐

- 优先级：P2
- 目标：让后续维护不再依赖人工重新摸工程。
- 范围：
  - `tap-agents/prompts/module-map.md`
  - `tap-agents/prompts/modules/*.md`
  - `docs/`
- 交付：
  - 创建模块索引。
  - 为核心模块建立说明文档。
  - 记录快照模型、显示器识别策略、已知限制。
- 验收标准：
  - 后续开发前可以直接从索引定位到目标模块。
- 依赖：无

#### ZRN-012 发布流程自动化

- 优先级：P2
- 目标：把本地发版脚本升级为可重复的 CI/CD 流程。
- 范围：
  - `Scripts/bundle.sh`
  - `Scripts/release.sh`
  - CI 配置文件
- 交付：
  - 自动构建、签名、notarize、生成 release artifact。
- 验收标准：
  - 发布流程不再依赖手工串行执行本地脚本。
- 依赖：无

## 推荐执行顺序

1. ZRN-001
2. ZRN-002
3. ZRN-003
4. ZRN-004
5. ZRN-005
6. ZRN-006
7. ZRN-007
8. ZRN-008
9. ZRN-009
10. ZRN-010
11. ZRN-011
12. ZRN-012

## 本轮建议落地范围

如果本轮只做一段可交付整改，建议只做 M1：

- ZRN-001
- ZRN-002
- ZRN-003
- ZRN-004
- ZRN-005

完成 M1 后，Zcreen 才基本配得上 README 里“零配置自动保存与恢复”的定位。
