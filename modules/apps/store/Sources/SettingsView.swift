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
            HStack {
                VStack(alignment: .leading) {
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.text)
                    Text("Configure Omanix system")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
            }
            .padding()

            Form {
                Section("System") {
                    HStack {
                        Text("Hostname")
                            .foregroundColor(theme.text)
                        Spacer()
                        Text(hostName)
                            .foregroundColor(theme.secondaryText)
                    }

                    HStack {
                        Text("Username")
                            .foregroundColor(theme.text)
                        Spacer()
                        Text(userName)
                            .foregroundColor(theme.secondaryText)
                    }

                    HStack {
                        Text("Omanix Version")
                            .foregroundColor(theme.text)
                        Spacer()
                        Text("0.1.0")
                            .foregroundColor(theme.secondaryText)
                    }

                    Toggle("Auto-rebuild after changes", isOn: $autoRebuild)
                        .foregroundColor(theme.text)
                }

                Section("Actions") {
                    Button(action: { Task { await store.rebuild() } }) {
                        Label("Rebuild System", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundColor(theme.text)
                    }

                    Button(action: { rollback() }) {
                        Label("Rollback to Previous Generation", systemImage: "arrow.uturn.backward")
                            .foregroundColor(theme.text)
                    }

                    Button(action: { updateFlake() }) {
                        Label("Update Flake Inputs", systemImage: "arrow.down.circle")
                            .foregroundColor(theme.text)
                    }
                }

                Section {
                    Button(action: { showAdvanced.toggle() }) {
                        HStack {
                            Text("Advanced")
                                .foregroundColor(theme.text)
                            Spacer()
                            Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                .foregroundColor(theme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)

                    if showAdvanced {
                        Button(action: { resetConfig() }) {
                            Label("Reset Configuration", systemImage: "arrow.counterclockwise")
                                .foregroundColor(.red)
                        }

                        Button(action: { uninstallOmanix() }) {
                            Label("Uninstall Omanix", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)
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
                }
                Spacer()
            }
            .padding()
            .background(theme.surface)
        }
        .onAppear {
            loadSettings()
        }
    }

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
        Task {
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["omanix", "rebuild", "--rollback"]
                try process.run()
                process.waitUntilExit()
                store.successMessage = "Rolled back successfully"
            } catch {
                store.errorMessage = "Rollback failed: \(error.localizedDescription)"
            }
        }
    }

    private func updateFlake() {
        Task {
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["omanix", "update"]
                try process.run()
                process.waitUntilExit()
                store.successMessage = "Flake updated successfully"
            } catch {
                store.errorMessage = "Update failed: \(error.localizedDescription)"
            }
        }
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
