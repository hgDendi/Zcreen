# ScreenAnchor

[English](#english) | [中文](#中文)

<p align="center">
  <a href="https://github.com/hgDendi/ScreenAnchor/releases/latest">
    <img src="https://img.shields.io/github/v/release/hgDendi/ScreenAnchor?style=flat-square&color=blue" alt="Latest Release">
  </a>
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License">
</p>

---

## English

macOS menu bar app for multi-screen window management. Zero configuration — just install and forget.

### [Download Latest Release](https://github.com/hgDendi/ScreenAnchor/releases/latest)

> Download `ScreenAnchor.app.zip`, unzip, move to `~/Applications`, launch, and grant Accessibility permission.

### Features

**Auto Layout Save & Restore**
- Remembers every window's position for each unique screen combination
- Uses hardware IDs (vendor/model/serial) to identify physical monitors
- Automatically restores layout when screens are reconnected
- Works seamlessly across different locations (e.g., office 3-screen vs home 2-screen)

**Snap Bar**
- Drag any window to trigger a floating layout bar at the top of the screen
- Interactive zone groups — drag within a cell to pick the target area:

  | Group | Zones |
  |-------|-------|
  | Full | Entire screen |
  | Padded | 80% centered (10% margin each side) |
  | ½ | Left / Right (drag to choose) |
  | ⅓ | Left / Center / Right |
  | ¼ | Top-left / Top-right / Bottom-left / Bottom-right |

- **Portrait-aware**: portrait screens get vertical splits (½ ↕, ⅓ ↕) with matching aspect ratio icons
- Snapped layouts are automatically saved to the snapshot system

**Caffeinate**
- Prevent display & idle sleep from the menu bar
- Duration options: 1h / 2h / 4h
- Shows countdown with stop button when active

**Menu Bar**
- Current screen list with resolution badges
- Click any screen to jump to Display Settings
- Toggle auto-restore, snap bar, launch at login
- Optional JSON config for power-user app-pinning rules

### Requirements

- macOS 13+ (Ventura)
- Apple Silicon or Intel Mac
- Accessibility permission (prompted on first launch)

### Install

**Option 1: Download**

Download from [Releases](https://github.com/hgDendi/ScreenAnchor/releases/latest), unzip, move to `~/Applications`, and launch.

**Option 2: Build from source**

```bash
git clone https://github.com/hgDendi/ScreenAnchor.git && cd ScreenAnchor
make install    # builds, bundles, and installs to ~/Applications
```

### Configuration (optional)

ScreenAnchor works with zero config. For power users who want to pin specific apps to screens:

```bash
# Click "Config" in the menu bar, or create manually:
~/.config/screenanchor/config.json
```

```json
{
  "version": 1,
  "screens": [
    { "alias": "dell-portrait", "nameContains": "U2723QE" },
    { "alias": "macbook", "nameContains": "Built-in" }
  ],
  "rules": [
    {
      "app": { "bundleId": "com.mitchellh.ghostty" },
      "targetScreen": "dell-portrait"
    }
  ]
}
```

Find bundle IDs: `osascript -e 'id of app "AppName"'`

### Data

- Snapshots: `~/.config/screenanchor/snapshots/`
- Config (optional): `~/.config/screenanchor/config.json`

### Troubleshooting

| Problem | Solution |
|---------|----------|
| Accessibility permission required | System Settings > Privacy & Security > Accessibility > add ScreenAnchor |
| Permission lost after rebuild | Each build produces a new code signature; re-add in Accessibility settings |
| Snap Bar not showing | Verify Accessibility permission is granted and restart the app |

---

## 中文

macOS 菜单栏应用，多屏窗口管理。零配置即用。

### [下载最新版本](https://github.com/hgDendi/ScreenAnchor/releases/latest)

> 下载 `ScreenAnchor.app.zip`，解压，移动到 `~/Applications`，启动后授予辅助功能权限。

### 功能特性

**自动布局保存与恢复**
- 记忆每种屏幕组合下所有窗口的位置
- 通过硬件 ID（厂商/型号/序列号）识别物理显示器
- 重新连接显示器时自动恢复布局
- 不同地点无缝切换（如公司三屏 vs 家里二屏）

**Snap Bar（拖拽布局）**
- 拖拽任意窗口时，屏幕顶部自动弹出布局选择条
- 交互式区域 — 在同一个格子内拖到不同位置选择不同布局：

  | 分组 | 区域 |
  |------|------|
  | Full | 全屏 |
  | Padded | 80% 居中（四周留 10% 空隙）|
  | ½ | 左 / 右（拖到对应侧选择）|
  | ⅓ | 左 / 中 / 右 |
  | ¼ | 左上 / 右上 / 左下 / 右下 |

- **竖屏适配**：竖屏自动切换为纵向分割（½ ↕、⅓ ↕），预览图标匹配屏幕比例
- 通过 Snap Bar 调整的布局自动保存

**Caffeinate（防息屏）**
- 在菜单栏中防止显示器和系统休眠
- 可选时长：1h / 2h / 4h
- 激活时显示倒计时和停止按钮

**菜单栏**
- 显示当前屏幕列表和分辨率
- 点击屏幕跳转到系统显示器设置
- 开关：自动恢复、Snap Bar、开机自启
- 可选 JSON 配置文件（高级用户固定应用到指定屏幕）

### 系统要求

- macOS 13+（Ventura）
- Apple Silicon 或 Intel Mac
- 辅助功能权限（首次启动时提示）

### 安装

**方式一：直接下载**

从 [Releases](https://github.com/hgDendi/ScreenAnchor/releases/latest) 下载，解压，移动到 `~/Applications`，启动即可。

**方式二：源码构建**

```bash
git clone https://github.com/hgDendi/ScreenAnchor.git && cd ScreenAnchor
make install    # 构建 + 打包 + 安装到 ~/Applications
```

### 配置（可选）

零配置即可使用。如需将特定应用固定到指定屏幕：

```bash
# 点击菜单栏 "Config"，或手动创建：
~/.config/screenanchor/config.json
```

```json
{
  "version": 1,
  "screens": [
    { "alias": "dell-portrait", "nameContains": "U2723QE" },
    { "alias": "macbook", "nameContains": "Built-in" }
  ],
  "rules": [
    {
      "app": { "bundleId": "com.mitchellh.ghostty" },
      "targetScreen": "dell-portrait"
    }
  ]
}
```

查找 Bundle ID：`osascript -e 'id of app "应用名"'`

### 数据存储

- 快照：`~/.config/screenanchor/snapshots/`
- 配置（可选）：`~/.config/screenanchor/config.json`

### 常见问题

| 问题 | 解决方案 |
|------|----------|
| 需要辅助功能权限 | 系统设置 > 隐私与安全性 > 辅助功能 > 添加 ScreenAnchor |
| 重新构建后权限失效 | 每次构建产生新签名，需在辅助功能设置中重新添加 |
| Snap Bar 不弹出 | 确认辅助功能权限已授予，重启应用 |

## License

MIT
