## 中文

1.3.0 正式版新增精确尺寸输入、可调砖块大小、随机宽高、自选色板和文献阅读模式。

- 透卡宽度 100–6000、高度 48–4000；滑块和数字输入均可使用。
- 随机砖块支持高度范围，以及可选的随机宽度范围；布局稳定，可手动重新随机。
- 文献模式使用 2–16 个整宽大色块划分阅读区域。
- 1–12 色自选色板，支持系统选色器和十六进制输入。
- 恢复旧版 Mac“绿色”配色，并将相同色系带到 Windows。
- 默认外观与个人预设保存全部新设置。首次启动优先导入试用版设置，否则导入旧正式版。

先退出旧版再打开正式版。Mac 解压打开 `BrickOverlay.app`（Apple Silicon + macOS 26）；Windows 完整解压后打开 `BrickOverlay.exe`（Windows 10/11 + .NET Framework 4.8）。已有自选配色保留，需在 Appearance → 载入配色 → 绿色 主动载入新绿色。

用户已确认两平台功能试用正常，以及 Mac 恢复后的绿色正常。正式包已通过编译、布局与保存测试、Mac 签名和压缩包检查；最后的 Windows 配色与正式版迁移尚未单独实机复测。Mac 使用临时签名，未经开发者签名或公证。

## English

Version 1.3.0 adds numeric dimensions, adjustable brick sizes, random widths and heights, custom palettes and document reading bands.

- Overlay width 100–6000 and height 48–4000, using sliders or numeric fields.
- Configurable random height ranges and optional random widths, with stable layouts and a Shuffle button.
- Document mode with 2–16 full-width reading bands.
- 1–12 editable colors, a native color picker and hex input.
- Restored original Mac green colors, also available on Windows.
- Defaults and named presets retain all new settings. First launch imports preview settings when available, otherwise the old stable settings.

Quit the old app first. Extract and open `BrickOverlay.app` on Apple Silicon/macOS 26, or `BrickOverlay.exe` on Windows 10/11 with .NET Framework 4.8. Custom palettes are preserved; choose Appearance → Load palette → 绿色 to load the restored green palette.

The user confirmed the feature previews working on both platforms and the restored Mac green palette on Mac. Release compilation, layout/persistence checks, Mac signature verification and archive checks pass. The final Windows palette and stable settings migration have not received a separate Windows desktop retest. The Mac app is ad-hoc signed, not Developer ID signed or notarized.

Settings: %APPDATA%\BrickOverlay\settings-v1.3.xml
Fallback launcher: Start Brick Overlay.cmd. Keep all files together.
