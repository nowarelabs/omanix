// modules/apps/store/Sources/WidgetGalleryView.swift
// Omanix — widget management gallery
import SwiftUI

struct WidgetGalleryView: View {
    @ObservedObject var store: StoreViewModel
    @Environment(\.omanixTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Widget Gallery")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.text)
                    Text("Enable or disable Omanix widgets")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
            }
            .padding()

            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 200, maximum: 300))
                ], spacing: 16) {
                    ForEach(store.widgets) { widget in
                        WidgetCard(widget: widget, store: store)
                    }
                }
                .padding()
            }
            .background(theme.background)

            HStack {
                if let error = store.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                } else if let success = store.successMessage {
                    Label(success, systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Text("\(store.widgets.filter(\.isEnabled).count) of \(store.widgets.count) widgets enabled")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
                Button("Rebuild System") {
                    Task { await store.rebuild() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(theme.accent)
            }
            .padding()
            .background(theme.surface)
        }
    }
}

struct WidgetCard: View {
    let widget: WidgetItem
    @ObservedObject var store: StoreViewModel
    @Environment(\.omanixTheme) var theme

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: widget.icon)
                    .font(.title2)
                    .foregroundColor(widget.isEnabled ? theme.accent : theme.secondaryText)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { widget.isEnabled },
                    set: { _ in Task { await store.toggleWidget(widget) } }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(theme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(widget.name)
                    .font(.headline)
                    .foregroundColor(theme.text)
                Text(widgetDescription)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(theme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(widget.isEnabled ? theme.accent.opacity(0.3) : .clear, lineWidth: 1)
        )
    }

    var widgetDescription: String {
        switch widget.id {
        case "store":
            return "Browse and install packages from nixpkgs and Homebrew"
        case "pomodoro":
            return "Pomodoro timer with break reminders"
        case "clock":
            return "World clock with multiple timezones"
        default:
            return "Omanix widget"
        }
    }
}

#Preview {
    WidgetGalleryView(store: StoreViewModel())
}
