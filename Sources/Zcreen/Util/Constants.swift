import Foundation
import CoreGraphics

enum Constants {
    enum SnapBar {
        /// 高频轮询间隔 (20 Hz, 用于拖拽中)
        static let highFrequencyInterval: TimeInterval = 0.05
        /// 低频轮询间隔 (4 Hz, 用于 idle 检测)
        static let lowFrequencyInterval: TimeInterval = 0.25
        /// 触发拖拽的最小移动距离 (pt)
        static let dragThreshold: CGFloat = 12
        /// Title bar 检测高度 (pt)
        static let titleBarHeight: CGFloat = 50
        /// Title bar 点击检测扩展边距 (pt)
        static let titleBarPadding: CGFloat = 5
        /// Snap 后保存延迟 (s)
        static let snapSaveDelay: TimeInterval = 0.3
        /// Tracking 超时 tick 数 (idle 后放弃检测)
        static let trackingTimeoutTicks: Int = 20
    }

    enum Layout {
        /// 分屏窗口间的间距 (pt)
        static let windowGap: CGFloat = 6
    }

    enum Panel {
        /// SnapBar 面板水平内边距 (pt)
        static let horizontalPadding: CGFloat = 22
        /// SnapBar 面板垂直内边距 (pt)
        static let verticalPadding: CGFloat = 18
        /// Preset 组之间的间距 (pt)
        static let groupGap: CGFloat = 22
        /// Label 高度 (pt)
        static let labelHeight: CGFloat = 18
        /// Icon 与 Label 之间的间距 (pt)
        static let iconLabelGap: CGFloat = 6
    }

    enum Timing {
        /// 屏幕变化 debounce (ms)
        static let screenChangeDebounceMs: Int = 500
        /// 定时自动保存布局间隔 (s)
        static let layoutAutoSaveInterval: TimeInterval = 15
        /// 屏幕变化后延迟保存当前布局 (s)
        static let screenChangeAutoSaveDelay: TimeInterval = 2.0
        /// 配置文件变化重载延迟 (s)
        static let configReloadDelay: TimeInterval = 0.2
        /// 快照恢复重试基础延迟 (s)
        static let snapshotRetryBaseDelay: TimeInterval = 1.0
        /// 快照恢复最大重试次数
        static let snapshotMaxRetries: Int = 3
        /// App 启动后轮询窗口间隔 (s)
        static let appLaunchPollInterval: TimeInterval = 0.5
        /// App 启动后轮询窗口最大次数
        static let appLaunchPollMaxAttempts: Int = 10
        /// App 启动规则执行后延迟保存布局 (s)
        static let appLaunchAutoSaveDelay: TimeInterval = 2.0
    }

    enum WindowFilter {
        /// 默认窗口最小宽度 (pt)
        static let minimumWidth: CGFloat = 50
        /// 默认窗口最小高度 (pt)
        static let minimumHeight: CGFloat = 50
    }
}
