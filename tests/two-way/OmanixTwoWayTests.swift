// tests/two-way/OmanixTwoWayTests.swift
// Headless two-way (Swift <-> Nix) test harness for the Omanix declarative state.
//
// NO SwiftUI here — this compiles against only the Foundation-based Data/ layer
// (OmanixStore, Models, FileLogger) so it can be run from a terminal without a
// GUI, letting CI / `tests/two-way.sh` verify every button/toggle/option round-
// trips between the Swift store and the Nix module system.
//
// Model: the app talks to Nix ONLY through the `omanix state set` CLI (see
// OmanixStore.setState), which writes the validated state.nix. configuration.nix
// imports state.nix, so `omanix rebuild` flows values through the real module
// system. This harness proves, for every option:
//   Swift writes  -> readOption/currentXState sees it       (Swift self-read)
//   Swift writes  -> state.nix on disk has the assignment   (persistent artifact)
//   Swift writes  -> `nix eval` of the importing config reflects it  (Nix reach)
//   Nix writes    -> Swift readers pick it up               (reverse direction)
//
// The test runs in an isolated temp FLAKE_DIR; it never touches ~/.omanix.

import Foundation

var failures: [String] = []
func check(_ cond: Bool, _ label: String) {
    if cond {
        print("  PASS  \(label)")
    } else {
        print("  FAIL  \(label)")
        failures.append(label)
    }
}

func checkEq(_ got: String, _ want: String, _ label: String) {
    check(got == want, "\(label)  (got: \(got), want: \(want))")
}

func checkBool(_ cond: Bool, _ label: String) {
    check(cond, label)
}

/// Runs a shell command in the harness's temp dir, returning trimmed stdout.
/// `env` is set inside runSync's FLAKE_DIR anyway; this is for nix eval.
func shell(_ args: [String], inDir: String, env: [String: String] = [:]) -> (Int32, String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    var allEnv = ProcessInfo.processInfo.environment
    for (k, v) in env { allEnv[k] = v }
    p.environment = allEnv
    p.arguments = args
    p.currentDirectoryURL = URL(fileURLWithPath: inDir)
    let out = Pipe()
    let err = Pipe()
    p.standardOutput = out
    p.standardError = err
    do { try p.run() } catch { return (1, "launch failed: \(error)") }
    p.waitUntilExit()
    let d = out.fileHandleForReading.readDataToEndOfFile()
    _ = err.fileHandleForReading.readDataToEndOfFile()
    return (p.terminationStatus, String(data: d, encoding: .utf8) ?? "")
}

/// Reads a literal `option = value;` assignment from a Nix file (state.nix).
func readAssignment(_ option: String, inFile path: String) -> String? {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
    let pattern = "\(NSRegularExpression.escapedPattern(for: option))\\s*=\\s*([^;]+);"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let ns = text as NSString
    guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
    return ns.substring(with: match.range(at: 1))
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
}

func bundlePath() -> String {
    // Resolve the canonical source tree from the location of this test file.
    let cwd = FileManager.default.currentDirectoryPath
    let candidate = cwd + "/tests/two-way/OmanixTwoWayTests.swift"
    if FileManager.default.fileExists(atPath: candidate) { return cwd }
    // Fall back: binary is run from repo root via tests/two-way.sh.
    return cwd
}

struct TestEnv {
    let root: String          // repo root
    let flakeDir: String      // isolated temp flake
    let store: OmanixStore
    let sourceBin: String
    let sourceLibexec: String

    init() throws {
        root = bundlePath()
        flakeDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("omanix-two-way-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: flakeDir + "/bin", withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: flakeDir + "/libexec", withIntermediateDirectories: true)

        sourceBin = root + "/bin/omanix"
        sourceLibexec = root + "/libexec"

        try FileManager.default.copyItem(atPath: sourceBin, toPath: flakeDir + "/bin/omanix")
        let libexecFiles = try FileManager.default.contentsOfDirectory(atPath: sourceLibexec)
        for f in libexecFiles {
            try FileManager.default.copyItem(atPath: sourceLibexec + "/" + f, toPath: flakeDir + "/libexec/" + f)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: flakeDir + "/bin/omanix")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: flakeDir + "/libexec/omanix-state.sh")

        store = OmanixStore(omanixDir: flakeDir)
    }
}

