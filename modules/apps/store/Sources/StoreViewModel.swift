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
    private var searchTask: Task<Void, Never>?
    private var lastQuery: String = ""

    init() {
        self.omanixDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/omanix").path

        loadInstalledPackages()
        loadWidgets()
        loadThemes()
    }

    // MARK: - Package Management

    func search(query: String) {
        // Don't cancel if same query
        guard query != lastQuery else { return }
        lastQuery = query

        searchTask?.cancel()

        guard !query.isEmpty else {
            packages = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await searchPackages(query: query)
        }
    }

    func searchPackages(query: String) async {
        isLoading = true
        errorMessage = nil

        // Run searches sequentially to avoid cancellation issues
        var results: [PackageItem] = []

        // Search nixpkgs
        do {
            let nixResults = try await runCommandWithTimeout(
                "nix", ["search", "nixpkgs", query, "--json"], timeout: 15.0
            )
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
        } catch {
            // Continue if nix search fails
        }

        // Search brew
        do {
            let brewResults = try await runCommandWithTimeout(
                "brew", ["search", query], timeout: 10.0
            )
            let brewPackages = brewResults.components(separatedBy: "\n")
                .filter { !$0.isEmpty }
            for name in brewPackages {
                results.append(PackageItem(
                    name: name,
                    description: "Homebrew package",
                    source: .homebrew,
                    isInstalled: installedPackages.contains(name)
                ))
            }
        } catch {
            // Continue if brew search fails
        }

        packages = results
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

            _ = try await runCommand(command[0], Array(command.dropFirst()))
            successMessage = "Installed \(package.name)"

            installedPackages.insert(package.name)

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

            _ = try await runCommand(command[0], Array(command.dropFirst()))
            successMessage = "Uninstalled \(package.name)"

            installedPackages.remove(package.name)

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
            _ = try await runCommand("omanix", ["rebuild"])
            successMessage = "System rebuilt successfully"
        } catch {
            errorMessage = "Rebuild failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Widget Management

    func loadWidgets() {
        widgets = [
            WidgetItem(id: "store", name: "Omanix", icon: "bag", isEnabled: true),
            WidgetItem(id: "pomodoro", name: "Pomodoro Timer", icon: "timer", isEnabled: false),
            WidgetItem(id: "clock", name: "Clock", icon: "clock", isEnabled: false),
        ]
    }

    func toggleWidget(_ widget: WidgetItem) async {
        guard let index = widgets.firstIndex(where: { $0.id == widget.id }) else { return }

        widgets[index].isEnabled.toggle()

        // Update configuration.nix
        let configPath = "\(omanixDir)/configuration.nix"
        guard var config = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            errorMessage = "Could not read configuration.nix"
            return
        }

        let option = "omanix.widgets.\(widget.id).enable"
        let newValue = widgets[index].isEnabled ? "true" : "false"

        if config.contains(option) {
            config = config.replacingOccurrences(
                of: "\(option) = .*;",
                with: "\(option) = \(newValue);",
                options: .regularExpression
            )
        } else {
            config += "\n  \(option) = \(newValue);"
        }

        try? config.write(toFile: configPath, atomically: true, encoding: .utf8)
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

        let configPath = "\(omanixDir)/configuration.nix"
        guard var config = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            errorMessage = "Could not read configuration.nix"
            return
        }

        if config.contains("omanix.theme") {
            config = config.replacingOccurrences(
                of: "omanix\\.theme = \".*\";",
                with: "omanix.theme = \"\(theme.id)\";",
                options: .regularExpression
            )
        } else {
            config += "\n  omanix.theme = \"\(theme.id)\";"
        }

        try? config.write(toFile: configPath, atomically: true, encoding: .utf8)
    }

    // MARK: - Installed Packages

    func loadInstalledPackages() {
        Task {
            do {
                let output = try await runCommand("omanix", ["list-apps"])
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

        try process.run()
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

    private func runCommandWithTimeout(
        _ command: String, _ arguments: [String], timeout: TimeInterval
    ) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        // Wait with timeout
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        if process.isRunning {
            process.terminate()
            throw StoreError.commandFailed("Command timed out after \(Int(timeout))s")
        }

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
