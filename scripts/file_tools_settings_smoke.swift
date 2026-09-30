import AppKit
import Darwin
import FileMintCore
import SwiftUI

/// Uses the production SwiftUI surface and native images with in-memory preferences.
/// Never opens a user's preferences, performs a file operation or registers an extension.
@main
struct FileToolsSettingsSmoke: App {
    init() {
        for tool in FileTool.allCases {
            for size: CGFloat in [16, 20] {
                guard let image = FileToolAppearance.image(for: tool, size: size),
                      image.size == NSSize(width: size, height: size), !image.isTemplate,
                      let raster = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
                else { fatalError("Missing native icon: \(tool.rawValue)") }
                let pixels = NSBitmapImageRep(cgImage: raster)
                let hasColor = (0..<pixels.pixelsHigh).contains { y in
                    (0..<pixels.pixelsWide).contains { x in
                        guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                              color.alphaComponent > 0.5 else { return false }
                        return max(color.redComponent, color.greenComponent, color.blueComponent)
                            - min(color.redComponent, color.greenComponent, color.blueComponent) > 0.1
                    }
                }
                precondition(hasColor, "Icon lost its color: \(tool.rawValue)")
            }
        }
        precondition(FileToolAppearance.toolsImage != nil && FileToolAppearance.moveHereImage != nil)
        verifyIconStyles()
        if CommandLine.arguments.contains("--verify-icons") { exit(0) }
    }

    var body: some Scene {
        WindowGroup("FileMint Tools UI QA") { FixtureView() }
            .defaultSize(width: 632, height: 600)
            .windowResizability(.contentSize)
    }
}

private func verifyIconStyles() {
    func check(_ image: NSImage?, style: FinderMenuIconStyle, label: String) {
        guard let image, image.isTemplate == (style == .systemMonochrome),
              let raster = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { fatalError("Missing icon or incorrect rendering mode: \(label)") }
        let pixels = NSBitmapImageRep(cgImage: raster)
        var visible = false
        var hasColor = false
        for y in 0..<pixels.pixelsHigh {
            for x in 0..<pixels.pixelsWide {
                guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.5 else { continue }
                visible = true
                if max(color.redComponent, color.greenComponent, color.blueComponent)
                    - min(color.redComponent, color.greenComponent, color.blueComponent) > 0.1 { hasColor = true }
            }
        }
        precondition(visible, "Empty icon: \(label)")
        precondition(style == .colored ? hasColor : !hasColor, "Unexpected icon colors: \(label)")
    }
    precondition(Bundle.main.image(forResource: "FinderMenuIcon") != nil)
    precondition(Bundle.main.image(forResource: "FinderRootMenuIcon") != nil)
    let custom = MenuIconCustomization(symbolName: "folder.fill.badge.plus", primaryHex: "#CC3300", secondaryHex: "#0066CC")!
    let missing = MenuIconCustomization(symbolName: "filemint.missing.symbol", primaryHex: "#CC3300", secondaryHex: "#0066CC")!
    for style in FinderMenuIconStyle.allCases {
        for slot in MenuIconSlot.allCases {
            check(FileToolAppearance.image(for: slot, defaultBundle: .main, style: style),
                style: style, label: slot.rawValue)
            check(FileToolAppearance.image(for: slot, customization: custom, defaultBundle: .main, style: style),
                style: style, label: "custom-\(slot.rawValue)")
            check(FileToolAppearance.image(for: slot, customization: missing, defaultBundle: .main, style: style),
                style: style, label: "fallback-\(slot.rawValue)")
        }
        for var template in TemplateCatalog.builtInTemplates {
            check(FileToolAppearance.image(for: template, style: style), style: style, label: template.id)
            template.customMenuIcon = custom
            check(FileToolAppearance.image(for: template, style: style), style: style, label: "custom-\(template.id)")
            template.customMenuIcon = missing
            check(FileToolAppearance.image(for: template, style: style), style: style, label: "fallback-\(template.id)")
        }
    }
    if let directory = Bundle.main.object(forInfoDictionaryKey: "FixturePath") as? String {
        let result = ["passed": true, "styles": FinderMenuIconStyle.allCases.map(\.rawValue),
                      "slots": MenuIconSlot.allCases.count, "templates": TemplateCatalog.builtInTemplates.count] as [String: Any]
        let data = try! JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        try! data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("icon-rendering-checks.json"))
    }
    print("PASS native colored/monochrome icons, custom symbols, logo and unavailable-symbol fallback")
}

