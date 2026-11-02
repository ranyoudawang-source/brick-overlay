import AppKit

final class FlippedView: NSView { override var isFlipped: Bool { true } }
final class OverlayView: NSView {
    var configuration = Appearance()
    var canDrag = false
    var tiles: [Tile] = []
    override var isFlipped: Bool { true }
    override func mouseDown(with event: NSEvent) { if canDrag { window?.performDrag(with: event) } }
    func update(_ a: Appearance) { configuration = a; tiles = Layout.tiles(a); needsDisplay = true }
    override func draw(_ rect: NSRect) {
        NSColor.clear.setFill(); bounds.fill(using: .copy)
        let colors = configuration.colors.map { NSColor(hex: $0).withAlphaComponent(Double(configuration.opacity)/100) }
        for tile in tiles {
            colors[tile.color].setFill()
            NSBezierPath(rect: NSRect(x: tile.x, y: tile.y, width: tile.width, height: tile.height)).fill()
        }
    }
}
extension NSColor {
    convenience init(hex: String) {
        let v = UInt32(hex, radix:16) ?? 0
        self.init(srgbRed: Double((v>>16)&255)/255, green: Double((v>>8)&255)/255, blue: Double(v&255)/255, alpha:1)
    }
    var hex: String {
        let c = usingColorSpace(.sRGB) ?? self
        return String(format:"%02X%02X%02X",Int((c.redComponent*255).rounded()),Int((c.greenComponent*255).rounded()),Int((c.blueComponent*255).rounded()))
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    private var state = SavedState()
    // The application bundle identifier selects the stable preferences domain.
    // A suite named after the current application can return nil on macOS.
    private let preferences = UserDefaults.standard
    private var panel: NSPanel!
    private var control: NSPanel!
    private var overlay = OverlayView()
    private var status: NSStatusItem!
    private var settings: NSWindow?
    private var moving = false
    private var placing = false
    private var modePopup: NSPopUpButton!
    private var fields: [String:NSTextField] = [:]
    private var sliders: [String:NSSlider] = [:]
    private var wells: [NSButton] = []
    private var chosenColor = 0
    private var colorWell: NSColorWell!
    private var hexField: NSTextField!
    private var note: NSTextField!
    private var modeHint: NSTextField!
    private var randomWidthToggle: NSButton!
    private var regenerate: NSButton!
    private var removeColor: NSButton!
    private var addColor: NSButton!
    private let names = ["砖块 / Bricks", "随机砖块 / Random bricks", "文献阅读 / Document"]
    private let paletteNames = ["彩色", "暖色", "冷色", "绿色", "粉彩"]
    private var palettes: [[String]] { [
        ["F26F6C","F5C84C","68B995","58B6D3","967BC5"],
        ["CD5C5C","FF7F50","FFD700","FFB6C1","CD853F"],
        ["6495ED","008080","87CEEB","7B68EE","DDA0DD"],
        // Preserve the original Mac green preset, resolved for the current appearance.
        [NSColor.systemGreen, .systemMint, .systemTeal, .systemYellow, .systemBrown].map { $0.hex },
        ["FFB6C1","EEE8AA","98FB98","E0FFFF","D8BFD8"]] }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let data = preferences.data(forKey: "state"), let saved = try? JSONDecoder().decode(SavedState.self, from:data) { state = saved }
        else if let preview = preferences.persistentDomain(forName:"local.brickoverlay.preview"),
                let data = preview["state"] as? Data,
                let saved = try? JSONDecoder().decode(SavedState.self, from:data) { state = saved }
        else { importLegacy() }
        state.current = state.startup ?? state.current
        state.current.normalize()
        panel = NSPanel(contentRect: NSRect(x:60,y:80,width:state.current.width,height:state.current.height),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.contentView = overlay; panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = false; panel.level = .floating; panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]
        let button = NSButton(title:"⋯",target:self,action:#selector(menu))
        button.bezelStyle = .rounded; button.toolTip = "透卡菜单 / Overlay menu"
        control = NSPanel(contentRect:NSRect(x:0,y:0,width:36,height:36),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        control.contentView = button; control.isOpaque = false; control.backgroundColor = .clear
        control.level = .floating; control.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]
        status = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        status.button?.title = "透"
        let fallback = NSMenu()
        addMenu(fallback,"显示/隐藏 / Show or hide",#selector(toggleVisible))
        addMenu(fallback,"Appearance…",#selector(showSettings))
        addMenu(fallback,"退出 / Quit",#selector(quit))
        status.menu = fallback
        panel.orderFrontRegardless(); control.orderFrontRegardless()
        NotificationCenter.default.addObserver(self,selector:#selector(moved),name:NSWindow.didMoveNotification,object:panel)
        apply(); showSettings()
    }
    private func importLegacy() {
        guard let old = UserDefaults.standard.persistentDomain(forName:"local.codex.brickoverlay") else { return }
        var a = Appearance()
        a.width = (old["defaultWidth"] as? NSNumber ?? old["width"] as? NSNumber)?.intValue ?? a.width
        a.height = (old["defaultHeight"] as? NSNumber ?? old["height"] as? NSNumber)?.intValue ?? a.height
        a.opacity = Int(((old["defaultOpacity"] as? NSNumber ?? old["opacity"] as? NSNumber)?.doubleValue ?? 0.22)*100)
        let p = (old["defaultPaletteIndex"] as? NSNumber ?? old["paletteIndex"] as? NSNumber)?.intValue ?? 0
        a.colors = palettes[Appearance.clamp(p,0,4)]; a.normalize(); state.current = a
        if let oldPresets = old["savedPresets"] as? [String:[NSNumber]] {
            for (name,values) in oldPresets where values.count == 4 {
                var p = Appearance(); p.colors = palettes[Appearance.clamp(values[0].intValue,0,4)]
                p.opacity = Int(values[1].doubleValue*100); p.width = values[2].intValue; p.height = values[3].intValue
                p.normalize(); state.presets[name] = p
            }
        }
    }
    private func save() { if let data = try? JSONEncoder().encode(state) { preferences.set(data,forKey:"state") } }
    private func apply() {
        state.current.normalize()
        let top = panel.frame.maxY
        panel.setContentSize(NSSize(width:state.current.width,height:state.current.height))
        panel.setFrameTopLeftPoint(NSPoint(x:panel.frame.minX,y:top))
        overlay.update(state.current); positionControl(); sync(); save()
    }
    private func positionControl() {
        guard !placing, panel != nil, control != nil else { return }; placing = true
        defer { placing = false }
        let screen = (panel.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x:0,y:0,width:1440,height:900)
        let rightmost = screen.maxX - CGFloat(state.current.width) - 44
        let x = min(max(panel.frame.minX,screen.minX),rightmost)
        let top = min(screen.maxY,max(panel.frame.maxY,screen.minY+50))
        panel.setFrameTopLeftPoint(NSPoint(x:x,y:top))
        let y = min(screen.maxY-36,max(screen.minY,panel.frame.midY-18))
        control.setFrameOrigin(NSPoint(x:panel.frame.maxX+8,y:y))
    }
    @objc private func moved() { positionControl() }
    private func addMenu(_ menu:NSMenu,_ title:String,_ action:Selector) { menu.addItem(withTitle:title,action:action,keyEquivalent:"").target = self }
    @objc private func menu() {
        let m = NSMenu()
        addMenu(m,panel.isVisible ? "隐藏 / Hide" : "显示 / Show",#selector(toggleVisible))
        addMenu(m,moving ? "锁定位置 / Lock" : "解锁移动 / Move",#selector(toggleMove))
        addMenu(m,"Appearance…",#selector(showSettings))
        addMenu(m,"保存为默认 / Save startup appearance",#selector(saveDefault))
        addMenu(m,"恢复默认 / Restore startup appearance",#selector(restoreDefault))
        addMenu(m,"保存个人预设… / Save preset…",#selector(savePreset))
        let p = NSMenuItem(title:"个人预设 / My presets",action:nil,keyEquivalent:""); let sub = NSMenu()
        for name in state.presets.keys.sorted() { let i = sub.addItem(withTitle:name,action:#selector(loadPreset(_:)),keyEquivalent:""); i.target = self; i.representedObject = name }
        p.submenu = sub; p.isEnabled = !state.presets.isEmpty; m.addItem(p)
        m.addItem(.separator()); addMenu(m,"退出 / Quit",#selector(quit))
        m.popUp(positioning:nil,at:NSPoint(x:0,y:36),in:control.contentView)
    }
    @objc private func toggleVisible() { let visible = !panel.isVisible; if visible { panel.orderFrontRegardless();control.orderFrontRegardless() } else { panel.orderOut(nil);control.orderOut(nil) } }
    @objc private func toggleMove() { moving.toggle(); overlay.canDrag = moving; panel.ignoresMouseEvents = !moving }
    @objc private func quit() { save(); NSApp.terminate(nil) }
    @objc private func saveDefault() { settings?.makeFirstResponder(nil); state.startup = state.current; save(); note?.stringValue = "已保存启动外观 / Startup appearance saved" }
    @objc private func restoreDefault() { state.current = state.startup ?? Appearance(); apply() }
    @objc private func savePreset() {
        settings?.makeFirstResponder(nil)
        let alert = NSAlert(); alert.messageText = "保存预设 / Save preset"
        alert.addButton(withTitle:"保存 / Save"); alert.addButton(withTitle:"取消 / Cancel")
        let field = NSTextField(frame:NSRect(x:0,y:0,width:260,height:24)); alert.accessoryView = field; alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty else { return }; state.presets[name] = state.current; save()
    }
    @objc private func loadPreset(_ sender:NSMenuItem) { if let name = sender.representedObject as? String,let p = state.presets[name] { state.current = p;apply() } }
    @objc private func showSettings() {
        if settings == nil { settings = buildSettings() }
        sync(); settings?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    private func label(_ text:String,_ x:Int,_ y:Int,_ w:Int,_ view:NSView) -> NSTextField {
        let f = NSTextField(labelWithString:text); f.frame = NSRect(x:x,y:y,width:w,height:22); view.addSubview(f); return f
    }
    private func row(_ key:String,_ title:String,_ y:Int,_ min:Int,_ max:Int,_ view:NSView,_ unit:String = "px") {
        _ = label(title,20,y+4,160,view)
        let slider = NSSlider(value:Double(min),minValue:Double(min),maxValue:Double(max),target:self,action:#selector(slid(_:)))
        slider.identifier = NSUserInterfaceItemIdentifier(key); slider.frame = NSRect(x:185,y:y,width:220,height:24);slider.isContinuous = true
        view.addSubview(slider);sliders[key] = slider
        let f = NSTextField(frame:NSRect(x:415,y:y,width:78,height:25));f.identifier = NSUserInterfaceItemIdentifier(key);f.delegate = self
        f.alignment = .right; f.toolTip = "\(min)–\(max) \(unit)";view.addSubview(f);fields[key] = f
        _ = label(unit,500,y+4,50,view)
    }
    private func buildSettings() -> NSWindow {
        let win = NSWindow(contentRect:NSRect(x:0,y:0,width:570,height:610),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        win.title = "Appearance · Brick Overlay 1.3";win.isReleasedWhenClosed = false;win.level = .floating
        let scroll = NSScrollView(frame:NSRect(x:0,y:0,width:570,height:610));scroll.hasVerticalScroller = true;scroll.autoresizingMask = [.width,.height]
        let view = FlippedView(frame:NSRect(x:0,y:0,width:550,height:758));scroll.documentView = view;win.contentView = scroll
        _ = label("阅读模式 / Mode",20,18,160,view)
        modePopup = NSPopUpButton(frame:NSRect(x:185,y:12,width:345,height:28));modePopup.addItems(withTitles:names);modePopup.target = self;modePopup.action = #selector(modeChanged);view.addSubview(modePopup)
        modeHint = label("",20,47,515,view);modeHint.font = .systemFont(ofSize:11);modeHint.textColor = .secondaryLabelColor
        row("width","透卡宽 / Width",78,100,6000,view)
        row("height","透卡高 / Height",114,48,4000,view)
        row("opacity","着色强度 / Tint",150,5,65,view,"%")
        row("brickWidth","砖块宽 / Brick width",198,24,1200,view)
        row("brickHeight","砖块高 / Brick height",234,8,1000,view)
        row("minimumHeight","随机最小高 / Min",270,8,1000,view)
        row("maximumHeight","随机最大高 / Max",306,8,1000,view)
        randomWidthToggle = NSButton(checkboxWithTitle:"同时随机宽度 / Randomize widths",target:self,action:#selector(randomWidthChanged))
        randomWidthToggle.frame = NSRect(x:20,y:342,width:510,height:24);view.addSubview(randomWidthToggle)
        row("minimumWidth","最小宽 / Min width",378,24,1200,view)
        row("maximumWidth","最大宽 / Max width",414,24,1200,view)
        row("bands","文献分段 / Sections",450,2,16,view,"")
        regenerate = NSButton(title:"重新随机 / Shuffle",target:self,action:#selector(shuffle));regenerate.frame = NSRect(x:20,y:488,width:180,height:28);view.addSubview(regenerate)
        _ = label("色板 / Palette  ·  1–12 色",20,530,260,view)
        let presets = NSPopUpButton(frame:NSRect(x:310,y:522,width:220,height:28));presets.addItems(withTitles:["载入配色 / Load palette"]+paletteNames);presets.target = self;presets.action = #selector(paletteChanged(_:));view.addSubview(presets)
        for i in 0..<12 {
            let b = NSButton(title:"",target:self,action:#selector(selectColor(_:)));b.tag = i;b.isBordered = false;b.wantsLayer = true;b.frame = NSRect(x:20+i*42,y:560,width:36,height:28);view.addSubview(b);wells.append(b)
        }
        colorWell = NSColorWell(frame:NSRect(x:20,y:604,width:48,height:28));colorWell.target = self;colorWell.action = #selector(colorPicked);view.addSubview(colorWell)
        hexField = NSTextField(frame:NSRect(x:80,y:606,width:105,height:25));hexField.identifier = NSUserInterfaceItemIdentifier("hex");hexField.delegate = self;view.addSubview(hexField)
        addColor = NSButton(title:"＋ 添加 / Add",target:self,action:#selector(add));addColor.frame = NSRect(x:204,y:602,width:140,height:30);view.addSubview(addColor)
        removeColor = NSButton(title:"－ 删除 / Remove",target:self,action:#selector(remove));removeColor.frame = NSRect(x:350,y:602,width:180,height:30);view.addSubview(removeColor)
        let saveButton = NSButton(title:"保存为默认 / Save default",target:self,action:#selector(saveDefault));saveButton.frame = NSRect(x:20,y:648,width:240,height:30);view.addSubview(saveButton)
        let presetButton = NSButton(title:"保存个人预设 / Save preset",target:self,action:#selector(savePreset));presetButton.frame = NSRect(x:280,y:648,width:250,height:30);view.addSubview(presetButton)
        note = label("输入后按回车或离开输入框生效 / Enter or leave field to apply",20,690,520,view);note.font = .systemFont(ofSize:11)
        _ = label("px 为屏幕逻辑单位；文献模式按区域分段，不自动识别正文。",20,719,520,view).font = .systemFont(ofSize:11)
        win.center();return win
    }
    private func values() -> [String:Int] {
        let a = state.current
        return ["width":a.width,"height":a.height,"opacity":a.opacity,"brickWidth":a.brickWidth,"brickHeight":a.brickHeight,"minimumHeight":a.minimumHeight,"maximumHeight":a.maximumHeight,"bands":a.bands,"minimumWidth":a.minimumWidth,"maximumWidth":a.maximumWidth]
    }
    private func set(_ key:String,_ n:Int) {
        switch key {
        case "width":state.current.width = n
        case "height":state.current.height = n
        case "opacity":state.current.opacity = n
        case "brickWidth":state.current.brickWidth = n
        case "brickHeight":state.current.brickHeight = n
        case "minimumHeight":state.current.minimumHeight = n;state.current.maximumHeight = max(n,state.current.maximumHeight)
        case "maximumHeight":state.current.maximumHeight = n;state.current.minimumHeight = min(n,state.current.minimumHeight)
        case "minimumWidth":state.current.minimumWidth = n;state.current.maximumWidth = max(n,state.current.maximumWidth)
        case "maximumWidth":state.current.maximumWidth = n;state.current.minimumWidth = min(n,state.current.minimumWidth)
        case "bands":state.current.bands = n
        default:return
        }
        apply()
    }
    @objc private func slid(_ sender:NSSlider) { if let k = sender.identifier?.rawValue { set(k,Int(sender.doubleValue.rounded())) } }
    func controlTextDidEndEditing(_ notification:Notification) {
        guard let f = notification.object as? NSTextField,let key = f.identifier?.rawValue else { return }
        if key == "hex" {
            guard let h = Appearance.hex(f.stringValue) else { note.stringValue = "请输入 #RRGGBB / Enter #RRGGBB";sync();return }
            state.current.colors[chosenColor] = h;apply();return
        }
        guard let n = Int(f.stringValue.trimmingCharacters(in:.whitespacesAndNewlines)) else { note.stringValue = "请输入整数 / Enter a whole number";sync();return }
        set(key,n)
        note.stringValue = values()[key] == n ? "已应用 / Applied" : "已调整到支持范围 / Adjusted to supported range"
    }
    @objc private func modeChanged() { state.current.mode = modePopup.indexOfSelectedItem;apply() }
    @objc private func randomWidthChanged() { state.current.randomWidth = randomWidthToggle.state == .on;apply() }
    @objc private func shuffle() { state.current.seed &+= 1;apply() }
    @objc private func paletteChanged(_ sender:NSPopUpButton) { let index = sender.indexOfSelectedItem-1;guard index>=0 else { return };state.current.colors = palettes[index];chosenColor = 0;sender.selectItem(at:0);apply() }
    @objc private func selectColor(_ sender:NSButton) { chosenColor = sender.tag;sync() }
    @objc private func colorPicked() { state.current.colors[chosenColor] = colorWell.color.hex;apply() }
    @objc private func add() { guard state.current.colors.count<12 else { return };state.current.colors.append(state.current.colors[chosenColor]);chosenColor = state.current.colors.count-1;apply() }
    @objc private func remove() { guard state.current.colors.count>1 else { return };state.current.colors.remove(at:chosenColor);chosenColor = min(chosenColor,state.current.colors.count-1);apply() }
    private func sync() {
        guard settings != nil else { return }
        let a = state.current
        modePopup.selectItem(at:a.mode)
        modeHint.stringValue = ["等高错缝砖块 / Uniform staggered bricks",a.randomWidth ? "每行随机高、每块随机宽 / Random rows and widths" : "每块独立高度 / Random heights; fixed width","整宽大色块划分阅读区 / Full-width bands for longer passages"][a.mode]
        for (key,value) in values() { fields[key]?.integerValue = value;sliders[key]?.doubleValue = Double(value) }
        for key in ["brickWidth","brickHeight","minimumHeight","maximumHeight","minimumWidth","maximumWidth","bands"] {
            let enabled = key == "bands" ? a.mode == 2 : key == "brickWidth" ? (a.mode == 0 || (a.mode == 1 && !a.randomWidth)) : (key == "minimumWidth" || key == "maximumWidth") ? (a.mode == 1 && a.randomWidth) : key == "brickHeight" ? a.mode == 0 : a.mode == 1
            fields[key]?.isEnabled = enabled;sliders[key]?.isEnabled = enabled
        }
        randomWidthToggle.state = a.randomWidth ? .on : .off
        randomWidthToggle.isEnabled = a.mode == 1
        regenerate.isEnabled = a.mode == 1
        chosenColor = min(chosenColor,a.colors.count-1)
        for (i,b) in wells.enumerated() {
            b.isHidden = i>=a.colors.count
            if i<a.colors.count { b.layer?.backgroundColor = NSColor(hex:a.colors[i]).cgColor;b.layer?.borderWidth = i==chosenColor ? 3 : 1;b.layer?.borderColor = (i==chosenColor ? NSColor.labelColor : NSColor.separatorColor).cgColor;b.layer?.cornerRadius = 4 }
        }
        colorWell.color = NSColor(hex:a.colors[chosenColor]);hexField.stringValue = "#"+a.colors[chosenColor]
        addColor.isEnabled = a.colors.count<12;removeColor.isEnabled = a.colors.count>1
    }
}

@main
struct BrickOverlayApp {
    @MainActor static func main() {
        let app = NSApplication.shared;let delegate = AppDelegate();app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
