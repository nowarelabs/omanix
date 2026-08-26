// modules/apps/store/Sources/StatusBarView.swift
// Omanix — reusable status bar with error/success/idle states and rebuild button
import SwiftUI

struct StatusBarView<Trailing: View>: View {
    @ObservedObject var store: StoreViewModel
    let idleText: String
    @ViewBuilder var trailingContent: () -> Trailing

    @Environment(\.omanixTheme) var theme

    init(
        store: StoreViewModel,
        idleText: String,
        @ViewBuilder trailingContent: @escaping () -> Trailing
    ) {
        self.store = store
        self.idleText = idleText
        self.trailingContent = trailingContent
    }

    var body: some View {
        HStack(spacing: 8) {
            if store.isIndexingBrew {
                ProgressView()
                    .controlSize(.mini)
                Text("Indexing Homebrew...")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)
            } else if let error = store.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(theme.error)
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(theme.error)
                    .lineLimit(1)
            } else if let success = store.successMessage {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(theme.success)
                Text(success)
                    .font(.system(size: 11))
                    .foregroundColor(theme.success)
            } else {
                Circle()
                    .fill(theme.tertiaryText.opacity(0.3))
                    .frame(width: 4, height: 4)
                Text(idleText)
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)
            }

            Spacer()

            trailingContent()

            Button(action: { Task { await store.rebuild() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                    Text("Rebuild")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(theme.accent)
                .cornerRadius(UIConstants.cornerRow)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.surface)
        .overlay(alignment: .top) {
            Divider().background(theme.divider)
        }
    }
}

// Convenience: no trailing content
struct StatusBarViewSimple: View {
    @ObservedObject var store: StoreViewModel
    let idleText: String

    @Environment(\.omanixTheme) var theme

    var body: some View {
        StatusBarView(store: store, idleText: idleText) {
            EmptyView()
        }
    }
}
