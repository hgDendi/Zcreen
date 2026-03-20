# ScreenAnchor

<p align="center">
  <a href="https://github.com/hgDendi/ScreenAnchor/releases/latest">
    <img src="https://img.shields.io/github/v/release/hgDendi/ScreenAnchor?style=flat-square&color=blue" alt="Latest Release">
  </a>
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License">
  <a href="README_CN.md">中文文档</a>
</p>

macOS menu bar app for multi-screen window management. Zero configuration — just install and forget.

### [Download (DMG)](https://github.com/hgDendi/ScreenAnchor/releases/latest)

> Open the DMG, drag **ScreenAnchor** to **Applications**, launch, and grant Accessibility permission.

## Features

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
- All window positions are automatically saved for every app

**Caffeinate**
- Prevent display & idle sleep from the menu bar
- Duration options: 1h / 2h / 4h
- Shows countdown with stop button when active

**Menu Bar**
- Current screen list with resolution badges
- Click any screen to jump to Display Settings
- Toggle auto-restore, snap bar, launch at login

## Requirements

- macOS 13+ (Ventura)
- Apple Silicon or Intel Mac
- Accessibility permission (prompted on first launch)

## Install

**Option 1: Download**

Download the DMG from [Releases](https://github.com/hgDendi/ScreenAnchor/releases/latest), open it, and drag ScreenAnchor to Applications.

**Option 2: Build from source**

```bash
git clone https://github.com/hgDendi/ScreenAnchor.git && cd ScreenAnchor
make install
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Accessibility permission required | System Settings > Privacy & Security > Accessibility > add ScreenAnchor |
| Permission lost after rebuild | Each build changes the code signature; re-add in Accessibility settings |
| Snap Bar not showing | Verify Accessibility permission is granted and restart the app |

## License

MIT
