// modules/apps/store/Sources/WidgetGalleryView.swift
// Omanix — widget management gallery
import SwiftUI

struct WidgetGalleryView: View {
    @ObservedObject var store: StoreViewModel
    @Environment(\.omanixTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            header
            if store.widgets.isEmpty {
                emptyState
            } else {
                content
            }
            StatusBarView(store: store, idleText: "Toggle widgets, then rebuild") { EmptyView() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Widgets")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.text)
                Text("\(store.widgets.filter(\.isEnabled).count) of \(store.widgets.count) enabled")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background(theme.background)
        .overlay(alignment: .bottom) {
            Divider().background(theme.divider)
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 12)
            ], spacing: 12) {
                ForEach(store.widgets) { widget in
                    WidgetCard(widget: widget, store: store)
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "rectangle.stack")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(theme.tertiaryText.opacity(0.4))
            VStack(spacing: 4) {
                Text("No widgets available")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(theme.text)
                Text("Widgets will appear here once configured")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)
            }
            Spacer()
        }
    }
}

// MARK: - Widget Card

struct WidgetCard: View {
    let widget: WidgetItem
    @ObservedObject var store: StoreViewModel
    @Environment(\.omanixTheme) var theme
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: UIConstants.cornerInput)
                        .fill(widget.isEnabled ? theme.accent.opacity(0.1) : Color.white.opacity(0.04))
                        .frame(width: 36, height: 36)
                    Image(systemName: widget.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(widget.isEnabled ? theme.accent : theme.tertiaryText)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { widget.isEnabled },
                    set: { _ in Task { await store.toggleWidget(widget) } }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(theme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(widget.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.text)
                Text(widgetDescription)
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(widget.isEnabled ? theme.success : theme.tertiaryText.opacity(0.3))
                    .frame(width: 5, height: 5)
                Text(widget.isEnabled ? "Active" : "Inactive")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(widget.isEnabled ? theme.success : theme.tertiaryText)
            }
        }
        .padding(14)
        .background(theme.surface)
        .cornerRadius(UIConstants.cornerCard)
        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: UIConstants.cornerCard)
                .stroke(
                    widget.isEnabled
                        ? theme.accent.opacity(isHovered ? 0.4 : 0.2)
                        : (isHovered ? theme.border : .clear),
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var widgetDescription: String {
        switch widget.id {
        case "store":
            return "Browse and install packages from nixpkgs and Homebrew"
        case "pomodoro":
            return "Focused work sessions with break reminders"
        case "clock":
            return "Minimalist clock with timezone support"
        default:
            return "Omanix widget"
        }
    }
}

#Preview {
    WidgetGalleryView(store: StoreViewModel())
}
