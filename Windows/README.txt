Brick Overlay for Windows 1.2.1

面向装有 .NET Framework 4.8 的 Windows 10/11。

解压整个文件夹后，直接双击 BrickOverlay.exe。请先退出旧版，建议解压到新的文件夹，避免混用旧文件。

备用入口是 Start Brick Overlay.cmd：程序不存在，或源码、启动脚本更新时，将通过 Windows PowerShell 重新编译。无需安装 Visual Studio。请保留同目录下的 BrickOverlay.cs 和 Start.ps1。

1.2.1 修复：
- 补齐 System.Xml.dll 编译引用，解决 System.Xml / IXmlLineInfo 缺失引用的启动错误。
- 修复 Windows PowerShell 中的中文提示编码。
- 启动脚本更新后会重新编译，编译成功后才替换旧程序。

彩色透卡默认鼠标穿透，右侧“⋯”按钮可打开菜单。解锁后拖动透卡，锁定后恢复穿透。Appearance 可以调节颜色、宽度、高度（48–1000）和透明度，支持个人预设和默认外观。

任务栏通知区域始终保留“显示/隐藏”和“退出”。设置保存在 %APPDATA%\BrickOverlay\settings.xml；更新包不会删除该设置文件。

验证范围：在 macOS 上使用微软 C# 编译器与 .NET Framework 4.8 参考程序集交叉编译成功。Windows 界面运行尚未实测；若遇到问题，请提供完整报错或截图。
