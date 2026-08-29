// ViewModels/OmanixViewModel.swift
// Omanix — the functionality layer bridging Data (OmanixStore) to Views.
// Owns all @Published UI state, instantiates the store, and exposes
// thin async operations. Views never touch the store directly.

import Foundation
import SwiftUI

@MainActor
final class OmanixViewModel: ObservableObject {

    // MARK: Published state (what views render)

    @Published var searchQuery = "" {
        didSet { scheduleSearch() }
    }
    @Published var searchResults: [PackageItem] = []
    @Published var declaredPackages: [PackageItem] = []
    @Published var installedCount = 0
    @Published var sourceCount = 0

    @Published var widgets: [WidgetItem] = []
    @Published var themes: [ThemeItem] = []
    @Published var currentTheme = "omanix"

    @Published var isSearching = false
    @Published var isRebuilding = false
    @Published var needsRebuild = false
    @Published var rebuildLog: [String] = []
    @Published var brewIndexReady = false
    @Published var isIndexingBrew = false

    @Published var message: String?
    @Published var messageKind: MessageKind?

    enum MessageKind { case success, error }

    // MARK: Derived / system info

    var systemUser: String { NSUserName() }
    var systemHost: String {
        ProcessInfo.processInfo.hostName
    }
    var versionString: String {
        (try? String(contentsOfFile: NSHomeDirectory() + "/.omanix/version", encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "0.1.0"
    }

    // MARK: Dependencies

    private let store: OmanixStore
    private var searchTask: Task<Void, Never>?
    private var messageTimer: Task<Void, Never>?
    private var lastQuery = ""

    // MARK: Init

    init(store: OmanixStore = OmanixStore()) {
        self.store = store
        FileLogger.shared.rotate()
        FileLogger.shared.info("vm", "app launched")

        loadWidgets()
        loadThemes()
        refreshDeclared()
    }

    // MARK: - Installed

    func refreshDeclared() {
        Task {
            do {
                let items = try await store.declaredPackages()
                declaredPackages = items
                installedCount = items.count
                sourceCount = Set(items.map(\.source)).count
                brewIndexReady = store.brewIndexReady
            } catch {
                FileLogger.shared.error("vm", "refreshDeclared failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Search

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = searchQuery

        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, !query.isEmpty else { return }
            await performSearch(query)
        }
    }

    private func performSearch(_ query: String) async {
        guard query != lastQuery else { return }
        lastQuery = query
        isSearching = true
        searchResults = await store.search(query: query, declared: declaredPackages)
        isSearching = false
    }

    func refreshBrewIndex() {
        isIndexingBrew = true
        Task {
            await store.refreshBrewIndex()
            brewIndexReady = store.brewIndexReady
            isIndexingBrew = false
        }
    }

    // MARK: - Install / uninstall

    func install(_ package: PackageItem) async {
        do {
            try await store.addPackage(package)
            showMessage("Added \(package.name) to configuration", .success)
            needsRebuild = true
            markInstalled(package, installed: true)
        } catch {
            showMessage("Failed to install \(package.name): \(error.localizedDescription)", .error)
        }
    }

    func uninstall(_ package: PackageItem) async {
        do {
            try await store.removePackage(package)
            showMessage("Removed \(package.name)", .success)
            declaredPackages.removeAll { $0.name == package.name }
            installedCount = declaredPackages.count
            sourceCount = Set(declaredPackages.map(\.source)).count
            markInstalled(package, installed: false)
        } catch {
            showMessage("Failed to remove \(package.name): \(error.localizedDescription)", .error)
        }
    }

    private func markInstalled(_ package: PackageItem, installed: Bool) {
        if let i = searchResults.firstIndex(where: { $0.id == package.id }) {
            searchResults[i].isInstalled = installed
        }
    }

    // MARK: - System actions

    func rebuild() {
        isRebuilding = true
        needsRebuild = false
        rebuildLog = []
        Task {
            do {
                let lines = try await store.rebuild()
                rebuildLog = lines
                showMessage("System rebuilt successfully", .success)
            } catch {
                rebuildLog = []
                showMessage("Rebuild failed: \(error.localizedDescription)", .error)
            }
            isRebuilding = false
        }
    }

    func rollback() {
        Task {
            do {
                try await store.rollback()
                showMessage("Rolled back successfully", .success)
            } catch {
                showMessage("Rollback failed: \(error.localizedDescription)", .error)
            }
        }
    }

    func updateFlake() {
        Task {
            do {
                try await store.updateFlake()
                showMessage("Flake updated successfully", .success)
            } catch {
                showMessage("Update failed: \(error.localizedDescription)", .error)
            }
        }
    }

    // MARK: - Widgets

    func loadWidgets() {
        let barState = store.currentOmabarState()
        let tilesState = store.currentOmatilesState()
        omabarEnabled = barState.enable
        omabarPosition = barState.position
        omabarHeight = barState.height
        omabarTransparent = barState.transparent
        omabarBlur = barState.blur
        omabarStyle = barState.style
        omabarColorScheme = barState.colorScheme
        omabarShowClock = barState.showClock
        omabarShowBattery = barState.showBattery
        omabarShowVolume = barState.showVolume
        omabarShowWifi = barState.showWifi
        omatilesEnabled = tilesState.enable
        omatilesLayout = tilesState.layout
        omatilesGapInner = tilesState.gapInner
        omatilesGapOuter = tilesState.gapOuter
        omatilesBindings = tilesState.bindings
        omatilesWatch = tilesState.watch
        omatilesFloatingApps = tilesState.floatingApps

        widgets = [
            WidgetItem(id: "store", name: "Omanix", icon: "bag", isEnabled: true),
            WidgetItem(id: "omabar", name: "Omabar", icon: "rectangle.topthird.inset.filled", isEnabled: omabarEnabled),
            WidgetItem(id: "omatiles", name: "Omatiles", icon: "rectangle.3.group", isEnabled: omatilesEnabled),
            WidgetItem(id: "pomodoro", name: "Pomodoro Timer", icon: "timer", isEnabled: false),
            WidgetItem(id: "clock", name: "Clock", icon: "clock", isEnabled: false),
        ]
    }

    func toggleWidget(_ widget: WidgetItem) {
        guard let i = widgets.firstIndex(where: { $0.id == widget.id }) else { return }
        // Omabar + Omatiles are desktop modules (omanix.omabar./omanix.omatiles.),
        // handled here so you can switch them on/off right from the Widgets page.
        switch widget.id {
        case "omabar":
            setOmabarEnabled(!widgets[i].isEnabled)
            widgets[i].isEnabled = omabarEnabled
            return
        case "omatiles":
            setOmatilesEnabled(!widgets[i].isEnabled)
            widgets[i].isEnabled = omatilesEnabled
            return
        default:
            break
        }
        widgets[i].isEnabled.toggle()
        do {
            try store.setWidgetEnabled(widget.id, widgets[i].isEnabled)
            needsRebuild = true
        } catch {
            widgets[i].isEnabled.toggle()
            showMessage("Could not update widget: \(error.localizedDescription)", .error)
        }
    }

    // MARK: - Omabar appearance (mirrors omanix.omabar.*)

    @Published var omabarEnabled: Bool = true
    @Published var omabarPosition: String = "top"
    @Published var omabarHeight: Int = 40
    @Published var omabarTransparent: Bool = false
    @Published var omabarBlur: Bool = true
    @Published var omabarStyle: String = "default"
    @Published var omabarColorScheme: String = "auto"
    @Published var omabarShowClock: Bool = true
    @Published var omabarShowBattery: Bool = true
    @Published var omabarShowVolume: Bool = true
    @Published var omabarShowWifi: Bool = true

    var omabarRunning: Bool { OmabarManager.shared.isRunning }

    private func omabarSettings() -> RuntimeSettings.Omabar {
        RuntimeSettings.Omabar(
            enable: omabarEnabled,
            position: omabarPosition,
            height: omabarHeight,
            transparent: omabarTransparent,
            blur: omabarBlur,
            style: omabarStyle,
            colorScheme: omabarColorScheme,
            showClock: omabarShowClock,
            showBattery: omabarShowBattery,
            showVolume: omabarShowVolume,
            showWifi: omabarShowWifi
        )
    }

    private func applyOmabarToRuntime() {
        if omabarEnabled {
            if OmabarManager.shared.isRunning {
                OmabarManager.shared.apply(settings: omabarSettings())
            } else {
                _ = OmabarManager.shared.start(settings: omabarSettings())
            }
        } else {
            OmabarManager.shared.stop()
        }
    }

    func launchOmabar() {
        guard !OmabarManager.shared.isRunning else { return }
        _ = OmabarManager.shared.start(settings: omabarSettings())
    }

    func stopOmabar() {
        OmabarManager.shared.stop()
    }

    func setOmabarEnabled(_ enabled: Bool) {
        omabarEnabled = enabled
        do { try store.setOmabarEnabled(enabled); needsRebuild = true; applyOmabarToRuntime() }
        catch { omabarEnabled = !enabled; showMessage("Could not set Omabar: \(error.localizedDescription)", .error) }
    }
    func setOmabarPosition(_ pos: String) {
        omabarPosition = pos
        do { try store.setOmabarPosition(pos); needsRebuild = true; applyOmabarToRuntime() }
        catch { showMessage("Could not set bar position: \(error.localizedDescription)", .error) }
    }
    func setOmabarHeight(_ height: Int) {
        omabarHeight = height
        do { try store.setOmabarHeight(height); needsRebuild = true; applyOmabarToRuntime() }
        catch { showMessage("Could not set bar height: \(error.localizedDescription)", .error) }
    }
    func toggleOmabarTransparent() {
        omabarTransparent.toggle()
        do { try store.setOmabarTransparent(omabarTransparent); needsRebuild = true; applyOmabarToRuntime() }
        catch { omabarTransparent.toggle(); showMessage("Could not set transparency: \(error.localizedDescription)", .error) }
    }
    func toggleOmabarBlur() {
        omabarBlur.toggle()
        do { try store.setOmabarBlur(omabarBlur); needsRebuild = true; applyOmabarToRuntime() }
        catch { omabarBlur.toggle(); showMessage("Could not set blur: \(error.localizedDescription)", .error) }
    }
    func setOmabarStyle(_ style: String) {
        omabarStyle = style
        do { try store.setOmabarStyle(style); needsRebuild = true; applyOmabarToRuntime() }
        catch { showMessage("Could not set style: \(error.localizedDescription)", .error) }
    }
    func setOmabarColorScheme(_ scheme: String) {
        omabarColorScheme = scheme
        do { try store.setOmabarColorScheme(scheme); needsRebuild = true; applyOmabarToRuntime() }
        catch { showMessage("Could not set color scheme: \(error.localizedDescription)", .error) }
    }
    func toggleOmabarShowClock() {
        omabarShowClock.toggle()
        do { try store.setOmabarShowClock(omabarShowClock); needsRebuild = true; applyOmabarToRuntime() }
        catch { omabarShowClock.toggle(); showMessage("Could not update Omabar items: \(error.localizedDescription)", .error) }
    }
    func toggleOmabarShowBattery() {
        omabarShowBattery.toggle()
        do { try store.setOmabarShowBattery(omabarShowBattery); needsRebuild = true; applyOmabarToRuntime() }
        catch { omabarShowBattery.toggle(); showMessage("Could not update Omabar items: \(error.localizedDescription)", .error) }
    }
    func toggleOmabarShowVolume() {
        omabarShowVolume.toggle()
        do { try store.setOmabarShowVolume(omabarShowVolume); needsRebuild = true; applyOmabarToRuntime() }
        catch { omabarShowVolume.toggle(); showMessage("Could not update Omabar items: \(error.localizedDescription)", .error) }
    }
    func toggleOmabarShowWifi() {
        omabarShowWifi.toggle()
        do { try store.setOmabarShowWifi(omabarShowWifi); needsRebuild = true; applyOmabarToRuntime() }
        catch { omabarShowWifi.toggle(); showMessage("Could not update Omabar items: \(error.localizedDescription)", .error) }
    }

    // MARK: - Omatiles window tiling (mirrors omanix.omatiles.*)

    @Published var omatilesEnabled: Bool = true
    @Published var omatilesLayout: String = "tiles"
    @Published var omatilesGapInner: Int = 8
    @Published var omatilesGapOuter: Int = 10
    @Published var omatilesBindings: Bool = true
    @Published var omatilesWatch: Bool = false
    @Published var omatilesFloatingApps: [String] = []

    var omatilesRunning: Bool { OmatilesEngine.shared.isRunning }
    var omatilesTiledCount: Int { OmatilesEngine.shared.tiledCount }

    private func omatilesSettings() -> RuntimeSettings.Omatiles {
        RuntimeSettings.Omatiles(
            enable: omatilesEnabled,
            layout: omatilesLayout,
            gapInner: omatilesGapInner,
            gapOuter: omatilesGapOuter,
            bindings: omatilesBindings,
            watch: omatilesWatch,
            floatingApps: omatilesFloatingApps.isEmpty ? ["com.apple.finder", "com.apple.systempreferences", "com.apple.ActivityMonitor"] : omatilesFloatingApps
        )
    }

    private func applyOmatilesToRuntime() {
        if omatilesEnabled {
            if OmatilesEngine.shared.isRunning {
                OmatilesEngine.shared.apply(settings: omatilesSettings())
            } else {
                OmatilesEngine.shared.start(settings: omatilesSettings())
            }
        } else {
            OmatilesEngine.shared.stop()
        }
    }

    func launchOmatiles() {
        guard !OmatilesEngine.shared.isRunning else { return }
        OmatilesEngine.shared.start(settings: omatilesSettings())
    }

    func stopOmatiles() {
        OmatilesEngine.shared.stop()
    }

    func tileNow() {
        if OmatilesEngine.ensureAccessibility() {
            OmatilesEngine.shared.tile()
        }
    }

    func setOmatilesEnabled(_ enabled: Bool) {
        omatilesEnabled = enabled
        do { try store.setOmatilesEnabled(enabled); needsRebuild = true; applyOmatilesToRuntime() }
        catch { omatilesEnabled = !enabled; showMessage("Could not set Omatiles: \(error.localizedDescription)", .error) }
    }
    func setOmatilesLayout(_ layout: String) {
        omatilesLayout = layout
        do { try store.setOmatilesLayout(layout); needsRebuild = true; applyOmatilesToRuntime() }
        catch { showMessage("Could not set layout: \(error.localizedDescription)", .error) }
    }
    func setOmatilesGapInner(_ gap: Int) {
        omatilesGapInner = gap
        do { try store.setOmatilesGapInner(gap); needsRebuild = true; applyOmatilesToRuntime() }
        catch { showMessage("Could not set inner gap: \(error.localizedDescription)", .error) }
    }
    func setOmatilesGapOuter(_ gap: Int) {
        omatilesGapOuter = gap
        do { try store.setOmatilesGapOuter(gap); needsRebuild = true; applyOmatilesToRuntime() }
        catch { showMessage("Could not set outer gap: \(error.localizedDescription)", .error) }
    }
    func toggleOmatilesBindings() {
        omatilesBindings.toggle()
        do { try store.setOmatilesBindings(omatilesBindings); needsRebuild = true; applyOmatilesToRuntime() }
        catch { omatilesBindings.toggle(); showMessage("Could not set bindings: \(error.localizedDescription)", .error) }
    }
    func toggleOmatilesWatch() {
        omatilesWatch.toggle()
        do { try store.setOmatilesWatch(omatilesWatch); needsRebuild = true; applyOmatilesToRuntime() }
        catch { omatilesWatch.toggle(); showMessage("Could not set watch mode: \(error.localizedDescription)", .error) }
    }
    func setOmatilesFloatingApps(_ apps: [String]) {
        let cleaned = apps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        omatilesFloatingApps = cleaned
        do { try store.setOmatilesFloatingApps(cleaned); needsRebuild = true; applyOmatilesToRuntime() }
        catch { showMessage("Could not set floating apps: \(error.localizedDescription)", .error) }
    }

    // MARK: - Themes (13 — mirrors themes/*/colors.toml via lib/themed.nix, omanix = signature Omakase light)

    func loadThemes() {
        themes = [
            ThemeItem(id: "omanix", name: "Omanix", description: "Signature Omakase — light, clean, OC palette", mode: "Light", colors: [
                .background: OColor(hex: "FBFBFC"), .surface: OColor(hex: "FFFFFF"), .accent: OColor(hex: "0A7CFF"), .text: OColor(hex: "1D1D1F"), .muted: OColor(hex: "AEAEB4"), .selection: OColor(hex: "E6E6EA"), .darkBackground: OColor(hex: "F6F6F7"),
            ]),
            ThemeItem(id: "tokyo-night", name: "Tokyo Night", description: "Tokyo after hours — deep indigo", mode: "Dark", colors: [
                .background: OColor(hex: "1a1b26"), .surface: OColor(hex: "24283b"), .accent: OColor(hex: "7aa2f7"), .text: OColor(hex: "c0caf5"), .muted: OColor(hex: "414868"), .selection: OColor(hex: "292e42"), .darkBackground: OColor(hex: "13141c"),
            ]),
            ThemeItem(id: "catppuccin", name: "Catppuccin Mocha", description: "Pastel mocha — soft and balanced", mode: "Dark", colors: [
                .background: OColor(hex: "1e1e2e"), .surface: OColor(hex: "313244"), .accent: OColor(hex: "89b4fa"), .text: OColor(hex: "cdd6f4"), .muted: OColor(hex: "585b70"), .selection: OColor(hex: "45475a"), .darkBackground: OColor(hex: "161622"),
            ]),
            ThemeItem(id: "gruvbox", name: "Gruvbox", description: "Warm retro — amber & wood", mode: "Dark", colors: [
                .background: OColor(hex: "282828"), .surface: OColor(hex: "3c3836"), .accent: OColor(hex: "fe8019"), .text: OColor(hex: "fbf1c7"), .muted: OColor(hex: "928374"), .selection: OColor(hex: "3c3836"), .darkBackground: OColor(hex: "1d2021"),
            ]),
            ThemeItem(id: "everforest", name: "Everforest", description: "Forest green — low contrast calm", mode: "Dark", colors: [
                .background: OColor(hex: "2b3339"), .surface: OColor(hex: "3a4540"), .accent: OColor(hex: "a7c080"), .text: OColor(hex: "f0e0c0"), .muted: OColor(hex: "859289"), .selection: OColor(hex: "3d4840"), .darkBackground: OColor(hex: "232a2e"),
            ]),
            ThemeItem(id: "kanagawa", name: "Kanagawa Wave", description: "Japanese wave — granite & ink", mode: "Dark", colors: [
                .background: OColor(hex: "1f1f28"), .surface: OColor(hex: "2a2a37"), .accent: OColor(hex: "7e9cd8"), .text: OColor(hex: "dcd7ba"), .muted: OColor(hex: "727169"), .selection: OColor(hex: "2d4f67"), .darkBackground: OColor(hex: "16161d"),
            ]),
            ThemeItem(id: "rose-pine", name: "Rosé Pine", description: "Muted rosé — soft plum", mode: "Dark", colors: [
                .background: OColor(hex: "191724"), .surface: OColor(hex: "1f1d2e"), .accent: OColor(hex: "ebbcba"), .text: OColor(hex: "e0def4"), .muted: OColor(hex: "6e6a86"), .selection: OColor(hex: "26233a"), .darkBackground: OColor(hex: "12111a"),
            ]),
            ThemeItem(id: "nord", name: "Nord", description: "Arctic frost — cool slate", mode: "Dark", colors: [
                .background: OColor(hex: "2e3440"), .surface: OColor(hex: "3b4252"), .accent: OColor(hex: "88c0d0"), .text: OColor(hex: "eceff4"), .muted: OColor(hex: "4c566a"), .selection: OColor(hex: "434c5e"), .darkBackground: OColor(hex: "242933"),
            ]),
            ThemeItem(id: "dracula", name: "Dracula", description: "Vampire purple — midnight neon", mode: "Dark", colors: [
                .background: OColor(hex: "282a36"), .surface: OColor(hex: "343746"), .accent: OColor(hex: "bd93f9"), .text: OColor(hex: "f8f8f2"), .muted: OColor(hex: "6272a4"), .selection: OColor(hex: "44475a"), .darkBackground: OColor(hex: "1e1f29"),
            ]),
            ThemeItem(id: "solarized-dark", name: "Solarized Dark", description: "Solarized — ethan schooner", mode: "Dark", colors: [
                .background: OColor(hex: "002b36"), .surface: OColor(hex: "073642"), .accent: OColor(hex: "268bd2"), .text: OColor(hex: "eee8d5"), .muted: OColor(hex: "586e75"), .selection: OColor(hex: "073642"), .darkBackground: OColor(hex: "001e26"),
            ]),
            ThemeItem(id: "one-dark", name: "One Dark", description: "Atom One Dark — modern slate", mode: "Dark", colors: [
                .background: OColor(hex: "282c34"), .surface: OColor(hex: "2c313a"), .accent: OColor(hex: "61afef"), .text: OColor(hex: "ffffff"), .muted: OColor(hex: "5c6370"), .selection: OColor(hex: "3e4452"), .darkBackground: OColor(hex: "21252b"),
            ]),
            ThemeItem(id: "matte-black", name: "Matte Black", description: "Pure OLED — true black", mode: "Dark", colors: [
                .background: OColor(hex: "0a0a0a"), .surface: OColor(hex: "1a1a1a"), .accent: OColor(hex: "d4d4d4"), .text: OColor(hex: "ffffff"), .muted: OColor(hex: "3a3a3a"), .selection: OColor(hex: "1e1e1e"), .darkBackground: OColor(hex: "050505"),
            ]),
            ThemeItem(id: "horizon", name: "Horizon", description: "Sunset horizon — peach & dusk", mode: "Dark", colors: [
                .background: OColor(hex: "1c1e26"), .surface: OColor(hex: "2a2c38"), .accent: OColor(hex: "fab795"), .text: OColor(hex: "ffffff"), .muted: OColor(hex: "6c6f93"), .selection: OColor(hex: "2e303e"), .darkBackground: OColor(hex: "16161e"),
            ]),
        ]
        // Read actual current theme from disk (theme.json or configuration.nix)
        currentTheme = store.currentThemeId()
        if !themes.contains(where: { $0.id == currentTheme }) { currentTheme = "omanix" }
    }

    func selectTheme(_ theme: ThemeItem) {
        currentTheme = theme.id
        do {
            try store.setTheme(theme.id)
            needsRebuild = true
            showMessage("Theme set to \(theme.name) — rebuild to apply", .success)
        } catch {
            showMessage("Could not set theme: \(error.localizedDescription)", .error)
        }
    }

    // MARK: - Messages

    private func showMessage(_ text: String, _ kind: MessageKind) {
        messageTimer?.cancel()
        message = text
        messageKind = kind
        messageTimer = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            message = nil
        }
    }
}
