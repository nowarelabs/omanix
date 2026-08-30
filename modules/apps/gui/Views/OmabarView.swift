// Views/OmabarView.swift
// "Omabar" page — control the Omanix menu bar (status) plugins.
// Your plugins are listed in a drag-to-reorder list; toggling a row shows/hides it
// in the macOS menu bar instantly. Any plugin that needs a macOS permission is
// surfaced in the Permissions section below with a one-click grant.
//
// This page is 100% plugin-driven: it reads PluginRegistry + PluginStore through the
// view model and never names a specific plugin. Add a plugin to the registry and it
// shows up here, in the menu bar, and in the permission list automatically.

import SwiftUI

struct OmabarView: View {
    @EnvironmentObject private var vm: OmanixViewModel
    @State private var draggingID: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    clockMenubarSection

                    itemsSection

                    permissionsSection
                }
                .padding(24)
            }

            footer
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SYSTEM UTILITY")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(OC.textTertiary)
                Text("Menu Bar")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(OC.textPrimary)
                Text("Customize icon order and visibility")
                    .font(.system(size: 13))
                    .foregroundColor(OC.textSecondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 11, weight: .semibold))
                Text("\(vm.pluginItems.count) items")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(OC.accentBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(OC.lightBlueFill)
            .clipShape(Capsule())
        }
    }

    // MARK: Clock & Menubar (General toggles + Clock Format)

    private var clockMenubarSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                Text("General")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(OC.textPrimary)

                VStack(spacing: 0) {
                    PrefToggleRow(
                        title: "Auto-hide menu bar",
                        description: "Reveal the menu bar when you move the pointer to the top",
                        icon: "menubar.rectangle",
                        isOn: Binding(get: { vm.mbAutoHide }, set: { vm.setMBAutoHide($0) })
                    )
                    divider
                    PrefToggleRow(
                        title: "Show date next to time",
                        description: "Display the abbreviated date in the menu bar",
                        icon: "calendar",
                        isOn: Binding(get: { vm.mbShowDate }, set: { vm.setMBShowDate($0) })
                    )
                    divider
                    PrefToggleRow(
                        title: "Show battery percentage",
                        description: "Keep the current charge visible beside the battery icon",
                        icon: "battery.75percent",
                        isOn: Binding(get: { vm.mbShowBatteryPercent }, set: { vm.setMBShowBatteryPercent($0) })
                    )
                    divider
                    PrefToggleRow(
                        title: "Use 24-hour time",
                        description: "Display time using a 24-hour clock",
                        icon: "clock",
                        isOn: Binding(get: { vm.mbUse24Hour }, set: { vm.setMBUse24Hour($0) })
                    )
                }
                .background(OC.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: OMetrics.cardCorner).stroke(OC.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: OMetrics.cardCorner))
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Clock Format")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(OC.textPrimary)
                    Spacer()
                    Text("Choose how the time appears in your menu bar")
                        .font(.system(size: 12))
                        .foregroundColor(OC.textTertiary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        FormatTile(
                            kind: "digital",
                            title: "Digital",
                            icon: "digital",
                            mono: true,
                            selected: vm.mbClockFormat == "digital"
                        ) { vm.setMBClockFormat("digital") }

                        FormatTile(
                            kind: "analog",
                            title: "Analog",
                            icon: "clock",
                            mono: false,
                            selected: vm.mbClockFormat == "analog"
                        ) { vm.setMBClockFormat("analog") }
                    }

                    samplePreview
                }
                .padding(16)
                .background(OC.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: OMetrics.cardCorner).stroke(OC.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: OMetrics.cardCorner))
            }
        }
    }

    /// Live sample that mirrors what the Clock plugin will show.
    private var samplePreview: some View {
        let time = sampleTimeText()
        return HStack(spacing: 10) {
            Image(systemName: vm.mbClockFormat == "analog" ? "clock" : "digital")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(OC.accentBlue)
            Text(time)
                .font(OFont.mono(14, weight: .semibold))
                .foregroundColor(OC.textPrimary)
            Text(sampleDateText())
                .font(.system(size: 13))
                .foregroundColor(OC.textSecondary)
            Spacer()
            Text(vm.mbClockFormat == "analog" ? "Analog" : "Digital")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(OC.textTertiary)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(OC.subtleFill)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(OC.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func sampleTimeText() -> String {
        // Use a stable reference time ("9:41" classic Apple screen) so the preview
        // reads cleanly regardless of the actual wall clock.
        let base = DateComponents(hour: 9, minute: 41).date ?? Date()
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        if vm.mbClockFormat == "analog" { return "9:41" }
        f.dateFormat = vm.mbUse24Hour ? "HH:mm" : "h:mm a"
        return f.string(from: base)
    }

    private func sampleDateText() -> String {
        // "Saturday" sample consistent with the design reference.
        "Saturday"
    }

    private var divider: some View {
        Divider().overlay(OC.divider)
    }

    // MARK: Items (drag to reorder)

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Menu Bar Items")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(OC.textPrimary)
                Spacer()
                Text("Drag to reorder")
                    .font(.system(size: 12))
                    .foregroundColor(OC.textTertiary)
            }

            VStack(spacing: 0) {
                ForEach(Array(vm.pluginItems.enumerated()), id: \.element.id) { index, item in
                    PluginRow(
                        item: item,
                        isDragging: draggingID == item.id,
                        onToggle: { vm.togglePlugin(item) }
                    )
                    .onDrag {
                        draggingID = item.id
                        return NSItemProvider(object: item.id as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: PluginDropDelegate(
                            itemID: item.id,
                            targetIndex: index,
                            items: vm.pluginItems.map(\.id),
                            draggingID: $draggingID,
                            onMove: { from, to in vm.movePlugin(from, to: to) }
                        )
                    )
                    if index < vm.pluginItems.count - 1 {
                        Divider().overlay(OC.divider)
                    }
                }
            }
            .background(OC.cardBackground)
            .overlay(RoundedRectangle(cornerRadius: OMetrics.cardCorner).stroke(OC.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: OMetrics.cardCorner))
        }
    }

    // MARK: Drag & drop reorder delegate

    private struct PluginDropDelegate: DropDelegate {
        let itemID: String
        let targetIndex: Int
        let items: [String]
        @Binding var draggingID: String?
        let onMove: (String, Int) -> Void

        func dropEntered(info: DropInfo) {
            guard let dragging = draggingID, dragging != itemID,
                  let from = items.firstIndex(of: dragging) else { return }
            // Move the dragged plugin to the target's index (adjusting for removal).
            var result = items
            result.remove(at: from)
            let dest = items.firstIndex(of: itemID) ?? targetIndex
            let clamped = min(max(0, dest), result.count)
            onMove(dragging, clamped)
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
        }

        func performDrop(info: DropInfo) -> Bool {
            draggingID = nil
            return true
        }

        func dropExited(info: DropInfo) {
            draggingID = nil
        }
    }

    // MARK: Permissions

    private var permissionsSection: some View {
        let needed = enabledPermissions
        return Group {
            if !needed.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Permissions")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(OC.textPrimary)
                    VStack(spacing: 0) {
                        ForEach(Array(needed.enumerated()), id: \.element) { index, permission in
                            PermissionRow(permission: permission) {
                                vm.grant(permission)
                            }
                            if index < needed.count - 1 {
                                Divider().overlay(OC.divider)
                            }
                        }
                    }
                    .background(OC.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: OMetrics.cardCorner).stroke(OC.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: OMetrics.cardCorner))
                }
            }
        }
    }

    /// Distinct permissions required by the enabled plugins, in a stable order.
    private var enabledPermissions: [OmanixPermission] {
        var seen = Set<OmanixPermission>()
        var result: [OmanixPermission] = []
        for item in vm.pluginItems where item.isEnabled {
            for p in item.permissions where !seen.contains(p) {
                seen.insert(p)
                result.append(p)
            }
        }
        return result
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Text("Changes are applied live to the menu bar")
                .font(.system(size: 12))
                .foregroundColor(OC.textSecondary)
            Spacer()
            FilledButton(title: "Save Changes", icon: "checkmark") {
                vm.applyOmabarFromPlugins()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(OC.toolBarBackground)
        .overlay(Rectangle().fill(OC.divider).frame(height: 1), alignment: .top)
    }
}