private struct FixtureView: View {
    @State private var preferences: FileToolsPreferences = {
        var value = FileToolsPreferences()
        value.isEnabled = true
        value.permanentDelete = true
        return value
    }()
    @State private var language = AppLanguage.chinese
    @State private var dark = false
    @State private var menuIcons: [String: MenuIconCustomization] = [:]
    @State private var iconStyle = FinderMenuIconStyle.colored

    private func text(_ key: FileMintTextKey) -> String {
        FileMintStrings.text(key, language: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Picker("QA language", selection: $language) {
                    Text("中文").tag(AppLanguage.chinese)
                    Text("English").tag(AppLanguage.english)
                }.frame(width: 180)
                Toggle("QA dark", isOn: $dark).toggleStyle(.checkbox)
                Spacer()
                NativeToolMenu(language: language, menuIcons: menuIcons, style: iconStyle).frame(width: 125, height: 24)
            }.padding(10)
            PreferenceRow(title: text(.finderMenuIconStyle)) {
                FinderMenuIconStylePicker(selection: $iconStyle, language: language)
            }.padding(.horizontal, 10).padding(.bottom, 10)
            Divider()
            VStack(alignment: .leading, spacing: 7) {
                Text(text(.fileTools)).font(.system(size: 25, weight: .bold))
                Text(text(.fileToolsHint)).font(.callout).foregroundStyle(.secondary)
            }.padding(28)
            Divider().padding(.horizontal, 28)
            FileToolsSettingsView(preferences: $preferences, language: language, menuIcons: $menuIcons).padding(28)
        }
        // 840-point minimum app width minus its 208-point sidebar.
        .frame(width: 632, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(dark ? .dark : .light)
        .environment(\.finderMenuIconStyle, iconStyle)
        .onAppear { record(preferences); recordIcons() }
        .onChange(of: preferences) { record($0) }
        .onChange(of: iconStyle) { _ in recordIcons() }
        .onChange(of: menuIcons) { _ in recordIcons() }
    }

    private func record(_ value: FileToolsPreferences) {
        guard let directory = Bundle.main.object(forInfoDictionaryKey: "FixturePath") as? String,
              let data = try? JSONEncoder().encode(value) else { return }
        // Readback for regression checks; this path is inside the disposable QA build.
        try? data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("last-state.json"), options: .atomic)
    }

    private func recordIcons() {
        struct IconState: Encodable {
            let style: FinderMenuIconStyle
            let icons: [String: MenuIconCustomization]
        }
        guard let directory = Bundle.main.object(forInfoDictionaryKey: "FixturePath") as? String,
              let data = try? JSONEncoder().encode(IconState(style: iconStyle, icons: menuIcons)) else { return }
        try? data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("last-icons-state.json"), options: .atomic)
    }
}

private struct NativeToolMenu: NSViewRepresentable {
    let language: AppLanguage
    let menuIcons: [String: MenuIconCustomization]
    let style: FinderMenuIconStyle

    func makeNSView(context: Context) -> NSPopUpButton {
        NSPopUpButton(frame: .zero, pullsDown: true)
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(withTitle: "QA menu icons", action: nil, keyEquivalent: "")
        func addTools(to menu: NSMenu) {
            for tool in FileTool.allCases {
                let item = NSMenuItem(title: FileMintStrings.text(tool.title, language: language),
                                      action: nil, keyEquivalent: "")
                item.image = FileToolAppearance.image(for: tool,
                    customization: menuIcons[tool.menuIconSlot.rawValue], style: style)
                menu.addItem(item)
            }
            let item = NSMenuItem(title: FileMintStrings.text(.moveSelectedHere, language: language),
                                  action: nil, keyEquivalent: "")
            item.image = FileToolAppearance.image(for: .moveHere,
                customization: menuIcons[MenuIconSlot.moveHere.rawValue], style: style)
            menu.addItem(item)
        }
        addTools(to: menu)
        let root = NSMenuItem(title: "QA submenu", action: nil, keyEquivalent: "")
        root.image = FileToolAppearance.image(for: .fileTools,
            customization: menuIcons[MenuIconSlot.fileTools.rawValue], style: style)
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        addTools(to: submenu)
        root.submenu = submenu
        menu.addItem(root)
        button.menu = menu
    }
}
