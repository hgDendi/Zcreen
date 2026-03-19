# ScreenAnchor

[English](#english) | [中文](#中文)

---

## English

macOS menu bar app for multi-screen window management. Automatically saves and restores window layouts when displays are connected or disconnected.

**Zero configuration needed** — just install and forget. Works across different locations and screen combos.

### Features

- **Auto save/restore** — Remembers window positions per screen combo, restores them when you reconnect
- **Hardware-based screen ID** — Uses display vendor/model/serial to identify physical monitors, not names
- **Multi-location support** — Seamlessly handles different setups (e.g., office 3-screen vs. home 2-screen)
- **Pre-change capture** — Saves layout before macOS rearranges windows on disconnect
- **Periodic auto-save** — Keeps snapshots up to date every 2 minutes
- **Optional app rules** — Power users can pin specific apps to specific screens via config file
- **Hot-reload config** — Edit the config file and changes apply immediately
- **Launch at Login** — Optional auto-start on boot

### How it works

Each unique combination of physical displays gets its own layout profile, identified by hardware IDs (`CGDisplayVendorNumber` + `CGDisplayModelNumber` + `CGDisplaySerialNumber`).

```
Office 3-screen:  MacBook + DELL U2723QE + DELL UP2720Q  →  profile A
Office 2-screen:  MacBook + DELL U2723QE                 →  profile B
Home 2-screen:    MacBook + Apple Studio Display          →  profile C
```

When you unplug/plug a display:

1. **Pre-change save** — Captures current window positions before macOS moves them
2. **Detect new combo** — Identifies which physical screens are connected
3. **Restore snapshot** — If this combo was seen before, restores the saved window positions
4. **Apply rules** — If configured, moves specific apps to target screens (optional)

### Requirements

- macOS 13+ (Ventura)
- Apple Silicon or Intel Mac
- Accessibility permission (prompted on first run)

### Install

```bash
git clone https://github.com/hgDendi/ScreenAnchor.git && cd ScreenAnchor

# Build + bundle + install to ~/Applications
make install

# Or just build and run
make bundle
open ScreenAnchor.app
```

### Configuration (optional)

**ScreenAnchor works out of the box with zero config.** The snapshot system automatically saves/restores layouts for each screen combination.

For power users who want to pin specific apps to screens, create a config file:

Config path: `~/.config/screenanchor/config.json`

You can also click **"Edit Config..."** in the menu bar to create an example config.

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

#### Finding bundle IDs

```bash
osascript -e 'id of app "Google Chrome"'
```

### Data storage

- Snapshots: `~/.config/screenanchor/snapshots/`
- Config (optional): `~/.config/screenanchor/config.json`

### Troubleshooting

| Problem | Solution |
|---------|----------|
| Accessibility permission required | System Settings > Privacy & Security > Accessibility > enable ScreenAnchor |
| Windows not moving | Ensure the app is ad-hoc signed (`bundle.sh` does this) |
| First time with a screen combo | Arrange windows manually, they'll be saved automatically |

---

## 中文

macOS 菜单栏应用，用于多屏窗口管理。自动保存和恢复显示器插拔时的窗口布局。

**零配置即用** — 安装后即可使用，无需任何配置。支持多地点、多种屏幕组合自由切换。

### 功能特性

- **自动保存/恢复** — 记忆每种屏幕组合下的窗口位置，重新连接时自动恢复
- **硬件级屏幕识别** — 使用显示器厂商/型号/序列号识别物理屏幕，而非名称
- **多地点支持** — 无缝处理不同场所的屏幕配置（如公司三屏 vs 家里二屏）
- **变化前捕获** — 在 macOS 重排窗口之前保存当前布局
- **定时自动保存** — 每 2 分钟自动保存一次当前快照
- **可选应用规则** — 高级用户可通过配置文件将特定应用固定到指定屏幕
- **配置热更新** — 编辑配置文件后立即生效
- **开机自启** — 可选的登录时自动启动

### 工作原理

每种物理显示器组合会生成唯一的布局配置，通过硬件 ID（`CGDisplayVendorNumber` + `CGDisplayModelNumber` + `CGDisplaySerialNumber`）识别。

```
公司三屏:  MacBook + DELL U2723QE + DELL UP2720Q  →  配置 A
公司二屏:  MacBook + DELL U2723QE                 →  配置 B
家里二屏:  MacBook + Apple Studio Display          →  配置 C
```

当你插拔显示器时：

1. **变化前保存** — 在 macOS 移动窗口之前捕获当前布局
2. **检测新组合** — 识别当前连接了哪些物理屏幕
3. **恢复快照** — 如果这个组合之前见过，恢复保存的窗口位置
4. **应用规则** — 如果配置了规则，将特定应用移到目标屏幕（可选）

### 系统要求

- macOS 13+（Ventura）
- Apple Silicon 或 Intel Mac
- 辅助功能权限（首次运行时提示授权）

### 安装

```bash
git clone https://github.com/hgDendi/ScreenAnchor.git && cd ScreenAnchor

# 构建 + 打包 + 安装到 ~/Applications
make install

# 或者只构建运行
make bundle
open ScreenAnchor.app
```

### 配置（可选）

**ScreenAnchor 开箱即用，无需任何配置。** 快照系统会自动为每种屏幕组合保存和恢复布局。

如果你希望将特定应用固定到指定屏幕，可以创建配置文件：

配置路径：`~/.config/screenanchor/config.json`

也可以点击菜单栏中的 **"Edit Config..."** 来创建示例配置。

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

#### 查找 Bundle ID

```bash
osascript -e 'id of app "Google Chrome"'
```

### 数据存储

- 快照：`~/.config/screenanchor/snapshots/`
- 配置（可选）：`~/.config/screenanchor/config.json`

### 常见问题

| 问题 | 解决方案 |
|------|----------|
| 提示需要辅助功能权限 | 系统设置 > 隐私与安全性 > 辅助功能 > 启用 ScreenAnchor |
| 窗口没有移动 | 确保应用已签名（`bundle.sh` 会自动 ad-hoc 签名） |
| 首次使用某屏幕组合 | 手动排列窗口，之后会自动保存 |

## License

MIT
