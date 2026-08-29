// Modules/Omabar/OmabarContentView.swift
// SwiftUI content of the Omabar panel. Stateless — it renders whatever the
// OmabarModel publishes plus the settings struct handed down by the manager.
//
// The bar draws full-width (a native menu bar always spans the screen, notch and
// all); `leadingInset`/`trailingInset` come from NSScreen.safeAreaInsets so items
// flow around the notch instead of under it. Colors follow the active theme
// palette when `colorScheme == "auto"`.

import SwiftUI
import AppKit

struct OmabarContentView: View {
    @ObservedObject var model: OmabarModel
    let settings: RuntimeSettings.Omabar
    var onAppleClick: () -> Void

    /// Left/right insets (points) that keep the bar's content out of notch shadow.
    let leadingInset: CGFloat
    let trailingInset: CGFloat

    init(
        model: OmabarModel,
        settings: RuntimeSettings.Omabar,
        leadingInset: CGFloat = 0,
        trailingInset: CGFloat = 0,
        onAppleClick: @escaping () -> Void
    ) {
        self.model = model
        self.settings = settings
        self.leadingInset = leadingInset
        self.trailingInset = trailingInset
        self.onAppleClick = onAppleClick
    }

    // MARK: - Themed appearance

    /// Resolved appearance: explicit settings win, otherwise the active theme's mode.
    private var isDark: Bool {
        switch settings.colorScheme {
        case "dark": return true
        case "light": return false
        default: return model.palette.isDark
        }
    }

    private var accent: Color {
        Color(red: model.palette.accent.r, green: model.palette.accent.g, blue: model.palette.accent.b)
    }

    private var textColor: Color {
        isDark ? .white : .black.opacity(0.9)
    }

    private var barHeight: CGFloat { max(24, CGFloat(settings.height)) }

    private var pillFont: Font {
        .custom("JetBrainsMono Nerd Font", size: 11.5)
    }

    private var bodyFont: Font {
        .custom("JetBrainsMono Nerd Font", size: 12)
    }

    var body: some View {
        HStack(spacing: 10) {
            // App launcher → Omanix store
            Button(action: onAppleClick) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accent)
                    .frame(width: 26, height: 26)
                    .background(barTint.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Workspace/app pills (click to refocus that app)
            ForEach(model.visibleApps.prefix(8)) { app in
                workspacePill(app)
            }

            // Chevron + focused app
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(textColor.opacity(0.5))

            HStack(spacing: 6) {
                Image(nsImage: model.frontAppIcon)
                    .resizable()
                    .frame(width: 14, height: 14)
                Text(model.frontAppName)
                    .font(bodyFont.weight(.medium))
            }
            .frame(minWidth: 0, maxWidth: nil, alignment: .leading)
            .lineLimit(1)

            Spacer(minLength: 8)

            // Right cluster
            if settings.showVolume {
                volumeItem
            }
            if settings.showWifi {
                wifiItem
            }
            if settings.showBattery {
                batteryItem
            }
            if settings.showClock {
                clockItem
            }
        }
        .font(bodyFont)
        .foregroundColor(textColor)
        .padding(.leading, 14 + leadingInset)
        .padding(.trailing, 16 + trailingInset)
        .frame(maxWidth: .infinity, minHeight: barHeight, alignment: .center)
        .background(barBackground)
        .clipShape(RoundedRectangle(cornerRadius: barCorner))
        .preferredColorScheme(isDark ? .dark : .light)
    }

    // MARK: - Pills

    private func workspacePill(_ app: OmabarModel.VisibleApp) -> some View {
        Button(action: { model.activate(app) }) {
            Text(monogram(app.name))
                .font(pillFont.weight(app.isFocused ? .bold : .medium))
                .foregroundColor(app.isFocused ? .white : textColor.opacity(0.92))
                .frame(width: 24, height: pillHeight)
                .background(app.isFocused ? accent : pillTint, in: RoundedRectangle(cornerRadius: pillCorner))
                .help(app.name)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func monogram(_ name: String) -> String {
        guard let first = name.first else { return "·" }
        return String(first).uppercased()
    }

    private var pillHeight: CGFloat { max(20, barHeight - 10) }

    private var pillCorner: CGFloat {
        settings.style == "modern" || settings.style == "glass" ? 8 : 5
    }

    // MARK: - Items

    private var clockItem: some View {
        Button(action: openCalendar) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                Text(model.timeString)
                    .font(bodyFont.weight(.semibold))
            }
            .foregroundColor(textColor)
            .contentShape(Rectangle())
            .help("Open Calendar")
        }
        .buttonStyle(.plain)
    }

    private var batteryItem: some View {
        Button {
            showStatusMenu([
                (title: batteryDetailTitle, action: {}),
                (title: "Battery Settings…", action: openBatterySettings),
            ])
        } label: {
            HStack(spacing: 5) {
                if model.charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: batteryIcon)
                        .font(.system(size: 13))
                }
                Text(model.batteryText)
                    .font(bodyFont)
            }
            .foregroundColor(textColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click for battery details")
    }