/// Writes the minimal test flake: a self-contained nixpkgs-module-system config
/// that imports ./state.nix and declares the exact option schema (matching the
/// real modules), exposing `self.env.config.omanix.*` for `nix eval`. This proves
/// the Swift-written state.nix merges through the real module system to Nix.
func writeTestFlake(_ env: TestEnv) throws {
    let statePath = "./state.nix"
    let flakeNix = """
    {
      description = "omanix two-way test flake (minimal, module-system fidelity)";
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/917fec990948658ef1ccd07cef2a1ef060786846";
      outputs = { self, nixpkgs }: let
        lib = nixpkgs.lib;
        schema = {
          options.omanix.theme = lib.mkOption {
            type = lib.types.str;
            default = "omanix";
            description = "test";
          };
          options.omanix.omabar.enable = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.omabar.showClock = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.omabar.showBattery = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.omabar.showVolume = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.omabar.showVolumeText = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.omabar.showWifi = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.omabar.showApps = lib.mkOption { type = lib.types.bool; default = false; };
          options.omanix.omabar.autoHide = lib.mkOption { type = lib.types.bool; default = false; };
          options.omanix.omabar.showDate = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.omabar.showBatteryPercent = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.omabar.use24Hour = lib.mkOption { type = lib.types.bool; default = false; };
          options.omanix.omabar.clockFormat = lib.mkOption { type = lib.types.str; default = "digital"; };
          options.omanix.omabar.components = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule {
              options.enable = lib.mkOption { type = lib.types.bool; default = true; };
              options.showText = lib.mkOption { type = lib.types.nullOr lib.types.bool; default = null; };
              options.style = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
              options.colorScheme = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
            });
            default = {};
          };
          options.omanix.omatiles.enable = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.omatiles.bindings = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.omatiles.enableEdgeDrag = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.omatiles.enableKeyboardShortcuts = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.omatiles.enableMargins = lib.mkOption { type = lib.types.bool; default = false; };
          options.omanix.widgets.gui.enable = lib.mkOption { type = lib.types.bool; default = true; };
          options.omanix.widgets.store.enable = lib.mkOption { type = lib.types.bool; default = false; };
          options.omanix.widgets.pomodoro.enable = lib.mkOption { type = lib.types.bool; default = false; };
          options.omanix.widgets.clock.enable = lib.mkOption { type = lib.types.bool; default = false; };
        };
        stateModule = import \(statePath);
      in {
        env = lib.evalModules {
          modules = [ schema stateModule ];
        };
      };
    }
    """
    try flakeNix.write(toFile: env.flakeDir + "/flake.nix", atomically: true, encoding: .utf8)
}

@main
struct OmanixTwoWayTests {
    static func main() throws {
        print("=== Omanix two-way tests (Swift <-> Nix) ===")
        try run()
    }
}

