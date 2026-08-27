// Components.swift
// Reusable pieces shared across screens: page header, pills, toolbar, status bar.

import SwiftUI

// MARK: - Page header (breadcrumb / title / subtitle), with optional trailing accessory

struct PageHeader<Accessory: View>: View {
    let breadcrumb: String
    let title: String
    let subtitle: String
    @ViewBuilder var accessory: () -> Accessory

    init(breadcrumb: String, title: String, subtitle: String, @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.breadcrumb = breadcrumb
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(breadcrumb.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(OC.textTertiary)
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(OC.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(OC.textSecondary)
            }
            Spacer()
            accessory()
        }
    }
}

// MARK: - Bordered button (used for Refresh / Manage / Save changes)

struct BorderedButton: View {
    let title: String
    let icon: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(OC.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(OC.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Primary filled button (blue), used for Install / Rebuild

struct FilledButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                }
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(OC.accentBlue)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

/// A lighter "link style" pill install button, used in list rows.
struct SoftFilledButton: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(OC.accentBlue)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(OC.lightBlueFill)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter pill (All / Developer / Productivity / Utilities)

struct FilterPill: View {
    let title: String
    let selected: Bool
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(selected ? .white : OC.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selected ? OC.accentBlue : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: OMetrics.pillCorner)
                        .stroke(selected ? Color.clear : OC.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: OMetrics.pillCorner))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Icon square (colored rounded-rect app icon)

struct IconSquare: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Bottom status bar

struct StatusBar: View {
    let left: String
    var rightText: String? = nil
    var rightDotColor: Color? = nil
    var trailingView: AnyView? = nil

    var body: some View {
        HStack {
            Text(left)
                .font(.system(size: 12))
                .foregroundColor(OC.textSecondary)
            Spacer()
            if let trailingView {
                trailingView
            } else if let rightText {
                HStack(spacing: 6) {
                    if let rightDotColor {
                        Circle().fill(rightDotColor).frame(width: 6, height: 6)
                    }
                    Text(rightText)
                        .font(.system(size: 12))
                        .foregroundColor(OC.textSecondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(OC.toolBarBackground)
        .overlay(Rectangle().fill(OC.divider).frame(height: 1), alignment: .top)
    }
}

// MARK: - Top title bar + toolbar row (shared by every screen)

struct TopChrome: View {
    @Binding var sidebarVisible: Bool
    @Binding var searchText: String

    var body: some View {
        VStack(spacing: 0) {
            // Title bar row
            HStack {
                Button(action: { withAnimation(.easeInOut(duration: 0.18)) { sidebarVisible.toggle() } }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(OC.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 20)

                Spacer()
                Text("Omanix")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(OC.textPrimary)
                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(OC.textTertiary)
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(OC.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(width: 260)
                .background(OC.subtleFill)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.trailing, 20)
            }
            .frame(height: 52)
            .background(OC.titleBarBackground)

            Divider().overlay(OC.divider)

            // Secondary toolbar row (View / Group / Share / Action / Search)
            HStack(spacing: 28) {
                Spacer()
                ToolbarIcon(icon: "square.grid.2x2", label: "View", selected: true)
                ToolbarIcon(icon: "slider.horizontal.3", label: "Group", selected: false)
                ToolbarIcon(icon: "square.and.arrow.up", label: "Share", selected: false)
                ToolbarIcon(icon: "ellipsis", label: "Action", selected: false)
                ToolbarIcon(icon: "magnifyingglass", label: "Search", selected: false)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(OC.toolBarBackground)

            Divider().overlay(OC.divider)
        }
    }
}

struct ToolbarIcon: View {
    let icon: String
    let label: String
    let selected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 15))
            Text(label)
                .font(.system(size: 10))
        }
        .foregroundColor(selected ? OC.textPrimary : OC.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(selected ? OC.subtleFill : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