// MARK: - Plugin row

private struct PluginRow: View {
    let item: PluginItem
    let isDragging: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Drag/ordering handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(OC.textTertiary)
                .frame(width: 18)
                .help("Drag to reorder")

            // Icon tile
            RoundedRectangle(cornerRadius: 8)
                .fill(item.tint)
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: item.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(OC.textPrimary)
                Text(item.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundColor(OC.textTertiary)
            }

            Spacer()

            // Permission indication (small dot if this plugin needs a permission)
            if !item.permissions.isEmpty {
                Image(systemName: "lock.shield")
                    .font(.system(size: 12))
                    .foregroundColor(OC.textTertiary)
                    .help(item.permissions.map(\.title).joined(separator: ", "))
            }

            Toggle("", isOn: Binding(get: { item.isEnabled }, set: { _ in onToggle() }))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(OC.accentBlue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isDragging ? OC.subtleFill : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isDragging ? OC.accentBlue : Color.clear, lineWidth: isDragging ? 1 : 0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Permission row

private struct PermissionRow: View {
    let permission: OmanixPermission
    let grant: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8)
                .fill(permission.granted ? OC.green : OC.orange)
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: permission.granted ? "checkmark" : "lock")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(OC.textPrimary)
                Text(permission.explanation)
                    .font(.system(size: 11.5))
                    .foregroundColor(OC.textTertiary)
            }

            Spacer()

            Text(permission.granted ? "Granted" : "Not granted")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(permission.granted ? OC.green : OC.orange)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background((permission.granted ? OC.green : OC.orange).opacity(0.14))
                .clipShape(Capsule())

            if !permission.granted {
                FilledButton(title: "Grant", icon: "lock.open") { grant() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Preference toggle row

private struct PrefToggleRow: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8)
                .fill(OC.accentBlue.opacity(0.12))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(OC.accentBlue)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(OC.textPrimary)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(OC.textSecondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(OC.accentBlue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Clock format tile

private struct FormatTile: View {
    let kind: String
    let title: String
    let icon: String
    let mono: Bool
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if mono {
                    Text("9:41")
                        .font(OFont.mono(15, weight: .semibold))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(selected ? Color.white : OC.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selected ? OC.accentBlue : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? OC.accentBlue : OC.border, lineWidth: selected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OmabarView()
        .environmentObject(OmanixViewModel())
        .frame(width: 1100, height: 760)
}
