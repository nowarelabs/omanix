// modules/apps/store/Sources/StoreViewModel.swift
// Omanix Store — ViewModel for package management
import SwiftUI
import Foundation

@MainActor
class StoreViewModel: ObservableObject {
    @Published var packages: [PackageItem] = []
    @Published var installedPackages: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var widgets: [WidgetItem] = []
    @Published var themes: [ThemeItem] = []
    @Published var currentTheme: String = "tokyo-night"

    private let omanixDir: String

    init() {
        self.omanixDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/omanix").path

        loadInstalledPackages()
        loadWidgets()
        loadThemes()
    }

    // MARK: - Package Management

    func refresh() {
        isLoading = true
        errorMessage = nil
        Task {
            await searchPackages(query: "")
            isLoading = false
        }
    }

    func searchPackages(query: String) async {
        guard !query.isEmpty else {
            packages = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Search nixpkgs
            let nixResults = try await runCommand(
                "nix", ["search", "nixpkgs", query, "--json"]
            )

            // Search brew
            let brewResults = try await runCommand(
                "brew", ["search", query]
            )

            // Parse and combine results
            var results: [PackageItem] = []

            // Parse nix search JSON output
            if let data = nixResults.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                for (name, info) in json {
                    if let details = info as? [String: Any],
                       let description = details["description"] as? String {
                        results.append(PackageItem(
                            name: name,
                            description: description,
                            source: .nixpkgs,
                            isInstalled: installedPackages.contains(name)
                        ))
                    }
                }
            }

            // Parse brew search output
            let brewPackages = brewResults.components(separatedBy: "\n").filter { !$0.isEmpty }
            for name in brewPackages {
                results.append(PackageItem(
                    name: name,
                    description: "Homebrew package",
                    source: .homebrew,
                    isInstalled: installedPackages.contains(name)
                ))
            }

            packages = results
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func installPackage(_ package: PackageItem) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let command: [String]
            switch package.source {
            case .nixpkgs:
                command = ["omanix", "add", package.name]
            case .homebrew:
                command = ["omanix", "add", "--brew", package.name]
            case .custom:
                command = ["omanix", "install-app", package.name]
            }

            let output = try await runCommand(command[0], Array(command.dropFirst()))
            successMessage = "Installed \(package.name)"

            // Update installed list
            installedPackages.insert(package.name)

            // Update package in list
            if let index = packages.firstIndex(where: { $0.id == package.id }) {
                packages[index].isInstalled = true
            }
        } catch {
            errorMessage = "Failed to install \(package.name): \(error.localizedDescription)"
        }

        isLoading = false
    }

    func uninstallPackage(_ package: PackageItem) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let command: [String]
            switch package.source {
            case .nixpkgs:
                command = ["omanix", "remove", package.name]
            case .homebrew:
                command = ["omanix", "remove", "--brew", package.name]
            case .custom:
                command = ["omanix", "uninstall-app", package.name]
            }

            let output = try await runCommand(command[0], Array(command.dropFirst()))
            successMessage = "Uninstalled \(package.name)"

            // Update installed list
            installedPackages.remove(package.name)

            // Update package in list
            if let index = packages.firstIndex(where: { $0.id == package.id }) {
                packages[index].isInstalled = false
            }
        } catch {
            errorMessage = "Failed to uninstall \(package.name): \(error.localizedDescription)"
        }

        isLoading = false
    }

    func rebuild() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            let output = try await runCommand("omanix", ["rebuild"])
            successMessage = "System rebuilt successfully"
        } catch {
            errorMessage = "Rebuild failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Widget Management

    func loadWidgets() {
        widgets = [
            WidgetItem(id: "store", name: "Omanix Store", icon: "bag", isEnabled: true),
            WidgetItem(id: "pomodoro", name: "Pomodoro Timer", icon: "timer", isEnabled: false),
            WidgetItem(id: "clock", name: "Clock", icon: "clock", isEnabled: false),
        ]
    }

    func toggleWidget(_ widget: WidgetItem) async {
        guard let index = widgets.firstIndex(where: { $0.id == widget.id }) else { return }

        widgets[index].isEnabled.toggle()

        // TODO: Update configuration.nix and rebuild
        // This would modify the nix config file
    }

    // MARK: - Theme Management

    func loadThemes() {
        themes = [
            ThemeItem(id: "tokyo-night", name: "Tokyo Night", colors: [
                .background: Color(red: 0.13, green: 0.13, blue: 0.17),
                .surface: Color(red: 0.18, green: 0.18, blue: 0.23),
                .accent: Color(red: 0.42, green: 0.44, blue: 0.95),
                .text: Color(red: 0.87, green: 0.87, blue: 0.93),
            ]),
            ThemeItem(id: "catppuccin", name: "Catppuccin Mocha", colors: [
                .background: Color(red: 0.11, green: 0.11, blue: 0.15),
                .surface: Color(red: 0.15, green: 0.15, blue: 0.20),
                .accent: Color(red: 0.83, green: 0.53, blue: 0.76),
                .text: Color(red: 0.90, green: 0.90, blue: 0.95),
            ]),
        ]
    }

    func selectTheme(_ theme: ThemeItem) {
        currentTheme = theme.id
        // TODO: Update configuration.nix and rebuild
    }

    // MARK: - Installed Packages

    func loadInstalledPackages() {
        // Read from configuration.nix or run `omanix list-apps`
        Task {
            do {
                let output = try await runCommand("omanix", ["list-apps"])
                // Parse output and populate installedPackages
                let lines = output.components(separatedBy: "\n")
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("✓") {
                        let name = trimmed.replacingOccurrences(of: "✓ ", with: "")
                        installedPackages.insert(name)
                    }
                }
            } catch {
                // Ignore errors on init
            }
        }
    }

    // MARK: - Helpers

    private func runCommand(_ command: String, _ arguments: [String]) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        process.standardOutput = pipe
        process.standardError = pipe

        process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw StoreError.invalidOutput
        }

        guard process.terminationStatus == 0 else {
            throw StoreError.commandFailed(output)
        }

        return output
    }
}

enum StoreError: LocalizedError {
    case invalidOutput
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidOutput:
            return "Invalid command output"
        case .commandFailed(let output):
            return "Command failed: \(output)"
        }
    }
}