    private var batteryDetailTitle: String {
        model.charging ? "Charging — \(model.batteryText)" : "Battery — \(model.batteryText)"
    }

    private var batteryIcon: String {
        let pct = model.batteryText.replacingOccurrences(of: "%", with: "")
        guard let v = Int(pct) else { return "battery.0" }
        if v >= 100 { return "battery.100" }
        if v >= 75 { return "battery.75" }
        if v >= 50 { return "battery.50" }
        if v >= 25 { return "battery.25" }
        return "battery.0"
    }

    private var volumeItem: some View {
        Button(action: { model.toggleMute() }) {
            HStack(spacing: 5) {
                Image(systemName: model.muted ? "speaker.slash.fill" : (model.volume <= 33 ? "speaker.wave.1.fill" : (model.volume <= 66 ? "speaker.wave.2.fill" : "speaker.wave.3.fill")))
                    .font(.system(size: 12))
                Text("\(model.volume)%")
                    .font(bodyFont)
            }
            .foregroundColor(model.muted ? textColor.opacity(0.55) : textColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click to toggle mute")
        .contextMenu {
            Button("Sound Settings…", action: openSoundSettings)
        }
    }

    private var wifiItem: some View {
        Button {
            showStatusMenu([
                (title: model.wifiOn ? "Wi-Fi: On\(model.wifiName.isEmpty ? "" : " · \(model.wifiName)")" : "Wi-Fi: Off", action: {}),
                (title: model.wifiOn ? "Turn Wi-Fi Off" : "Turn Wi-Fi On", action: { model.toggleWifi() }),
                (title: "Wi-Fi Settings…", action: openWifiSettings),
            ])
        } label: {
            HStack(spacing: 5) {
                Image(systemName: model.wifiOn ? "wifi" : "wifi.slash")
                    .font(.system(size: 12))
                if model.wifiOn, !model.wifiName.isEmpty {
                    Text(model.wifiName)
                        .font(bodyFont)
                }
            }
            .foregroundColor(model.wifiOn ? textColor : textColor.opacity(0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click for Wi-Fi options")
    }

    // MARK: - Status menus

    /// Pops an NSMenu at the cursor. The target lives until `popUp` returns, so a
    /// locally-retained object is safe here.
    private func showStatusMenu(_ items: [(title: String, action: () -> Void)]) {
        let target = StatusMenuTarget()
        let menu = target.makeMenu(items)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: - System deep links

    private func openCalendar() {
        NSWorkspace.shared.open(URL(string: "ical://")!)
    }

    private func openWifiSettings() {
        openSystemSettingsPane("com.apple.settings.Wi-Fi")
    }

    private func openBatterySettings() {
        openSystemSettingsPane("com.apple.settings.Battery")
    }

    private func openSoundSettings() {
        openSystemSettingsPane("com.apple.settings.Sound")
    }

    private func openSystemSettingsPane(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Background

    private var barTint: Color {
        textColor.opacity(0.12)
    }

    private var pillTint: Color {
        if settings.style == "minimal" { return Color.clear }
        return isDark ? Color.white.opacity(0.16) : Color.black.opacity(0.10)
    }

    /// Theme-tinted bar fill. Follows the palette's background so the bar always
    /// matches the active theme (dark themes → tinted black, light → tinted white).
    private var barFill: Color {
        let base = Color(red: model.palette.background.r, green: model.palette.background.g, blue: model.palette.background.b)
        let alpha: Double = settings.transparent ? (isDark ? 0.30 : 0.40) : (isDark ? 0.82 : 0.88)
        return base.opacity(alpha)
    }

    @ViewBuilder
    private var barBackground: some View {
        switch settings.style {
        case "glass":
            RoundedRectangle(cornerRadius: 13).fill(.ultraThinMaterial)
        case "minimal":
            Color.clear
        default:
            ZStack {
                RoundedRectangle(cornerRadius: 0).fill(barFill)
                if settings.blur {
                    RoundedRectangle(cornerRadius: 0).fill(.ultraThinMaterial).opacity(0.55)
                }
            }
        }
    }

    private var barCorner: CGFloat { settings.style == "glass" ? 13 : 0 }
}

// MARK: - NSMenu helper

/// Tiny NSMenu target that maps tag → closure. Retained while `popUp` runs.
private final class StatusMenuTarget: NSObject {
    private var actions: [Int: () -> Void] = [:]

    func makeMenu(_ items: [(title: String, action: () -> Void)]) -> NSMenu {
        let menu = NSMenu()
        actions = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($0.offset, $0.element.action) })
        for (index, item) in items.enumerated() {
            let menuItem = NSMenuItem(title: item.title, action: #selector(fire(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.tag = index
            menu.addItem(menuItem)
        }
        if !items.isEmpty { menu.addItem(.separator()) }
        return menu
    }

    @objc private func fire(_ sender: NSMenuItem) {
        actions[sender.tag]?()
    }
}