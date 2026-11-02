# Brick Overlay · 彩色砖块阅读透卡

浮在文字上方的半透明彩色砖块阅读辅助工具，支持 macOS 和 Windows。

## 下载

- **[macOS 1.2（Apple Silicon）](releases/BrickOverlay-macOS.zip)**：已由项目作者在 Mac 上确认可用。
- **[Windows 1.2.1](releases/BrickOverlay-Windows.zip)**：提供已编译的 `.exe`、源码和备用启动脚本；已通过编译检查，并于 2026-11-02 经用户在 Windows 实机运行确认可用。

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

面向装有 .NET Framework 4.8 的 Windows 10/11。Windows 1.2.1 已经用户实机运行确认可用。

1. 将整个压缩包解压到可写的文件夹。
2. 直接双击 `BrickOverlay.exe`。
3. 备用入口是 `Start Brick Overlay.cmd`。程序不存在或源码、启动脚本更新时，它会通过 Windows PowerShell 重新编译。

1.2.1 修复了 `System.Xml / IXmlLineInfo` 缺失引用导致的启动编译错误，并修正 Windows PowerShell 下的中文文本编码。

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

这是一个持续改进的小工具。macOS 版由作者实测；Windows 1.2.1 已使用微软 C# 编译器及 .NET Framework 4.8 参考程序集完成编译检查，并于 2026-11-02 经用户在 Windows 实机运行确认可用。此确认针对该用户的测试环境，不代表所有 Windows 版本和设备的兼容性覆盖。欢迎通过 Issues 提交系统版本、复现步骤和报错内容。
