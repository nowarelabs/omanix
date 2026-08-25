// modules/apps/store/Sources/WidgetGalleryView.swift
// Omanix — widget management gallery
import SwiftUI

struct WidgetGalleryView: View {
    @ObservedObject var store: StoreViewModel
    @Environment(\.omanixTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            header
            content
            statusBar
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Widget Gallery")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(theme.text)
                Text("\(store.widgets.filter(\.isEnabled).count) of \(store.widgets.count) enabled")
                    .font(.caption)
                    .foregroundColor(theme.tertiaryText)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 14)
            ], spacing: 14) {
                ForEach(store.widgets) { widget in
                    WidgetCard(widget: widget, store: store)
                }
            }
            .padding(20)
        }
        .background(theme.background)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            if let error = store.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(theme.error)
                Text(error)
                    .font(.caption)
                    .foregroundColor(theme.error)
                    .lineLimit(1)
            } else if let success = store.successMessage {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(theme.success)
                Text(success)
                    .font(.caption)
                    .foregroundColor(theme.success)
            } else {
                Circle()
                    .fill(theme.tertiaryText.opacity(0.4))
                    .frame(width: 4, height: 4)
                Text("Toggle widgets on or off, then rebuild")
                    .font(.caption)
                    .foregroundColor(theme.tertiaryText)
            }

            Spacer()

            Button(action: { Task { await store.rebuild() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                    Text("Rebuild")
                }
                .font(.system(.caption, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(theme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.surface)
        .overlay(alignment: .top) {
            Divider().background(theme.border)
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
        VStack(alignment: .leading, spacing: 14) {
            // Top: icon + toggle
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(widget.isEnabled ? theme.accent.opacity(0.12) : theme.tertiarySurface)
                        .frame(width: 40, height: 40)
                    Image(systemName: widget.icon)
                        .font(.system(size: 18, weight: .semibold))
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

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(widget.name)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundColor(theme.text)
                Text(widgetDescription)
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Status pill
            HStack(spacing: 4) {
                Circle()
                    .fill(widget.isEnabled ? theme.success : theme.tertiaryText.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text(widget.isEnabled ? "Active" : "Inactive")
                    .font(.system(.caption2, weight: .medium))
                    .foregroundColor(widget.isEnabled ? theme.success : theme.tertiaryText)
            }
        }
        .padding(16)
        .background(theme.surface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    widget.isEnabled
                        ? theme.accent.opacity(isHovered ? 0.5 : 0.25)
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
            return "Browse and install packages from nixpkgs and Homebrew right from your menu bar"
        case "pomodoro":
            return "Focused work sessions with customizable break reminders in your menu bar"
        case "clock":
            return "Minimalist clock widget with multiple timezone support in your menu bar"
        default:
            return "Omanix widget"
        }
    }
}

#Preview {
    WidgetGalleryView(store: StoreViewModel())
}
