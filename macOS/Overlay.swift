import AppKit

final class OverlayView: NSView {
    var palette: [NSColor] = [.systemRed, .systemYellow, .systemGreen, .systemTeal, .systemPurple]
    var tint: CGFloat = 0.22
    var canDrag = false

    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        if canDrag { window?.performDrag(with: event) }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let brickWidth: CGFloat = 150
        let brickHeight: CGFloat = 48
        let gap: CGFloat = 3
        let rows = max(1, Int(bounds.height / (brickHeight + gap)))
        let columns = Int(ceil(bounds.width / (brickWidth + gap))) + 1
        for row in 0..<rows {
            let y = CGFloat(row) * (brickHeight + gap)
            let offset = row.isMultiple(of: 2) ? 0 : -(brickWidth / 2)
            for column in 0..<columns {
                let x = CGFloat(column) * (brickWidth + gap) + offset
                let color = palette[(column + row * 2 + columns) % palette.count]
                color.withAlphaComponent(tint).setFill()
                NSBezierPath(roundedRect: NSRect(x: x, y: y, width: brickWidth, height: brickHeight), xRadius: 2, yRadius: 2).fill()
            }
        }
    }
}

final class DragPanel: NSPanel {
    var movementLocked = true
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: DragPanel!
    private var buttonPanel: NSPanel!
    private var menuButton: NSButton!
    private var overlay: OverlayView!
    private var settings: NSWindow?
    private var palettePopup: NSPopUpButton!
    private var widthSlider: NSSlider!
    private var heightSlider: NSSlider!
    private var opacitySlider: NSSlider!
    private var widthValue: NSTextField!
    private var heightValue: NSTextField!
    private var paletteIndex = 0
    private var opacity = 0.22

