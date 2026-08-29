// Views/ContentView.swift
// App shell: sidebar + title/toolbar chrome + the selected page.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var vm: OmanixViewModel
    @State private var selection: SidebarItem = .browse
    @State private var sidebarVisible = true

    var body: some View {
        VStack(spacing: 0) {
            TopChrome(sidebarVisible: $sidebarVisible, searchText: $vm.searchQuery)

            HStack(spacing: 0) {
                if sidebarVisible {
                    SidebarView(
                        selection: $selection,
                        installedCount: vm.installedCount
                    )
                    Divider().overlay(OC.divider)
                }

                Group {
                    switch selection {
                    case .browse:
                        BrowseView()
                    case .installed:
                        InstalledView()
                    case .widgets:
                        WidgetsView()
                    case .omatiles:
                        OmatilesView()
                    case .omabar:
                        OmabarView()
                    case .themes:
                        ThemesView()
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(OC.pageBackground)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if let message = vm.message, let kind = vm.messageKind {
                MessageBanner(message: message, kind: kind, onDismiss: { vm.message = nil })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 12)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.message)
    }
}

// MARK: - Message banner (top-toast equivalent)

struct MessageBanner: View {
    let message: String
    let kind: OmanixViewModel.MessageKind
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: kind == .success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 360)
        .background(kind == .success ? OC.green : OC.red)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    ContentView()
        .environmentObject(OmanixViewModel())
        .frame(width: 1280, height: 840)
}
