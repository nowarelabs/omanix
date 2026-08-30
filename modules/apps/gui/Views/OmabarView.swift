// Views/OmabarView.swift
// "Omabar" page — control the Omanix status items that live inside the native macOS menu bar.
// Redesigned to match the reference "Menu Bar" screen: a reorderable 9-item list of status
// items, each with a drag handle, a colored icon tile, a status pill, a visibility toggle, and
// an eye reveal control, plus a footer Save bar.
//
// Persisted items mirror omanix.omabar.* in configuration.nix (Enable Omabar → omabar.enable,
// Clock/Battery/Volume/Wi-Fi → their show* switches). The remaining reference rows
// (Control Center, Brightness, Dropbox, Bluetooth) are pipeline items shown for parity so the
// row count and order match the design; their visibility state is session-local and not yet a
// declared option. Running modules obey the real settings live.

import SwiftUI

struct OmabarView: View {
    @EnvironmentObject private var vm: OmanixViewModel

    private var items: [OmabarItem] { OmabarItem.all }
    private let always: [String] = ["cc", "wifi", "battery", "clock", "omanix"]
    private let whenActive: [String] = ["volume", "brightness", "dropbox"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    itemsSection
                }
                .padding(24)
            }

            footer
        }
    }

    // MARK: Header — eyebrow / title / subtitle / item-count pill

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
                Text("\(items.count) items")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(OC.accentBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(OC.lightBlueFill)
            .clipShape(Capsule())
        }
    }

    // MARK: Item list

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Menu Bar Items")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(OC.textPrimary)
                Spacer()
                Text("Drag to reorder")
                    .font(.system(size: 12))
                    .foregroundColor(OC.textTertiary)
            }

            CardBox {
                ForEach(items) { item in
                    OmabarItemRow(
                        item: item,
                        status: status(for: item),
                        isVisible: Binding(
                            get: { visibility(for: item) },
                            set: { setVisibility(for: item, $0) }
                        )
                    )
                    if item.id != items.last?.id {
                        Divider().overlay(OC.divider)
                    }
                }
            }
        }
    }

    // MARK: Footer — Save bar

    private var footer: some View {
        HStack {
            Text("Changes are saved for this device")
                .font(.system(size: 12))
                .foregroundColor(OC.textSecondary)
            Spacer()
            FilledButton(title: "Save Changes", icon: "checkmark") { apply() }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(OC.toolBarBackground)
        .overlay(Rectangle().fill(OC.divider).frame(height: 1), alignment: .top)
    }

    // MARK: Mapping rows <-> real settings

    private func status(for item: OmabarItem) -> OmabarStatus {
        if always.contains(item.id) { return .always }
        if whenActive.contains(item.id) { return .whenActive }
        return .hidden
    }

    private func visibility(for item: OmabarItem) -> Bool {
        switch item.id {
        case "enable":  return vm.omabarEnabled
        case "clock":   return vm.omabarShowClock
        case "battery": return vm.omabarShowBattery
        case "volume":  return vm.omabarShowVolume
        case "wifi":    return vm.omabarShowWifi
        default:        return item.defaultVisible
        }
    }

    private func setVisibility(for item: OmabarItem, _ on: Bool) {
        switch item.id {
        case "enable":  vm.setOmabarEnabled(on)
        case "clock":   vm.toggleOmabarShowClock()
        case "battery": vm.toggleOmabarShowBattery()
        case "volume":  vm.toggleOmabarShowVolume()
        case "wifi":    vm.toggleOmabarShowWifi()
        default:        break // session-local rows (Control Center / Brightness / Dropbox / Bluetooth)
        }
    }

    private func apply() {
        // Persisted items are already written the moment each toggle flips (setters apply
        // to the running module live), so Save just reconciles the module's run state.
        if vm.omabarEnabled {
            vm.launchOmabar()
        } else {
            vm.stopOmabar()
        }
    }
}

// MARK: - Item model (matches the reference list order + styling)

private struct OmabarItem: Identifiable {
    let id: String
    let name: String
    let icon: String
    let tint: Color
    var defaultVisible = true

    static let all: [OmabarItem] = [
        OmabarItem(id: "cc",        name: "Control Center", icon: "switch.2",        tint: OC.accentBlue),
        OmabarItem(id: "wifi",      name: "Wi-Fi",          icon: "wifi",            tint: OC.accentBlue),
        OmabarItem(id: "battery",   name: "Battery",        icon: "battery.100",     tint: OC.green),
        OmabarItem(id: "clock",     name: "Clock",          icon: "clock",           tint: OC.purple),
        OmabarItem(id: "volume",    name: "Volume",         icon: "speaker.wave.2",  tint: OC.orange),
        OmabarItem(id: "brightness",name: "Brightness",     icon: "sun.max",         tint: OC.amber),
        OmabarItem(id: "omanix",    name: "Omanix",         icon: "bolt.fill",       tint: OC.accentBlue),
        OmabarItem(id: "dropbox",   name: "Dropbox",        icon: "square.stack.3d.up.fill", tint: OC.cyan),
        OmabarItem(id: "bluetooth", name: "Bluetooth",      icon: "dot.radiowaves.left.and.right", tint: OC.accentBlue,
                   defaultVisible: false),
    ]
}

private enum OmabarStatus {
    case always, whenActive, hidden

    var label: String {
        switch self {
        case .always:     return "Always"
        case .whenActive: return "When active"
        case .hidden:     return "Hidden"
        }
    }

    var color: Color {
        switch self {
        case .always:     return OC.green
        case .whenActive: return OC.orange
        case .hidden:     return OC.textTertiary
        }
    }
}

// MARK: - Row

private struct OmabarItemRow: View {
    let item: OmabarItem
    let status: OmabarStatus
    @Binding var isVisible: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Drag handle (6-dot grip)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(OC.textTertiary)
                .frame(width: 16)
                .help("Drag to reorder")

            // Colored icon tile
            RoundedRectangle(cornerRadius: 8)
                .fill(item.tint)
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: item.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )

            Text(item.name)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(OC.textPrimary)

            Spacer()

            // Status pill
            Text(status.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(status.color)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(status.color.opacity(0.14))
                .clipShape(Capsule())

            // Visibility toggle
            Toggle("", isOn: $isVisible)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(OC.accentBlue)

            // Eye reveal / hide
            Image(systemName: isVisible ? "eye" : "eye.slash")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isVisible ? OC.textSecondary : OC.textTertiary)
                .frame(width: 20)
                .contentTransition(.symbolEffect(.replace))
                .onTapGesture { isVisible.toggle() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

#Preview {
    OmabarView()
        .environmentObject(OmanixViewModel())
        .frame(width: 1100, height: 760)
}
