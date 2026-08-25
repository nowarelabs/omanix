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
    @Published var isIndexingBrew = false
    @Published var brewIndexReady = false

    private let omanixDir: String
    private var searchTask: Task<Void, Never>?
    private var lastQuery: String = ""
    private var messageTimer: Task<Void, Never>?

    // In-memory brew index: (token/name, name array, description)
    private var brewCaskIndex: [(token: String, names: [String], desc: String)] = []
    private var brewFormulaIndex: [(name: String, desc: String)] = []
    private var brewIndexLoaded = false

    private var brewCacheDir: String {
        NSHomeDirectory() + "/.omanix-store/brew-index"
    }

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

        // 1. Filter declared packages (instant, local match)
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
        if let nixPath = findExecutable("nix") {
            do {
                let json = try await runJSONCommand(
                    nixPath, ["search", "nixpkgs", query, "--json"],
                    timeout: 20.0
                )
                for (fullName, info) in json {
                    let name = extractNixPackageName(fullName)
                    if name.isEmpty { continue }
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
            } catch { }
        }

        // 3. Search Homebrew index (cached, instant)
        ensureBrewIndex()
        let brewCaskResults = brewCaskIndex.filter {
            $0.token.contains(queryLower) ||
            $0.names.contains(where: { $0.lowercased().contains(queryLower) }) ||
            $0.desc.lowercased().contains(queryLower)
        }
        for entry in brewCaskResults {
            if results.contains(where: { $0.name == entry.token }) { continue }
            results.append(PackageItem(
                name: entry.token,
                description: entry.desc.isEmpty ? "Homebrew cask" : entry.desc,
                source: .homebrewCask,
                isInstalled: installedPackages.contains(entry.token)
            ))
        }

        let brewFormulaResults = brewFormulaIndex.filter {
            $0.name.contains(queryLower) || $0.desc.lowercased().contains(queryLower)
        }
        for entry in brewFormulaResults {
            if results.contains(where: { $0.name == entry.name }) { continue }
            results.append(PackageItem(
                name: entry.name,
                description: entry.desc.isEmpty ? "Homebrew formula" : entry.desc,
                source: .homebrewBrew,
                isInstalled: installedPackages.contains(entry.name)
            ))
        }

        packages = results
        isLoading = false
    }

    // MARK: - Brew Index (cached to disk)

    func ensureBrewIndex() {
        guard !brewIndexLoaded else { return }
        brewIndexLoaded = true
        loadBrewIndexFromDisk()
        // Refresh if older than 7 days or doesn't exist
        if brewCaskIndex.isEmpty && brewFormulaIndex.isEmpty {
            Task { await downloadBrewIndex() }
        } else if isBrewIndexStale() {
            Task { await downloadBrewIndex() }
        }
    }

    func refreshBrewIndex() async {
        await downloadBrewIndex()
    }

    private func loadBrewIndexFromDisk() {
        let fm = FileManager.default

        // Load casks
        let caskPath = "\(brewCacheDir)/casks.json"
        if let data = fm.contents(atPath: caskPath),
           let entries = try? JSONDecoder().decode([BrewCask].self, from: data) {
            brewCaskIndex = entries.map { (token: $0.token, names: $0.name ?? [], desc: $0.desc ?? "") }
        }

        // Load formulas
        let formulaPath = "\(brewCacheDir)/formulas.json"
        if let data = fm.contents(atPath: formulaPath),
           let entries = try? JSONDecoder().decode([BrewFormula].self, from: data) {
            brewFormulaIndex = entries.map { (name: $0.name, desc: $0.desc ?? "") }
        }

        brewIndexReady = !brewCaskIndex.isEmpty || !brewFormulaIndex.isEmpty
    }

    private func isBrewIndexStale() -> Bool {
        let fm = FileManager.default
        let metaPath = "\(brewCacheDir)/last-updated"
        guard let data = fm.contents(atPath: metaPath),
              let str = String(data: data, encoding: .utf8),
              let timestamp = Double(str.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return true
        }
        let lastUpdate = Date(timeIntervalSince1970: timestamp)
        return Date().timeIntervalSince(lastUpdate) > 7 * 24 * 3600
    }

    private func downloadBrewIndex() async {
        isIndexingBrew = true
        let fm = FileManager.default
        try? fm.createDirectory(atPath: brewCacheDir, withIntermediateDirectories: true)

        await withTaskGroup(of: Void.self) { group in
            // Download casks
            group.addTask { [weak self] in
                guard let self else { return }
                let url = URL(string: "https://formulae.brew.sh/api/cask.json")!
                guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
                try? data.write(to: URL(fileURLWithPath: "\(self.brewCacheDir)/casks.json"))
                if let entries = try? JSONDecoder().decode([BrewCask].self, from: data) {
                    await MainActor.run {
                        self.brewCaskIndex = entries.map { (token: $0.token, names: $0.name ?? [], desc: $0.desc ?? "") }
                    }
                }
            }

            // Download formulas
            group.addTask { [weak self] in
                guard let self else { return }
                let url = URL(string: "https://formulae.brew.sh/api/formula.json")!
                guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
                try? data.write(to: URL(fileURLWithPath: "\(self.brewCacheDir)/formulas.json"))
                if let entries = try? JSONDecoder().decode([BrewFormula].self, from: data) {
                    await MainActor.run {
                        self.brewFormulaIndex = entries.map { (name: $0.name, desc: $0.desc ?? "") }
                    }
                }
            }
        }

        // Write timestamp
        let ts = "\(Date().timeIntervalSince1970)"
        try? ts.write(toFile: "\(brewCacheDir)/last-updated", atomically: true, encoding: .utf8)

        await MainActor.run {
            self.isIndexingBrew = false
            self.brewIndexReady = !self.brewCaskIndex.isEmpty || !self.brewFormulaIndex.isEmpty
        }
    }

    // MARK: - Search Helpers

    private func findExecutable(_ name: String) -> String? {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", name]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
        let path = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (path?.isEmpty == true) ? nil : path
    }

    private func runJSONCommand(
        _ path: String, _ arguments: [String], timeout: TimeInterval
    ) async throws -> [String: Any] {
        let process = Process()
        let stdoutPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        if process.isRunning {
            process.terminate()
            throw StoreError.commandFailed("nix search timed out")
        }

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StoreError.invalidOutput
        }
        return json
    }

    private func extractNixPackageName(_ nixKey: String) -> String {
        let parts = nixKey.split(separator: ".")
        return parts.last.map(String.init) ?? nixKey
    }

    func installPackage(_ package: PackageItem) async {
        isLoading = true
        clearMessages()

        do {
            let command: [String]
            switch package.source {
            case .custom:
                command = ["omanix", "install-app", package.name]
            default:
                command = ["omanix", "add", package.name]
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
            case .custom:
                command = ["omanix", "uninstall-app", package.name]
            default:
                command = ["omanix", "remove", package.name]
            }

            _ = try await runCommand(command[0], Array(command.dropFirst()))
            showMessage("Removed \(package.name)", type: .success)

            installedPackages.remove(package.name)
            if let index = packages.firstIndex(where: { $0.id == package.id }) {
                packages[index].isInstalled = false
            }
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

    // MARK: - Installed Packages

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

    // MARK: - Process Helpers

    private func runCommand(_ command: String, _ arguments: [String]) async throws -> String {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw StoreError.invalidOutput
        }

        guard process.terminationStatus == 0 else {
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            throw StoreError.commandFailed(errStr.isEmpty ? output : errStr)
        }

        return output
    }

    private func runCommandWithTimeout(
        _ path: String, _ arguments: [String], timeout: TimeInterval
    ) async throws -> String {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        if process.isRunning {
            process.terminate()
            throw StoreError.commandFailed("Command timed out after \(Int(timeout))s")
        }

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw StoreError.invalidOutput
        }

        guard process.terminationStatus == 0 else {
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            throw StoreError.commandFailed(errStr.isEmpty ? output : errStr)
        }

        return output
    }
}

// MARK: - Brew Index Codable Types

private struct BrewCask: Codable {
    let token: String
    let name: [String]?
    let desc: String?
}

private struct BrewFormula: Codable {
    let name: String
    let desc: String?
}

// MARK: - Errors

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
