// modules/apps/store/Sources/WidgetGalleryView.swift
// Omanix Store — widget management gallery
import SwiftUI

struct WidgetGalleryView: View {
    @ObservedObject var store: StoreViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Widget Gallery")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Enable or disable Omanix widgets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()

            // Widget grid
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

            // Status bar
            HStack {
                if let error = store.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                } else if let success = store.successMessage {
                    Label(success, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Text("\(store.widgets.filter(\.isEnabled).count) of \(store.widgets.count) widgets enabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Rebuild System") {
                    Task { await store.rebuild() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(.bar)
        }
    }
}

struct WidgetCard: View {
    let widget: WidgetItem
    @ObservedObject var store: StoreViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: widget.icon)
                    .font(.title2)
                    .foregroundStyle(widget.isEnabled ? .accentColor : .secondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { widget.isEnabled },
                    set: { _ in Task { await store.toggleWidget(widget) } }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(widget.name)
                    .font(.headline)
                Text(widgetDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(widget.isEnabled ? Color.accentColor.opacity(0.3) : .clear, lineWidth: 1)
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
