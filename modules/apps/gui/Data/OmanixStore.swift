// Data/OmanixStore.swift
// Omanix — the data/service layer. Wraps the `omanix` CLI and the on-disk
// Homebrew index. Foundation ONLY — no SwiftUI. All methods run the `omanix`
// command and return plain values; the view model layers state on top.

import Foundation

enum OmanixError: LocalizedError {
    case invalidOutput
    case commandFailed(String)
    case timedOut(String)

    var errorDescription: String? {
        switch self {
        case .invalidOutput: return "Invalid command output"
        case .commandFailed(let output): return "Command failed: \(output)"
        case .timedOut(let cmd): return "\(cmd) timed out"
        }
    }
}

/// The single place that talks to the `omanix` CLI and reads/writes files
/// under `~/.omanix`. Create one instance and share it.
final class OmanixStore {

    private let omanixDir: String
    private var brewCacheDir: String { "\(omanixDir)/brew-index" }

    // In-memory brew index, backed by 7-day disk cache.
    private var brewCaskIndex: [(token: String, names: [String], desc: String)] = []
    private var brewFormulaIndex: [(name: String, desc: String)] = []
    private var brewIndexLoaded = false

    // MARK: - Init

    init(omanixDir: String = NSHomeDirectory() + "/.omanix") {
        self.omanixDir = omanixDir
    }

    var configPath: String { "\(omanixDir)/configuration.nix" }

    // MARK: - Installed (declared) packages

    /// Reads `omanix list-packages` and returns the declared set (deduped).
    func declaredPackages() async throws -> [PackageItem] {
        let output = try await runCommand("omanix", ["list-packages"])
        guard let data = output.data(using: .utf8) else { throw OmanixError.invalidOutput }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            FileLogger.shared.error("store", "failed to parse list-packages JSON")
            throw OmanixError.invalidOutput
        }

        var items: [PackageItem] = []
        var seen: Set<String> = []