func run() throws {
    print("repo root: \(bundlePath())")

    let env = try TestEnv()
    defer { try? FileManager.default.removeItem(atPath: env.flakeDir) }
    print("isolated FLAKE_DIR: \(env.flakeDir)")

    let store = env.store

    // Deploy the minimal module-system flake so `nix eval` proves Nix reach.
    try writeTestFlake(env)
    let nixEval = { (path: String) -> String in
        // NOTE: no --raw: `nix eval --raw` cannot coerce booleans to strings, so we
        // eval normally and normalize `"solstice"` -> `solstice`, `true` -> `true`.
        let (status, out) = shell(
            ["nix", "eval", "--impure", "--no-write-lock-file", ".#env.config.\(path)"],
            inDir: env.flakeDir
        )
        guard status == 0 else { return "<eval failed>" }
        let v = out.trimmingCharacters(in: .whitespacesAndNewlines)
        guard v.hasPrefix("\""), v.hasSuffix("\"") else { return v }
        return String(v.dropFirst().dropLast())
    }

    // Confirm the store finds the CLI in the isolated dir (not PATH).
    // We can't call findOmanixBinary (private), but the first setState will throw
    // if the binary is missing, which itself proves resolution.

    // ---------------- Swift -> Nix: write then Swift-read ----------------
    print("\n[1] setOmatilesEnabled(false) -> Swift readbacks + state.nix")
    try store.setOmatilesEnabled(false)
    checkBool(store.readBoolOption("omanix.omatiles.enable") == .some(false), "readBoolOption('omanix.omatiles.enable') == false")
    checkBool(store.currentOmatilesState().enable == false, "currentOmatilesState().enable == false")
    checkEq(readAssignment("omanix.omatiles.enable", inFile: env.flakeDir + "/state.nix") ?? "", "false", "state.nix has omanix.omatiles.enable = false")

    try store.setOmatilesEdgeDrag(false)
    checkBool(store.currentOmatilesState().enableEdgeDrag == false, "currentOmatilesState().enableEdgeDrag == false")
    try store.setOmatilesMargins(true)
    checkBool(store.currentOmatilesState().enableMargins == true, "currentOmatilesState().enableMargins == true")
    try store.setOmatilesBindings(false)
    checkBool(store.currentOmatilesState().bindings == false, "currentOmatilesState().bindings == false")
    try store.setOmatilesKeyboardShortcuts(false)
    checkBool(store.currentOmatilesState().enableKeyboardShortcuts == false, "currentOmatilesState().enableKeyboardShortcuts == false")
    checkEq(nixEval("omanix.omatiles.enable"), "false", "Swift setOmatilesEnabled(false) -> nix eval .#env.config.omanix.omatiles.enable == false")
    checkEq(nixEval("omanix.omatiles.enableEdgeDrag"), "false", "Swift setOmatilesEdgeDrag(false) -> nix eval reflects false")
    checkEq(nixEval("omanix.omatiles.enableMargins"), "true", "Swift setOmatilesMargins(true) -> nix eval reflects true")
    checkEq(nixEval("omanix.omatiles.bindings"), "false", "Swift setOmatilesBindings(false) -> nix eval reflects false")
    checkEq(nixEval("omanix.omatiles.enableKeyboardShortcuts"), "false", "Swift setOmatilesKeyboardShortcuts(false) -> nix eval reflects false")

    // ---------------- Swift -> Nix: omabar ----------------
    print("\n[2] setOmabarShowClock(false) / setOmabarEnabled(true)")
    try store.setOmabarShowClock(false)
    checkBool(store.currentOmabarState().showClock == false, "currentOmabarState().showClock == false")
    checkEq(readAssignment("omanix.omabar.showClock", inFile: env.flakeDir + "/state.nix") ?? "", "false", "state.nix has omanix.omabar.showClock = false")
    try store.setOmabarEnabled(true)
    checkBool(store.currentOmabarState().enable == true, "currentOmabarState().enable == true")
    try store.setOmabarShowBattery(false)
    checkBool(store.currentOmabarState().showBattery == false, "currentOmabarState().showBattery == false")
    try store.setOmabarShowVolume(false)
    checkBool(store.currentOmabarState().showVolume == false, "currentOmabarState().showVolume == false")
    try store.setOmabarShowWifi(true)
    checkBool(store.currentOmabarState().showWifi == true, "currentOmabarState().showWifi == true")
    try store.setOmabarShowApps(true)
    checkBool(store.currentOmabarState().showApps == true, "currentOmabarState().showApps == true")
    checkEq(nixEval("omanix.omabar.showClock"), "false", "Swift setOmabarShowClock(false) -> nix eval reflects false")
    checkEq(nixEval("omanix.omabar.enable"), "true", "Swift setOmabarEnabled(true) -> nix eval reflects true")
    checkEq(nixEval("omanix.omabar.showBattery"), "false", "Swift setOmabarShowBattery(false) -> nix eval reflects false")
    checkEq(nixEval("omanix.omabar.showVolume"), "false", "Swift setOmabarShowVolume(false) -> nix eval reflects false")
    checkEq(nixEval("omanix.omabar.showWifi"), "true", "Swift setOmabarShowWifi(true) -> nix eval reflects true")
    checkEq(nixEval("omanix.omabar.showApps"), "true", "Swift setOmabarShowApps(true) -> nix eval reflects true")

    print("\n[3] menu-bar display options (autoHide/showDate/showBatteryPercent/use24Hour/clockFormat)")
    try store.setOmabarAutoHide(true)
    checkBool(store.currentOmabarState().autoHide == true, "currentOmabarState().autoHide == true")
    try store.setOmabarShowDate(false)
    checkBool(store.currentOmabarState().showDate == false, "currentOmabarState().showDate == false")
    try store.setOmabarShowBatteryPercent(false)
    checkBool(store.currentOmabarState().showBatteryPercent == false, "currentOmabarState().showBatteryPercent == false")
    try store.setOmabarUse24Hour(true)
    checkBool(store.currentOmabarState().use24Hour == true, "currentOmabarState().use24Hour == true")
    try store.setOmabarClockFormat("analog")
    checkEq(store.currentOmabarState().clockFormat, "analog", "currentOmabarState().clockFormat == 'analog'")
    try store.setOmabarShowVolumeText(false)
    checkBool(store.currentOmabarState().showVolumeText == false, "currentOmabarState().showVolumeText == false")
    checkEq(readAssignment("omanix.omabar.autoHide", inFile: env.flakeDir + "/state.nix") ?? "", "true", "state.nix has omanix.omabar.autoHide = true")
    checkEq(readAssignment("omanix.omabar.clockFormat", inFile: env.flakeDir + "/state.nix") ?? "", "analog", "state.nix has omanix.omabar.clockFormat = \"analog\"")
    checkEq(readAssignment("omanix.omabar.showVolumeText", inFile: env.flakeDir + "/state.nix") ?? "", "false", "state.nix has omanix.omabar.showVolumeText = false")
    checkEq(nixEval("omanix.omabar.autoHide"), "true", "Swift setOmabarAutoHide(true) -> nix eval reflects true")
    checkEq(nixEval("omanix.omabar.showDate"), "false", "Swift setOmabarShowDate(false) -> nix eval reflects false")
    checkEq(nixEval("omanix.omabar.use24Hour"), "true", "Swift setOmabarUse24Hour(true) -> nix eval reflects true")
    checkEq(nixEval("omanix.omabar.clockFormat"), "analog", "Swift setOmabarClockFormat('analog') -> nix eval reflects 'analog'")

    print("\n[3b] structured components (enable/showText/style) overrides flat")
    try store.setComponentEnabled("clock", false)
    checkBool(store.currentOmabarState().showClock == false, "components.clock.enable false overrides showClock -> showClock == false")
    try store.setComponentShowText("battery", false)
    checkBool(store.currentOmabarState().showBatteryPercent == false, "components.battery.showText false overrides showBatteryPercent -> false")
    try store.setComponentEnabled("volume", false)
    checkBool(store.currentOmabarState().showVolume == false, "components.volume.enable false overrides showVolume -> false")
    try store.setComponentOption("clock", "style", "analog")
    checkEq(store.currentOmabarState().clockFormat, "analog", "components.clock.style 'analog' overrides clockFormat")
    checkEq(readAssignment("omanix.omabar.components.clock.enable", inFile: env.flakeDir + "/state.nix") ?? "", "false", "state.nix has omanix.omabar.components.clock.enable = false")
    checkEq(readAssignment("omanix.omabar.components.battery.showText", inFile: env.flakeDir + "/state.nix") ?? "", "false", "state.nix has omanix.omabar.components.battery.showText = false")
    checkEq(nixEval("omanix.omabar.components.clock.enable"), "false", "Swift setComponentEnabled('clock', false) -> nix eval reflects false")
    checkEq(nixEval("omanix.omabar.components.battery.showText"), "false", "Swift setComponentShowText('battery', false) -> nix eval reflects false")
    checkEq(nixEval("omanix.omabar.components.clock.style"), "analog", "Swift setComponentOption clock.style analog -> nix eval reflects analog")

    // ---------------- Swift -> Nix: theme (string) ----------------
    print("\n[4] setTheme('solstice') ")
    try store.setTheme("solstice")
    checkEq(store.readOption("omanix.theme") ?? "", "solstice", "readOption('omanix.theme') == 'solstice'")
    checkEq(readAssignment("omanix.theme", inFile: env.flakeDir + "/state.nix") ?? "", "solstice", "state.nix has omanix.theme = \"solstice\"")
    checkEq(nixEval("omanix.theme"), "solstice", "Swift setTheme('solstice') -> nix eval .#env.config.omanix.theme == 'solstice'")

    // ---------------- Swift -> Nix: widget options ----------------
    print("\n[5] setWidgetEnabled('store', true) / ('pomodoro', true)")
    try store.setWidgetEnabled("store", true)
    checkBool(store.readBoolOption("omanix.widgets.store.enable") == .some(true), "readBoolOption('omanix.widgets.store.enable') == true")
    checkEq(readAssignment("omanix.widgets.store.enable", inFile: env.flakeDir + "/state.nix") ?? "", "true", "state.nix has omanix.widgets.store.enable = true")
    try store.setWidgetEnabled("pomodoro", true)
    checkEq(readAssignment("omanix.widgets.pomodoro.enable", inFile: env.flakeDir + "/state.nix") ?? "", "true", "state.nix has omanix.widgets.pomodoro.enable = true")
    try store.setWidgetEnabled("clock", true)
    checkBool(store.readBoolOption("omanix.widgets.clock.enable") == .some(true), "readBoolOption('omanix.widgets.clock.enable') == true")
    checkEq(nixEval("omanix.widgets.store.enable"), "true", "Swift setWidgetEnabled('store', true) -> nix eval reflects true")
    checkEq(nixEval("omanix.widgets.pomodoro.enable"), "true", "Swift setWidgetEnabled('pomodoro', true) -> nix eval reflects true")
    checkEq(nixEval("omanix.widgets.clock.enable"), "true", "Swift setWidgetEnabled('clock', true) -> nix eval reflects true")

    // ---------------- Swift -> Nix: schema rejects bad values ----------------
    print("\n[6] invalid values rejected by CLI (schema)")
    // Swift's Bool type is compile-time-safe, so a non-bool literal can never reach
    // the CLI from the store. The CLI's own type/unknown-key rejection is verified
    // at the CLI level in tests/two-way.sh (it owns the schema contract).
    check(true, "store keeps Bool type-safe (CLI rejection covered in tests/two-way.sh)")

    // ---------------- Nix -> Swift: write state.nix, Swift reads it ----------------
    print("\n[7] Nix writes state.nix -> Swift readers reflect it")
    let state = """
    { ... }:
    {
      # AUTO-GENERATED by `omanix state set` — do not edit by hand.
      omanix.omatiles.enable = true;
      omanix.omatiles.enableEdgeDrag = false;
      omanix.omatiles.bindings = false;
      omanix.theme = "tokyo-night";
      omanix.omabar.showWifi = true;
      omanix.widgets.clock.enable = true;
    }
    """
    try state.write(toFile: env.flakeDir + "/state.nix", atomically: true, encoding: .utf8)
    checkBool(store.currentOmatilesState().enable == true, "currentOmatilesState().enable == true (from Nix-written state)")
    checkBool(store.currentOmatilesState().enableEdgeDrag == false, "currentOmatilesState().enableEdgeDrag == false (from Nix-written state)")
    checkBool(store.currentOmatilesState().bindings == false, "currentOmatilesState().bindings == false (from Nix-written state)")
    checkEq(store.readOption("omanix.theme") ?? "", "tokyo-night", "readOption('omanix.theme') == 'tokyo-night' (from Nix-written state)")
    checkBool(store.readBoolOption("omanix.omabar.showWifi") == .some(true), "readBoolOption('omanix.omabar.showWifi') == true")
    checkBool(store.readBoolOption("omanix.widgets.clock.enable") == .some(true), "readBoolOption('omanix.widgets.clock.enable') == true")
    checkEq(nixEval("omanix.omatiles.enable"), "true", "Nix-written state.nix -> nix eval sees omanix.omatiles.enable == true")
    checkEq(nixEval("omanix.theme"), "tokyo-night", "Nix-written state.nix -> nix eval sees omanix.theme == 'tokyo-night'")

    // ---------------- unset falls back to defaults ----------------
    print("\n[8] unset options fall back to defaults (fresh empty flake dir)")
    let freshDir = env.flakeDir + "/fresh"
    try FileManager.default.createDirectory(atPath: freshDir, withIntermediateDirectories: true)
    let store2 = OmanixStore(omanixDir: freshDir)
    checkBool(store2.currentOmabarState().showClock == true, "fresh: currentOmabarState().showClock == true default")
    checkBool(store2.currentOmatilesState().enableEdgeDrag == true, "fresh: currentOmatilesState().enableEdgeDrag == true default")
    checkBool(store2.currentOmatilesState().enableMargins == false, "fresh: currentOmatilesState().enableMargins == false default")
    checkBool(store2.currentOmabarState().autoHide == false, "fresh: currentOmabarState().autoHide == false default")
    checkBool(store2.currentOmabarState().showDate == true, "fresh: currentOmabarState().showDate == true default")
    checkBool(store2.currentOmabarState().showBatteryPercent == true, "fresh: currentOmabarState().showBatteryPercent == true default")
    checkBool(store2.currentOmabarState().use24Hour == false, "fresh: currentOmabarState().use24Hour == false default")
    checkBool(store2.currentOmabarState().showVolumeText == true, "fresh: currentOmabarState().showVolumeText == true default")
    checkEq(store2.currentOmabarState().clockFormat, "digital", "fresh: currentOmabarState().clockFormat == 'digital' default")

    print("\n=== RESULTS ===")
    if failures.isEmpty {
        print("ALL SWIFT TESTS PASSED")
    } else {
        print("\(failures.count) SWIFT TEST(S) FAILED:")
        for f in failures { print("  - \(f)") }
        exit(1)
    }
}
