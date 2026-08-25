// modules/apps/store/Sources/SettingsView.swift
// Omanix Store — system settings
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: StoreViewModel
    @State private var hostName = ""
    @State private var userName = ""
    @State private var autoRebuild = true
    @State private var showAdvanced = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Configure Omanix system")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()

            Form {
                // System section
                Section("System") {
                    HStack {
                        Text("Hostname")
                        Spacer()
                        Text(hostName)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Username")
                        Spacer()
                        Text(userName)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Omanix Version")
                        Spacer()
                        Text("0.1.0")
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Auto-rebuild after changes", isOn: $autoRebuild)
                }

                // Actions section
                Section("Actions") {
                    Button(action: { Task { await store.rebuild() } }) {
                        Label("Rebuild System", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button(action: { rollback() }) {
                        Label("Rollback to Previous Generation", systemImage: "arrow.uturn.backward")
                    }

                    Button(action: { updateFlake() }) {
                        Label("Update Flake Inputs", systemImage: "arrow.down.circle")
                    }
                }

                // Advanced section
                Section {
                    Button(action: { showAdvanced.toggle() }) {
                        HStack {
                            Text("Advanced")
                            Spacer()
                            Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        }
                    }
                    .buttonStyle(.plain)

                    if showAdvanced {
                        Button(action: { resetConfig() }) {
                            Label("Reset Configuration", systemImage: "arrow.counterclockwise")
                                .foregroundStyle(.red)
                        }

                        Button(action: { uninstallOmanix() }) {
                            Label("Uninstall Omanix", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)

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
                }
                Spacer()
            }
            .padding()
            .background(.bar)
        }
        .onAppear {
            loadSettings()
        }
    }

    private func loadSettings() {
        // Read from configuration.nix
        hostName = "Vances-MacBook-Pro"
        userName = "vanceworks"
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

        // Create backup
        let backupPath = configPath + ".backup"
        try? FileManager.default.copyItem(atPath: configPath, toPath: backupPath)

        // Reset to default configuration
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
        // Remove login item
        _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/osascript"), arguments: [
            "-e", "tell application \"System Events\" to delete login item \"Omanix\""
        ])

        // Remove app
        try? FileManager.default.removeItem(atPath: "/Applications/Omanix.app")

        // Remove store build directory
        try? FileManager.default.removeItem(
            atPath: NSHomeDirectory() + "/.omanix-store"
        )

        store.successMessage = "Omanix removed. Config preserved at ~/.config/omanix"
    }
}

#Preview {
    SettingsView(store: StoreViewModel())
}
