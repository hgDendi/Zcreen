# ScreenAnchor

<p align="center">
  <a href="https://github.com/hgDendi/ScreenAnchor/releases/latest">
    <img src="https://img.shields.io/github/v/release/hgDendi/ScreenAnchor?style=flat-square&color=blue" alt="Latest Release">
  </a>
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License">
  <a href="README.md">English</a>
</p>

macOS 菜单栏应用，多屏窗口管理。零配置即用。

### [下载安装包 (DMG)](https://github.com/hgDendi/ScreenAnchor/releases/latest)

> 打开 DMG，将 **ScreenAnchor** 拖到 **Applications**，启动后授予辅助功能权限。

## 功能特性

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
- 所有应用的窗口位置自动保存

**Caffeinate（防息屏）**
- 在菜单栏中防止显示器和系统休眠
- 可选时长：1h / 2h / 4h
- 激活时显示倒计时和停止按钮

**菜单栏**
- 显示当前屏幕列表和分辨率
- 点击屏幕跳转到系统显示器设置
- 开关：自动恢复、Snap Bar、开机自启

## 系统要求

- macOS 13+（Ventura）
- Apple Silicon 或 Intel Mac
- 辅助功能权限（首次启动时提示）

## 安装

**方式一：直接下载**

从 [Releases](https://github.com/hgDendi/ScreenAnchor/releases/latest) 下载 DMG，打开后拖拽到 Applications。

**方式二：源码构建**

```bash
git clone https://github.com/hgDendi/ScreenAnchor.git && cd ScreenAnchor
make install
```

## 常见问题

| 问题 | 解决方案 |
|------|----------|
| 需要辅助功能权限 | 系统设置 > 隐私与安全性 > 辅助功能 > 添加 ScreenAnchor |
| 重新构建后权限失效 | 每次构建产生新签名，需在辅助功能设置中重新添加 |
| Snap Bar 不弹出 | 确认辅助功能权限已授予，重启应用 |

## License

MIT
