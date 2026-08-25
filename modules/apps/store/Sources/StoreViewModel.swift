// modules/apps/store/Sources/StoreViewModel.swift
// Omanix Store — ViewModel for package management
import SwiftUI
import Foundation

@MainActor
class StoreViewModel: ObservableObject {
    @Published var packages: [PackageItem] = []
    @Published var installedPackages: Set<String> = []
    @Published var declaredPackages: [PackageItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var widgets: [WidgetItem] = []
    @Published var themes: [ThemeItem] = []
    @Published var currentTheme: String = "tokyo-night"

    private let omanixDir: String
    private var searchTask: Task<Void, Never>?
    private var lastQuery: String = ""
    private var messageTimer: Task<Void, Never>?

    init() {
        self.omanixDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/omanix").path

        loadDeclaredPackages()
        loadWidgets()
        loadThemes()
    }

    // MARK: - Package Management

    func search(query: String) {
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

        var results: [PackageItem] = []
        let queryLower = query.lowercased()

        // 1. Filter declared packages (instant, local)
        for pkg in declaredPackages {
            if pkg.name.lowercased().contains(queryLower) ||
               pkg.description.lowercased().contains(queryLower) {
                results.append(PackageItem(
                    name: pkg.name,
                    description: pkg.description.isEmpty ? pkg.source.displayName + " package" : pkg.description,
                    source: pkg.source,
                    isInstalled: true
                ))
            }
        }

        // 2. Search nixpkgs
        do {
            let nixResults = try await runCommandWithTimeout(
                "nix", ["search", "nixpkgs", query, "--json"], timeout: 15.0
            )
            if let data = nixResults.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                for (name, info) in json {
                    if results.contains(where: { $0.name == name }) { continue }
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
        } catch { }

        // 3. Search Homebrew formulas
        do {
            let brewResults = try await runCommandWithTimeout(
                "brew", ["search", query], timeout: 10.0
            )
            let brewPackages = brewResults.components(separatedBy: "\n")
                .filter { !$0.isEmpty && !$0.hasPrefix("==>") && !$0.hasPrefix("==" ) }
            for name in brewPackages {
                let trimmed = name.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                if results.contains(where: { $0.name == trimmed }) { continue }
                results.append(PackageItem(
                    name: trimmed,
                    description: "Homebrew formula",
                    source: .homebrewBrew,
                    isInstalled: installedPackages.contains(trimmed)
                ))
            }
        } catch { }

        // 4. Search Homebrew casks
        do {
            let caskResults = try await runCommandWithTimeout(
                "brew", ["search", "--cask", query], timeout: 10.0
            )
            let caskPackages = caskResults.components(separatedBy: "\n")
                .filter { !$0.isEmpty && !$0.hasPrefix("==>") && !$0.hasPrefix("==" ) }
            for name in caskPackages {
                let trimmed = name.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                if results.contains(where: { $0.name == trimmed }) { continue }
                results.append(PackageItem(
                    name: trimmed,
                    description: "Homebrew cask",
                    source: .homebrewCask,
                    isInstalled: installedPackages.contains(trimmed)
                ))
            }
        } catch { }

        packages = results
        isLoading = false
    }

    func installPackage(_ package: PackageItem) async {
        isLoading = true
        clearMessages()

        do {
            let command: [String]
            switch package.source {
            case .nixpkgs, .nix:
                command = ["omanix", "add", package.name]
            case .homebrewBrew, .homebrewCask:
                command = ["omanix", "add", package.name]
            case .custom:
                command = ["omanix", "install-app", package.name]
            }

            _ = try await runCommand(command[0], Array(command.dropFirst()))
            showMessage("Installed \(package.name)", type: .success)

            installedPackages.insert(package.name)
            if let index = packages.firstIndex(where: { $0.id == package.id }) {
                packages[index].isInstalled = true
            }
        } catch {
            showMessage("Failed to install \(package.name): \(error.localizedDescription)", type: .error)
        }

        isLoading = false
    }

    func uninstallPackage(_ package: PackageItem) async {
        isLoading = true
        clearMessages()

        do {
            let command: [String]
            switch package.source {
            case .nixpkgs, .nix:
                command = ["omanix", "remove", package.name]
            case .homebrewBrew, .homebrewCask:
                command = ["omanix", "remove", package.name]
            case .custom:
                command = ["omanix", "uninstall-app", package.name]
            }

            _ = try await runCommand(command[0], Array(command.dropFirst()))
            showMessage("Removed \(package.name)", type: .success)

            installedPackages.remove(package.name)
            if let index = packages.firstIndex(where: { $0.id == package.id }) {
                packages[index].isInstalled = false
            }
            // Remove from declared packages too
            declaredPackages.removeAll { $0.name == package.name }
        } catch {
            showMessage("Failed to remove \(package.name): \(error.localizedDescription)", type: .error)
        }

        isLoading = false
    }

    func rebuild() async {
        isLoading = true
        clearMessages()

        do {
            _ = try await runCommand("omanix", ["rebuild"])
            showMessage("System rebuilt successfully", type: .success)
        } catch {
            showMessage("Rebuild failed: \(error.localizedDescription)", type: .error)
        }

        isLoading = false
    }

    // MARK: - Messages

    private enum MessageType { case success, error }

    private func showMessage(_ text: String, type: MessageType) {
        messageTimer?.cancel()
        switch type {
        case .success: successMessage = text; errorMessage = nil
        case .error: errorMessage = text; successMessage = nil
        }
        messageTimer = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            clearMessages()
        }
    }

    private func clearMessages() {
        errorMessage = nil
        successMessage = nil
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

        let configPath = "\(omanixDir)/configuration.nix"
        guard var config = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            showMessage("Could not read configuration.nix", type: .error)
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
            showMessage("Could not read configuration.nix", type: .error)
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
        showMessage("Theme set to \(theme.name)", type: .success)
    }

    // MARK: - Installed Packages (from configuration.nix)

    func loadDeclaredPackages() {
        Task {
            do {
                let output = try await runCommand("omanix", ["list-packages"])
                guard let data = output.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    return
                }

                var items: [PackageItem] = []
                var names: Set<String> = []

                for entry in json {
                    guard let sourceStr = entry["source"] as? String,
                          let name = entry["name"] as? String else { continue }

                    let source: PackageItem.PackageSource
                    switch sourceStr {
                    case "nixpkgs": source = .nixpkgs
                    case "nix": source = .nix
                    case "homebrew-brew": source = .homebrewBrew
                    case "homebrew-cask": source = .homebrewCask
                    case "custom": source = .custom
                    default: source = .nixpkgs
                    }

                    let description = entry["description"] as? String ?? ""

                    items.append(PackageItem(
                        name: name,
                        description: description,
                        source: source,
                        isInstalled: true
                    ))
                    names.insert(name)
                }

                items.sort { a, b in
                    if a.source.rawValue != b.source.rawValue {
                        return a.source.rawValue < b.source.rawValue
                    }
                    return a.name < b.name
                }

                declaredPackages = items
                installedPackages = names
            } catch { }
        }
    }

    func loadInstalledPackages() {
        loadDeclaredPackages()
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

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
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