    private let palettes: [[NSColor]] = [
        [.systemRed, .systemYellow, .systemGreen, .systemTeal, .systemPurple],
        [.systemRed, .systemOrange, .systemYellow, .systemPink, .systemBrown],
        [.systemBlue, .systemTeal, .systemCyan, .systemIndigo, .systemPurple],
        [.systemGreen, .systemMint, .systemTeal, .systemYellow, .systemBrown],
        [.systemPink, .systemYellow, .systemMint, .systemCyan, .systemPurple]
    ]
    private let paletteNames = ["彩色砖块", "暖色", "冷色", "绿色", "粉彩"]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let defaults = UserDefaults.standard
        paletteIndex = defaults.object(forKey: "defaultPaletteIndex") as? Int ?? defaults.integer(forKey: "paletteIndex")
        opacity = defaults.object(forKey: "defaultOpacity") as? Double ?? defaults.object(forKey: "opacity") as? Double ?? 0.22
        let savedWidth = defaults.object(forKey: "defaultWidth") as? Double ?? defaults.object(forKey: "width") as? Double ?? 850
        let width = min(savedWidth, Double(max(100, (NSScreen.main?.visibleFrame.width ?? 900) - 50)))
        let height = defaults.object(forKey: "defaultHeight") as? Double ?? defaults.object(forKey: "height") as? Double ?? 240
        overlay = OverlayView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        overlay.palette = palettes[max(0, min(paletteIndex, palettes.count - 1))]
        overlay.tint = opacity
        panel = DragPanel(contentRect: overlay.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = overlay
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()

        menuButton = NSButton(title: "⋯", target: self, action: #selector(showButtonMenu))
        menuButton.bezelStyle = .rounded
        menuButton.toolTip = "透卡菜单"
        buttonPanel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 34, height: 34), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        buttonPanel.contentView = menuButton
        buttonPanel.isOpaque = false
        buttonPanel.backgroundColor = .clear
        buttonPanel.hasShadow = false
        buttonPanel.level = .floating
        buttonPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        buttonPanel.orderFrontRegardless()
        positionMenuButton()
        NotificationCenter.default.addObserver(self, selector: #selector(overlayMoved), name: NSWindow.didMoveNotification, object: panel)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "透"
        let fallbackMenu = NSMenu()
        fallbackMenu.addItem(withTitle: "隐藏透卡", action: #selector(toggleOverlay), keyEquivalent: "").target = self
        fallbackMenu.addItem(withTitle: "退出透卡", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = fallbackMenu
    }

    @objc private func showButtonMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: panel.isVisible ? "隐藏透卡" : "显示透卡", action: #selector(toggleOverlay), keyEquivalent: "")
        menu.addItem(withTitle: panel.movementLocked ? "解锁移动" : "锁定位置", action: #selector(toggleMovementLock), keyEquivalent: "")
        menu.addItem(withTitle: "Appearance…", action: #selector(showSettings), keyEquivalent: "")
        menu.addItem(withTitle: "保存为默认外观", action: #selector(saveDefault), keyEquivalent: "")
        let presets = NSMenuItem(title: "预设", action: nil, keyEquivalent: "")
        let presetMenu = NSMenu()
        for (index, name) in paletteNames.enumerated() {
            let item = NSMenuItem(title: name, action: #selector(applyPalettePreset(_:)), keyEquivalent: "")
            item.tag = index
            item.target = self
            presetMenu.addItem(item)
        }
        presetMenu.addItem(.separator())
        let savePreset = NSMenuItem(title: "保存当前为用户预设…", action: #selector(savePreset), keyEquivalent: "")
        savePreset.target = self
        presetMenu.addItem(savePreset)
        for preset in savedPresets() {
            let item = NSMenuItem(title: preset, action: #selector(applySavedPreset(_:)), keyEquivalent: "")
            item.representedObject = preset
            item.target = self
            presetMenu.addItem(item)
        }
        presets.submenu = presetMenu
        menu.addItem(presets)
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: buttonPanel.contentView!.bounds.height), in: buttonPanel.contentView)
    }

    @objc private func toggleOverlay() {
        if panel.isVisible {
            panel.orderOut(nil)
            buttonPanel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
            buttonPanel.orderFrontRegardless()
            positionMenuButton()
        }
        statusItem.menu?.item(at: 0)?.title = panel.isVisible ? "隐藏透卡" : "显示透卡"
    }

    @objc private func toggleMovementLock() {
        panel.movementLocked.toggle()
        overlay.canDrag = !panel.movementLocked
        panel.ignoresMouseEvents = panel.movementLocked
    }

    @objc private func showSettings() {
        if settings == nil { settings = makeSettings() }
        settings?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeSettings() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 300), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Appearance"
        window.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 300))
        window.contentView = content

        let label = NSTextField(labelWithString: "颜色组合")
        label.frame = NSRect(x: 20, y: 258, width: 100, height: 20)
        content.addSubview(label)
        palettePopup = NSPopUpButton(frame: NSRect(x: 20, y: 226, width: 280, height: 28), pullsDown: false)
        palettePopup.addItems(withTitles: paletteNames)
        palettePopup.selectItem(at: paletteIndex)
        palettePopup.target = self
        palettePopup.action = #selector(changePalette(_:))
        content.addSubview(palettePopup)

        let widthLabel = NSTextField(labelWithString: "宽度")
        widthLabel.frame = NSRect(x: 20, y: 184, width: 60, height: 20)
        content.addSubview(widthLabel)
        let maxWidth = min(1600, max(100, (panel.screen?.visibleFrame.width ?? 900) - 50))
        widthSlider = NSSlider(value: Double(overlay.bounds.width), minValue: min(400, maxWidth), maxValue: maxWidth, target: self, action: #selector(changeWidth(_:)))
        widthSlider.frame = NSRect(x: 82, y: 179, width: 175, height: 28)
        widthSlider.isContinuous = true
        content.addSubview(widthSlider)
        widthValue = NSTextField(labelWithString: "\(Int(overlay.bounds.width)) px")
        widthValue.frame = NSRect(x: 258, y: 184, width: 50, height: 20)
        content.addSubview(widthValue)

        let heightLabel = NSTextField(labelWithString: "高度")
        heightLabel.frame = NSRect(x: 20, y: 139, width: 60, height: 20)
        content.addSubview(heightLabel)
        heightSlider = NSSlider(value: Double(overlay.bounds.height), minValue: 48, maxValue: 1000, target: self, action: #selector(changeHeight(_:)))
        heightSlider.frame = NSRect(x: 82, y: 134, width: 175, height: 28)
        heightSlider.isContinuous = true
        content.addSubview(heightSlider)
        heightValue = NSTextField(labelWithString: "\(Int(overlay.bounds.height)) px")
        heightValue.frame = NSRect(x: 258, y: 139, width: 50, height: 20)
        content.addSubview(heightValue)

        let alphaLabel = NSTextField(labelWithString: "透明度")
        alphaLabel.frame = NSRect(x: 20, y: 94, width: 60, height: 20)
        content.addSubview(alphaLabel)
        opacitySlider = NSSlider(value: opacity * 100, minValue: 8, maxValue: 45, target: self, action: #selector(changeOpacity(_:)))
        opacitySlider.frame = NSRect(x: 82, y: 89, width: 218, height: 28)
        opacitySlider.isContinuous = true
        content.addSubview(opacitySlider)

        let hint = NSTextField(labelWithString: "透卡可拖到任意文字行上")
        hint.frame = NSRect(x: 20, y: 42, width: 280, height: 20)
        hint.textColor = .secondaryLabelColor
        content.addSubview(hint)
        window.center()
        return window
    }

    @objc private func changePalette(_ sender: NSPopUpButton) {
        paletteIndex = max(0, sender.indexOfSelectedItem)
        overlay.palette = palettes[paletteIndex]
        overlay.needsDisplay = true
        persistCurrentAppearance()
    }

    @objc private func changeOpacity(_ sender: NSSlider) {
        opacity = sender.doubleValue / 100
        overlay.tint = opacity
        overlay.needsDisplay = true
        persistCurrentAppearance()
    }

    @objc private func changeWidth(_ sender: NSSlider) {
        let width = CGFloat(sender.doubleValue.rounded())
        widthValue.stringValue = "\(Int(width)) px"
        resizeOverlay(width: width, height: panel.frame.height)
        persistCurrentAppearance()
    }

    @objc private func changeHeight(_ sender: NSSlider) {
        let height = CGFloat(sender.doubleValue.rounded())
        heightValue.stringValue = "\(Int(height)) px"
        resizeOverlay(width: panel.frame.width, height: height)
        persistCurrentAppearance()
    }

    private func resizeOverlay(width: CGFloat, height: CGFloat) {
        let top = panel.frame.maxY
        panel.setContentSize(NSSize(width: width, height: height))
        panel.setFrameTopLeftPoint(NSPoint(x: panel.frame.minX, y: top))
        overlay.needsDisplay = true
        positionMenuButton()
    }

    private func positionMenuButton() {
        guard panel != nil, buttonPanel != nil else { return }
        let screen = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? panel.frame
        let rightmostPanelX = screen.maxX - panel.frame.width - buttonPanel.frame.width - 8
        let panelX = min(max(panel.frame.minX, screen.minX), rightmostPanelX)
        if abs(panelX - panel.frame.minX) > 0.5 {
            panel.setFrameOrigin(NSPoint(x: panelX, y: panel.frame.minY))
        }
        let x = panel.frame.maxX + 8
        let y = panel.frame.midY - buttonPanel.frame.height / 2
        buttonPanel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func overlayMoved() { positionMenuButton() }

    private func persistCurrentAppearance() {
        let defaults = UserDefaults.standard
        defaults.set(paletteIndex, forKey: "paletteIndex")
        defaults.set(Double(opacity), forKey: "opacity")
        defaults.set(Double(panel.frame.width), forKey: "width")
        defaults.set(Double(panel.frame.height), forKey: "height")
    }

    @objc private func saveDefault() {
        persistCurrentAppearance()
        UserDefaults.standard.set(paletteIndex, forKey: "defaultPaletteIndex")
        UserDefaults.standard.set(Double(opacity), forKey: "defaultOpacity")
        UserDefaults.standard.set(Double(panel.frame.width), forKey: "defaultWidth")
        UserDefaults.standard.set(Double(panel.frame.height), forKey: "defaultHeight")
    }

    @objc private func applyPalettePreset(_ sender: NSMenuItem) {
        paletteIndex = sender.tag
        overlay.palette = palettes[paletteIndex]
        overlay.needsDisplay = true
        syncSettings()
        persistCurrentAppearance()
    }

    private func savedPresets() -> [String] {
        UserDefaults.standard.dictionary(forKey: "savedPresets")?.keys.sorted() ?? []
    }

    @objc private func savePreset() {
        let alert = NSAlert()
        alert.messageText = "保存用户预设"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        input.placeholderString = "预设名称"
        alert.accessoryView = input
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var presets = UserDefaults.standard.dictionary(forKey: "savedPresets") ?? [:]
        presets[name] = [paletteIndex, Double(opacity), Double(panel.frame.width), Double(panel.frame.height)]
        UserDefaults.standard.set(presets, forKey: "savedPresets")
    }

    @objc private func applySavedPreset(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let values = UserDefaults.standard.dictionary(forKey: "savedPresets")?[name] as? [Any], values.count == 4 else { return }
        paletteIndex = (values[0] as? Int) ?? 0
        opacity = (values[1] as? Double) ?? 0.22
        overlay.palette = palettes[max(0, min(paletteIndex, palettes.count - 1))]
        overlay.tint = opacity
        resizeOverlay(width: (values[2] as? Double) ?? 850, height: (values[3] as? Double) ?? 240)
        overlay.needsDisplay = true
        syncSettings()
        persistCurrentAppearance()
    }

    private func syncSettings() {
        guard settings != nil else { return }
        palettePopup.selectItem(at: paletteIndex)
        widthSlider.doubleValue = Double(panel.frame.width)
        heightSlider.doubleValue = Double(panel.frame.height)
        opacitySlider.doubleValue = opacity * 100
        widthValue.stringValue = "\(Int(panel.frame.width)) px"
        heightValue.stringValue = "\(Int(panel.frame.height)) px"
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

@main
struct BrickOverlayApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
