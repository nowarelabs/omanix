// Views/WidgetsView.swift
// "Widgets" page: real widget toggles that edit configuration.nix via the VM.

import SwiftUI

struct WidgetsView: View {
    @EnvironmentObject private var vm: OmanixViewModel

    private let columns = [GridItem(.adaptive(minimum: 260, maximum: 300), spacing: 20)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    breadcrumb: "Library / System",
                    title: "Widgets",
                    subtitle: "Small utilities for your desktop, ready when you are."
                ) {
                    if vm.needsRebuild {
                        FilledButton(title: "Rebuild", icon: "wrench.and.screwdriver.fill") {
                            vm.rebuild()
                        }
                    } else {
                        BorderedButton(title: "Manage", icon: "gearshape")
                    }
                }

                if vm.widgets.isEmpty {
                    emptyList
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                        ForEach(vm.widgets) { widget in
                            WidgetCard(
                                widget: widget,
                                enabled: Binding(
                                    get: { widget.isEnabled },
                                    set: { _ in vm.toggleWidget(widget) }
                                )
                            )
                        }
                    }
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            let enabledCount = vm.widgets.filter(\.isEnabled).count
            StatusBar(left: "\(enabledCount) of \(vm.widgets.count) widgets enabled", rightText: "Omanix System Library")
        }
    }

    private var emptyList: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            Image(systemName: "rectangle.stack")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(OC.textTertiary)
            Text("No widgets available")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(OC.textPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WidgetCard: View {
    let widget: WidgetItem
    @Binding var enabled: Bool

    private var accent: Color {
        switch widget.id {
        case "pomodoro": return OC.red
        case "clock": return OC.orange
        case "omabar": return OC.purple
        case "omatiles": return OC.cyan
        default: return OC.accentBlue
        }
    }

    private var description: String {
        switch widget.id {
        case "store": return "Browse and install packages with the Omanix store."
        case "omabar": return "Native SwiftUI menu bar — right on your screen edge."
        case "omatiles": return "Native window tiling built into Omanix."
        case "pomodoro": return "Focused work sessions with break reminders."
        case "clock": return "A quiet glance at the local time."
        default: return "Omanix widget"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                accent

                VStack {
                    HStack {
                        Text("OMANIX WIDGET")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(.white.opacity(0.85))
                        Spacer()
                        Image(systemName: widget.icon)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                }
                .padding(14)

                Image(systemName: widget.icon)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
                    .padding(14)
            }
            .frame(height: 130)

            HStack(alignment: .top, spacing: 12) {
                IconSquare(systemName: widget.icon, color: accent, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(widget.name).font(.system(size: 14, weight: .bold)).foregroundColor(OC.textPrimary)
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(OC.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Toggle("", isOn: $enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(OC.green)
            }
            .padding(14)
        }
        .background(OC.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: OMetrics.cardCorner).stroke(OC.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: OMetrics.cardCorner))
    }
}
