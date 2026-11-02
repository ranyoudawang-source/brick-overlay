# Brick Overlay · 彩色砖块阅读透卡

浮在文字上方的半透明彩色砖块阅读辅助工具，支持 macOS 和 Windows。

A translucent colored-brick reading overlay for macOS and Windows.

[中文说明](#中文说明) · [English](#english)

## 实机画面 · In use

![半透明彩色砖块叠加在网页文字上方 / Translucent colored bricks over webpage text](docs/images/brick-overlay-live.png)

用户提供的实机截图。截图中的页面内容为拍摄时的版本，下载及运行状态以本页说明为准。

A user-provided screenshot of the app in use. The page shown reflects an earlier version; see the information below for current downloads and testing status.

## 中文说明

### 下载

- **[macOS 1.2（Apple Silicon）](releases/BrickOverlay-macOS.zip)**：已由项目作者在 Mac 上确认可用。
- **[Windows 1.2.1](releases/BrickOverlay-Windows.zip)**：包含已编译的 `.exe`、源码和备用启动脚本；已通过编译检查，并于 2026-11-02 经用户在 Windows 实机运行确认可用。

### 功能

- 彩色透卡默认鼠标穿透，可以继续操作下方的文字和窗口。
- 透卡右侧小按钮打开控制菜单。
- **Appearance** 调整配色、宽度、高度和透明度；高度范围为 48–1000。
- 解锁后可拖动，锁定后恢复鼠标穿透。
- 五组内置配色，支持命名保存个人预设和保存默认外观。
- 菜单栏或通知区域保留显示、隐藏和退出入口。

### macOS 使用

解压后打开 `BrickOverlay.app`。现有预编译包面向 Apple Silicon，编译目标为 macOS 26；更早的 macOS 尚未验证。应用未做开发者签名或公证。

日常操作使用透卡右侧的 `⋯` 按钮。菜单栏的 **透** 可以显示、隐藏和退出应用。

### Windows 使用

面向装有 .NET Framework 4.8 的 Windows 10/11。Windows 1.2.1 已经用户实机运行确认可用。

1. 将整个压缩包解压到可写的文件夹。
2. 直接双击 `BrickOverlay.exe`。
3. 备用入口是 `Start Brick Overlay.cmd`。程序不存在或源码、启动脚本更新时，它会通过 Windows PowerShell 重新编译。

1.2.1 修复了 `System.Xml / IXmlLineInfo` 缺失引用导致的启动编译错误，并修正 Windows PowerShell 下的中文文本编码。

请保留配套的源码和启动脚本。遇到问题时，可从任务栏通知区域退出；设置存储在 `%APPDATA%\BrickOverlay\settings.xml`。

### 状态与反馈

macOS 版由作者实测；Windows 1.2.1 已使用微软 C# 编译器及 .NET Framework 4.8 参考程序集完成编译检查，并于 2026-11-02 经用户在 Windows 实机运行确认可用。此确认针对该用户的测试环境，不代表所有 Windows 版本和设备的兼容性覆盖。

欢迎通过 [Issues](https://github.com/ranyoudawang-source/brick-overlay/issues) 提交系统版本、复现步骤和报错内容。当前应用菜单主要使用中文，**Appearance** 使用英文。

## English

### Downloads

- **[macOS 1.2 (Apple Silicon)](releases/BrickOverlay-macOS.zip)**: confirmed working on the project author's Mac.
- **[Windows 1.2.1](releases/BrickOverlay-Windows.zip)**: includes a compiled `.exe`, source code, and a fallback launcher. Compilation has been checked, and a user confirmed it working on a Windows machine on November 2, 2026.

### Features

- The colored overlay is click-through by default, so you can interact with the text and windows underneath.
- A small button to the right of the overlay opens the control menu.
- **Appearance** adjusts the palette, width, height, and opacity. Height can be set from 48 to 1000.
- Unlock the overlay to drag it; locking it restores click-through behavior.
- Five built-in palettes, named personal presets, and a saved default appearance.
- The menu bar or notification-area icon always provides show, hide, and quit controls.

### Using the macOS app

Extract the archive and open `BrickOverlay.app`. The prebuilt app targets Apple Silicon and macOS 26; earlier macOS versions have not been tested. The app is not developer-signed or notarized.

Use the `⋯` button to the right of the overlay for everyday controls. The **透** menu-bar item lets you show or hide the overlay and quit the app.

### Using the Windows app

Intended for Windows 10/11 with .NET Framework 4.8 installed. A user has confirmed Windows 1.2.1 working on their machine.

1. Extract the entire archive into a writable folder.
2. Double-click `BrickOverlay.exe`.
3. Alternatively, use `Start Brick Overlay.cmd`. It recompiles the app through Windows PowerShell if the executable is missing or the source or launcher has been updated.

Version 1.2.1 fixes a missing `System.Xml / IXmlLineInfo` assembly reference that prevented startup compilation, and fixes Chinese text encoding in Windows PowerShell.

Keep the source and launcher files together. You can quit through the notification-area icon. Settings are stored in `%APPDATA%\BrickOverlay\settings.xml`.

### Testing and feedback

The macOS app has been tested by the author. Windows 1.2.1 passed compilation checks using Microsoft's C# compiler and .NET Framework 4.8 reference assemblies, and a user confirmed it working on a Windows machine on November 2, 2026. This confirmation covers that user's test environment, rather than every Windows version and device.

Please include your operating system version, steps to reproduce, and any error messages when submitting an [issue](https://github.com/ranyoudawang-source/brick-overlay/issues). App menus currently use mostly Chinese labels, with **Appearance** in English.

## 项目文件 · Project files

```text
macOS/
  Overlay.swift                  AppKit 源码 / AppKit source
  Info.plist                     应用包元数据 / App bundle metadata
Windows/
  BrickOverlay.cs                WinForms 源码 / WinForms source
  Start.ps1                      编译与启动脚本 / Build and launch script
  Start Brick Overlay.cmd        双击启动入口 / Double-click launcher
  README.txt                     Windows 使用说明 / Windows instructions
releases/
  BrickOverlay-macOS.zip
  BrickOverlay-Windows.zip
docs/images/
  brick-overlay-live.png         实机截图 / Screenshot
```
