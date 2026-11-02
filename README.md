# Brick Overlay · 彩色砖块阅读透卡

浮在文字上方的半透明彩色砖块阅读辅助工具，支持 macOS 和 Windows。

## 下载

- **[macOS 1.2（Apple Silicon）](releases/BrickOverlay-macOS.zip)**：已由项目作者在 Mac 上确认可用。
- **[Windows 版（实验版）](releases/BrickOverlay-Windows.zip)**：提供源码与首次启动编译脚本，尚未在 Windows 上实机验证。

## 功能

- 彩色透卡默认鼠标穿透，可以继续操作下方的文字和窗口。
- 透卡右侧小按钮打开控制菜单。
- **Appearance** 调整配色、宽度、高度和透明度；高度范围为 48–1000。
- 解锁后可拖动，锁定后恢复鼠标穿透。
- 五组内置配色，支持命名保存个人预设和保存默认外观。
- 菜单栏或通知区域保留显示、隐藏和退出入口。

## macOS 使用

解压后打开 `BrickOverlay.app`。现有预编译包面向 Apple Silicon，编译目标为 macOS 26；更早的 macOS 尚未验证。应用未做开发者签名或公证。

日常操作使用透卡右侧的 `⋯` 按钮。菜单栏的 **透** 可以显示、隐藏和退出应用。

## Windows 使用

面向 Windows 10/11，当前为待测试的实验版。

1. 将整个压缩包解压到可写的文件夹。
2. 双击 `Start Brick Overlay.cmd`。
3. 第一次启动时，脚本通过 Windows PowerShell 编译同目录的 `BrickOverlay.cs`，生成并启动 `BrickOverlay.exe`。

请保留配套的源码和启动脚本。遇到问题时，可从任务栏通知区域退出；设置存储在 `%APPDATA%\BrickOverlay\settings.xml`。

## 项目文件

```text
macOS/
  Overlay.swift                  AppKit 源码
  Info.plist                     应用包元数据
Windows/
  BrickOverlay.cs                WinForms 源码
  Start.ps1                      编译与启动脚本
  Start Brick Overlay.cmd        双击启动入口
releases/
  BrickOverlay-macOS.zip
  BrickOverlay-Windows.zip
```

## 状态与反馈

这是一个持续改进的小工具。macOS 版由作者实测；Windows 版目前只完成源码与打包检查，不代表已通过运行测试。欢迎通过 Issues 提交系统版本、复现步骤和报错内容。