        for entry in json {
            guard let sourceStr = entry["source"] as? String,
                  let name = entry["name"] as? String else { continue }

            let source = PackageSource(cliValue: sourceStr)
            let key = "\(name)|\(source.rawValue)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            items.append(PackageItem(
                name: name,
                description: entry["description"] as? String ?? "",
                source: source,
                isInstalled: true
            ))
        }

        items.sort { a, b in
            if a.source.rawValue != b.source.rawValue { return a.source.rawValue < b.source.rawValue }
            return a.name < b.name
        }

        FileLogger.shared.info("store", "loaded \(items.count) declared packages (\(seen.count) unique)")
        return items
    }

    // MARK: - Install / uninstall

    func addPackage(_ package: PackageItem) async throws {
        let command: [String]
        switch package.source {
        case .custom: command = ["install-app", package.name]
        default:      command = ["add", package.name]
        }
        _ = try await runCommand("omanix", command)
        FileLogger.shared.info("store", "added \(package.name)")
    }

    func removePackage(_ package: PackageItem) async throws {
        let command: [String]
        switch package.source {
        case .custom: command = ["uninstall-app", package.name]
        default:      command = ["remove", package.name]
        }
        _ = try await runCommand("omanix", command)
        FileLogger.shared.info("store", "removed \(package.name)")
    }

    // MARK: - System actions

    func rebuild() async throws -> [String] {
        let output = try await runCommand("omanix", ["rebuild"])
        return output.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    func rollback() async throws {
        _ = try await runCommand("omanix", ["rebuild", "--rollback"])
    }

    func updateFlake() async throws {
        _ = try await runCommand("omanix", ["update"])
    }

    // MARK: - Search

    /// Debounced at the view-model layer; this performs the actual search.
    /// Returns matches from declared packages, nixpkgs, and Homebrew.
    func search(query: String, declared: [PackageItem]) async -> [PackageItem] {
        var results: [PackageItem] = []
        let q = query.lowercased()

        // 1. Declared (instant, local)
        for pkg in declared {
            if pkg.name.lowercased().contains(q) || pkg.description.lowercased().contains(q) {
                results.append(PackageItem(
                    name: pkg.name,
                    description: pkg.description,
                    source: pkg.source,
                    isInstalled: true
                ))
            }
        }

        // 2. nixpkgs via `nix search`
        if let nixPath = await findExecutable("nix") {
            do {
                let json = try await runJSONCommand(
                    nixPath, ["search", "nixpkgs", query, "--json"], timeout: 20
                )
                for (fullName, info) in json {
                    let name = extractNixName(fullName)
                    if name.isEmpty || results.contains(where: { $0.name == name }) { continue }
                    if let details = info as? [String: Any],
                       let description = details["description"] as? String {
                        results.append(PackageItem(
                            name: name,
                            description: description,
                            source: .nixpkgs,
                            isInstalled: declared.contains { $0.name == name }
                        ))
                    }
                }
            } catch {
                FileLogger.shared.warn("store", "nix search skipped: \(error.localizedDescription)")
            }
        }

        // 3. Homebrew (cached index)
        ensureBrewIndex()
        for entry in brewCaskIndex
        where entry.token.contains(q) ||
              (entry.names.contains { $0.lowercased().contains(q) }) ||
              entry.desc.lowercased().contains(q) {
            guard !results.contains(where: { $0.name == entry.token }) else { continue }
            results.append(PackageItem(
                name: entry.token,
                description: entry.desc.isEmpty ? "Homebrew cask" : entry.desc,
                source: .homebrewCask,
                isInstalled: declared.contains { $0.name == entry.token }
            ))
        }

        for entry in brewFormulaIndex
        where entry.name.contains(q) || entry.desc.lowercased().contains(q) {
            guard !results.contains(where: { $0.name == entry.name }) else { continue }
            results.append(PackageItem(
                name: entry.name,
                description: entry.desc.isEmpty ? "Homebrew formula" : entry.desc,
                source: .homebrewBrew,
                isInstalled: declared.contains { $0.name == entry.name }
            ))
        }

        return results
    }

    // MARK: - Brew index (disk-cached)

    /// Loads the cached index, kicking off a background refresh if stale/missing.
    func ensureBrewIndex() {
        guard !brewIndexLoaded else { return }
        brewIndexLoaded = true
        loadedBrewIndexFromDisk()
        if (brewCaskIndex.isEmpty && brewFormulaIndex.isEmpty) || isBrewIndexStale() {
            Task { await refreshBrewIndex() }
        }
    }

    func refreshBrewIndex() async {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: brewCacheDir, withIntermediateDirectories: true)
        let cacheDir = brewCacheDir

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                guard let url = URL(string: "https://formulae.brew.sh/api/cask.json"),
                      let (data, _) = try? await URLSession.shared.data(from: url) else { return }
                try? data.write(to: URL(fileURLWithPath: "\(cacheDir)/casks.json"))
            }
            group.addTask {
                guard let url = URL(string: "https://formulae.brew.sh/api/formula.json"),
                      let (data, _) = try? await URLSession.shared.data(from: url) else { return }
                try? data.write(to: URL(fileURLWithPath: "\(cacheDir)/formulas.json"))
            }
        }

        let ts = "\(Date().timeIntervalSince1970)"
        try? ts.write(toFile: "\(brewCacheDir)/last-updated", atomically: true, encoding: .utf8)
        loadedBrewIndexFromDisk()
    }

    private func loadedBrewIndexFromDisk() {
        let fm = FileManager.default

        if let data = fm.contents(atPath: "\(brewCacheDir)/casks.json"),
           let entries = try? JSONDecoder().decode([BrewCask].self, from: data) {
            brewCaskIndex = entries.map { (token: $0.token, names: $0.name ?? [], desc: $0.desc ?? "") }
        }
        if let data = fm.contents(atPath: "\(brewCacheDir)/formulas.json"),
           let entries = try? JSONDecoder().decode([BrewFormula].self, from: data) {
            brewFormulaIndex = entries.map { (name: $0.name, desc: $0.desc ?? "") }
        }

        brewIndexReady = !brewCaskIndex.isEmpty || !brewFormulaIndex.isEmpty
    }

    private(set) var brewIndexReady = false

    private func isBrewIndexStale() -> Bool {
        let fm = FileManager.default
        guard let data = fm.contents(atPath: "\(brewCacheDir)/last-updated"),
              let str = String(data: data, encoding: .utf8),
              let timestamp = Double(str.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return true
        }
        let last = Date(timeIntervalSince1970: timestamp)
        return Date().timeIntervalSince(last) > 7 * 24 * 3600
    }

    // MARK: - Configuration edits

    /// Toggles a widget option in configuration.nix.
    func setWidgetEnabled(_ id: String, _ enabled: Bool) throws {
        let option = "omanix.widgets.\(id).enable"
        let value = enabled ? "true" : "false"
        try rewriteOption(option, toLiteral: value, in: configPath)
    }

    func setTheme(_ id: String) throws {
        try rewriteOption("omanix.theme", toLiteral: "\"\(id)\"", in: configPath)
    }

    func currentThemeId() -> String {
        // 1. Try ~/.config/omanix/theme.json (written by modules/theme/theme.nix)
        let themeJSON = NSHomeDirectory() + "/.config/omanix/theme.json"
        if let data = FileManager.default.contents(atPath: themeJSON),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let name = obj["name"] as? String { return name }
        // 2. Fallback: parse configuration.nix
        if let text = try? String(contentsOfFile: configPath, encoding: .utf8),
           let range = text.range(of: #"omanix\.theme\s*=\s*"([^"]+)""#, options: .regularExpression) {
            let substr = String(text[range])
            if let q1 = substr.firstIndex(of: "\""), let q2 = substr.lastIndex(of: "\""), q1 != q2 {
                return String(substr[substr.index(after: q1)..<q2])
            }
        }
        return "tokyo-night"
    }

    func setBarOption(_ key: String, _ value: String) throws {
        try rewriteOption("omanix.bar.\(key)", toLiteral: value, in: configPath)
    }

    func setBarPosition(_ pos: String) throws { try setBarOption("position", "\"\(pos)\"") }
    func setBarTransparent(_ v: Bool) throws { try setBarOption("transparent", v ? "true" : "false") }
    func setBarBlur(_ v: Bool) throws { try setBarOption("blur", v ? "true" : "false") }
    func setBarStyle(_ style: String) throws { try setBarOption("style", "\"\(style)\"") }
    func setBarEnabled(_ v: Bool) throws { try setBarOption("enable", v ? "true" : "false") }
    func setBarHeight(_ h: Int) throws { try setBarOption("height", "\(h)") }

    func setTilingOption(_ key: String, _ value: String) throws {
        try rewriteOption("omanix.tiling.\(key)", toLiteral: value, in: configPath)
    }

    func setTilingEnabled(_ v: Bool) throws { try setTilingOption("enable", v ? "true" : "false") }
    func setTilingLayout(_ layout: String) throws { try setTilingOption("layout", "\"\(layout)\"") }
    func setTilingGapInner(_ gap: Int) throws { try setTilingOption("gapInner", "\(gap)") }
    func setTilingGapOuter(_ gap: Int) throws { try setTilingOption("gapOuter", "\(gap)") }

    // MARK: - Config state readers (bar + tiling)

    /// Reads a literal `option = value;` from configuration.nix.
    func readOption(_ option: String) -> String? {
        guard let text = try? String(contentsOfFile: configPath, encoding: .utf8) else { return nil }
        guard let range = text.range(
            of: #"\#(NSRegularExpression.escapedPattern(for: option))\s*=\s*([^;]+);"#,
            options: .regularExpression
        ) else { return nil }
        let line = String(text[range])
        guard let eq = line.firstIndex(of: "=") else { return nil }
        let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    func readBoolOption(_ option: String) -> Bool? {
        guard let v = readOption(option) else { return nil }
        return v == "true"
    }

    func readIntOption(_ option: String) -> Int? {
        guard let v = readOption(option) else { return nil }
        return Int(v)
    }

    /// Reads the current `omanix.bar.*` values with defaults for anything unset.
    func currentBarState() -> BarState {
        BarState(
            enable: readBoolOption("omanix.bar.enable") ?? true,
            position: readOption("omanix.bar.position") ?? "top",
            transparent: readBoolOption("omanix.bar.transparent") ?? false,
            blur: readBoolOption("omanix.bar.blur") ?? true,
            blurRadius: readIntOption("omanix.bar.blurRadius") ?? 30,
            style: readOption("omanix.bar.style") ?? "default",
            height: readIntOption("omanix.bar.height") ?? 40
        )
    }

    /// Reads the current `omanix.tiling.*` values with defaults for anything unset.
    func currentTilingState() -> TilingState {
        TilingState(
            enable: readBoolOption("omanix.tiling.enable") ?? true,
            layout: readOption("omanix.tiling.layout") ?? "tiles",
            gapInner: readIntOption("omanix.tiling.gapInner") ?? 8,
            gapOuter: readIntOption("omanix.tiling.gapOuter") ?? 10
        )
    }

    /// Rewrites `option = ...;` in a Nix config file, appending if absent.
    private func rewriteOption(_ option: String, toLiteral value: String, in path: String) throws {
        let original = try String(contentsOfFile: path, encoding: .utf8)
        let pattern = NSRegularExpression.escapedPattern(for: option)
        var updated = original
        if updated.range(of: option) != nil {
            updated = updated.replacingOccurrences(
                of: "\(pattern) = .*;",
                with: "\(option) = \(value);",
                options: .regularExpression
            )
        } else {
            updated += "\n  \(option) = \(value);"
        }
        try updated.write(toFile: path, atomically: true, encoding: .utf8)
    }

    // MARK: - Process helpers

    /// GUI apps don't inherit a shell PATH, so we assemble one explicitly.
    private var processPATH: String {
        let userLocal   = NSHomeDirectory() + "/.local/bin"
        let nixProfile  = "/nix/var/nix/profiles/default/bin"
        let nixHome     = NSHomeDirectory() + "/.nix-profile/bin"
        let homebrew    = "/opt/homebrew/bin"
        let systemSw    = "/run/current-system/sw/bin"
        let systemPaths = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
        return "\(userLocal):\(nixProfile):\(nixHome):\(homebrew):\(systemSw):\(systemPaths)"
    }

    private func findExecutable(_ name: String) async -> String? {
        guard let path = try? await runCommand("which", [name]) else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func runCommand(_ command: String, _ arguments: [String]) async throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["PATH": processPATH]
        ) { _, new in new }
        process.standardOutput = stdout
        process.standardError = stderr

        let outTask = Task.detached { stdout.fileHandleForReading.readDataToEndOfFile() }
        let errTask = Task.detached { stderr.fileHandleForReading.readDataToEndOfFile() }

        try process.run()
        while process.isRunning {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        let outData = await outTask.value
        let errData = await errTask.value
        let errStr = String(data: errData, encoding: .utf8) ?? ""
        guard let output = String(data: outData, encoding: .utf8) else {
            throw OmanixError.invalidOutput
        }
        guard process.terminationStatus == 0 else {
            throw OmanixError.commandFailed(errStr.isEmpty ? output : errStr)
        }
        return output
    }

    private func runJSONCommand(_ path: String, _ args: [String], timeout: TimeInterval) async throws -> [String: Any] {
        let process = Process()
        let stdout = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["PATH": processPATH]
        ) { _, new in new }
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        let dataTask = Task.detached { stdout.fileHandleForReading.readDataToEndOfFile() }
        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        if process.isRunning {
            process.terminate()
            throw OmanixError.timedOut(path)
        }

        let data = await dataTask.value
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OmanixError.invalidOutput
        }
        return json
    }

    private func extractNixName(_ key: String) -> String {
        key.split(separator: ".").last.map(String.init) ?? key
    }
}

// MARK: - Brew Codable

private struct BrewCask: Codable {
    let token: String
    let name: [String]?
    let desc: String?
}

private struct BrewFormula: Codable {
    let name: String
    let desc: String?
}
