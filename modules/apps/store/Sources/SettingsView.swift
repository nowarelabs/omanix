// modules/apps/store/Sources/SettingsView.swift
// Omanix — system settings
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: StoreViewModel
    @Environment(\.omanixTheme) var theme
    @State private var hostName = ""
    @State private var userName = ""
    @State private var autoRebuild = true
    @State private var showAdvanced = false

    var body: some View {
        VStack(spacing: 0) {
            header
            content
            statusBar
        }
        .onAppear { loadSettings() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(theme.text)
                Text("Configure your Omanix system")
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
            VStack(spacing: 16) {
                systemSection
                actionsSection
                advancedSection
            }
            .padding(20)
        }
        .background(theme.background)
    }

    // MARK: - System Section

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("System", icon: "desktopcomputer")

            VStack(spacing: 0) {
                settingRow(
                    label: "Hostname",
                    value: hostName,
                    icon: "server.rack"
                )
                Divider().background(theme.border).padding(.leading, 36)
                settingRow(
                    label: "Username",
                    value: userName,
                    icon: "person"
                )
                Divider().background(theme.border).padding(.leading, 36)
                settingRow(
                    label: "Version",
                    value: "0.1.0",
                    icon: "tag"
                )
                Divider().background(theme.border).padding(.leading, 36)
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12))
                        .foregroundColor(theme.tertiaryText)
                        .frame(width: 24)
                    Text("Auto-rebuild after changes")
                        .font(.system(.body))
                        .foregroundColor(theme.text)
                    Spacer()
                    Toggle("", isOn: $autoRebuild)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(theme.accent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(theme.surface)
            .cornerRadius(10)
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Actions", icon: "bolt")

            VStack(spacing: 0) {
                actionRow(
                    title: "Rebuild System",
                    subtitle: "Apply all configuration changes",
                    icon: "arrow.triangle.2.circlepath",
                    color: theme.accent
                ) {
                    Task { await store.rebuild() }
                }
                Divider().background(theme.border).padding(.leading, 36)
                actionRow(
                    title: "Rollback",
                    subtitle: "Revert to the previous generation",
                    icon: "arrow.uturn.backward",
                    color: theme.warning
                ) {
                    rollback()
                }
                Divider().background(theme.border).padding(.leading, 36)
                actionRow(
                    title: "Update Flake Inputs",
                    subtitle: "Pull latest nixpkgs and rebuild",
                    icon: "arrow.down.circle",
                    color: theme.accent
                ) {
                    updateFlake()
                }
            }
            .background(theme.surface)
            .cornerRadius(10)
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Advanced", icon: "wrench.and.screwdriver")

            VStack(spacing: 0) {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showAdvanced.toggle() } }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 12))
                            .foregroundColor(theme.warning)
                            .frame(width: 24)
                        Text("Danger Zone")
                            .font(.system(.body, weight: .medium))
                            .foregroundColor(theme.warning)
                        Spacer()
                        Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(theme.tertiaryText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if showAdvanced {
                    Divider().background(theme.border).padding(.leading, 36)

                    actionRow(
                        title: "Reset Configuration",
                        subtitle: "Restore configuration.nix to defaults",
                        icon: "arrow.counterclockwise",
                        color: theme.error
                    ) {
                        resetConfig()
                    }

                    Divider().background(theme.border).padding(.leading, 36)

                    actionRow(
                        title: "Uninstall Omanix",
                        subtitle: "Remove Omanix app and login item",
                        icon: "trash",
                        color: theme.error
                    ) {
                        uninstallOmanix()
                    }
                }
            }
            .background(theme.surface)
            .cornerRadius(10)
        }
    }

    // MARK: - Reusable Components

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.accent)
            Text(title)
                .font(.system(.caption, weight: .semibold))
                .foregroundColor(theme.secondaryText)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    private func settingRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(theme.tertiaryText)
                .frame(width: 24)
            Text(label)
                .font(.system(.body))
                .foregroundColor(theme.text)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(theme.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func actionRow(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(.body, weight: .medium))
                        .foregroundColor(theme.text)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(theme.tertiaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
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
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.surface)
        .overlay(alignment: .top) {
            Divider().background(theme.border)
        }
    }

    // MARK: - Helpers

    private func loadSettings() {
        userName = NSUserName()
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/omanix/configuration.nix").path
        if let config = try? String(contentsOfFile: configPath, encoding: .utf8) {
            if let range = config.range(of: "omanix.host = \"") {
                let start = range.upperBound
                if let end = config[start...].range(of: "\"") {
                    hostName = String(config[start..<end.lowerBound])
                }
            }
        }
        if hostName.isEmpty {
            hostName = ProcessInfo.processInfo.hostName
        }
    }

    private func rollback() {
        Task { await store.rollback() }
    }

    private func updateFlake() {
        Task { await store.updateFlake() }
    }

    private func resetConfig() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/omanix/configuration.nix").path
        let backupPath = configPath + ".backup"
        try? FileManager.default.copyItem(atPath: configPath, toPath: backupPath)

        let defaultConfig = """
        { config, pkgs, ... }: {
          omanix.host = "my-mac";
          omanix.user = "\(NSUserName())";
          omanix.theme = "tokyo-night";
          omanix.bar.top = true;
          omanix.widgets.store.enable = true;
        }
        """

        do {
            try defaultConfig.write(toFile: configPath, atomically: true, encoding: .utf8)
            store.successMessage = "Configuration reset. Backup saved to configuration.nix.backup"
        } catch {
            store.errorMessage = "Failed to reset configuration: \(error.localizedDescription)"
        }
    }

    private func uninstallOmanix() {
        _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/osascript"), arguments: [
            "-e", "tell application \"System Events\" to delete login item \"Omanix\""
        ])
        try? FileManager.default.removeItem(atPath: "/Applications/Omanix.app")
        try? FileManager.default.removeItem(
            atPath: NSHomeDirectory() + "/.omanix-store"
        )
        store.successMessage = "Omanix removed. Config preserved at ~/.config/omanix"
    }
}

#Preview {
    SettingsView(store: StoreViewModel())
}
