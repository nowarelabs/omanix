// Modules/SysEvents/BatteryMonitor.swift
// Native, event-driven battery monitor via IOKit (no `pmset -g batt` polling).
//
// Reads state from IOPSCopyPowerSourcesInfo (the same source pmset wraps) and
// registers for the "com.apple.system.powersources" distributed notification so
// it re-reads exactly when macOS reports a power-state change — plugged in /
// unplugged, charging begun or finished, percentage changed. Idle the rest of
// the time, matching the purely event-driven model.

import Foundation
import IOKit.ps

/// Structural model of the current battery state.
struct BatteryState: Equatable {
    var percent: Int
    var charging: Bool
    var onAC: Bool

    static let unknown = BatteryState(percent: -1, charging: false, onAC: false)
}

final class BatteryMonitor {

    private final class Observer {
        let queue: DispatchQueue
        let onChange: (BatteryState) -> Void
        init(queue: DispatchQueue, onChange: @escaping (BatteryState) -> Void) {
            self.queue = queue
            self.onChange = onChange
        }
    }

    private var observers: [Observer] = []
    private var runLoopSource: CFRunLoopSource?

    static let shared = BatteryMonitor()

    private init() {}

    /// Subscribe to power-source changes. `onChange` fires once immediately on
    /// `queue` (correct initial value) and then on each system-reported change.
    @discardableResult
    func subscribe(queue: DispatchQueue = .main,
                   onChange: @escaping (BatteryState) -> Void) -> AnyObject {
        let observer = Observer(queue: queue, onChange: onChange)
        observers.append(observer)
        ensureListening()
        let q = observer.queue, handler = observer.onChange
        let state = readState()
        q.async { handler(state) }
        return observer
    }

    func cancel(_ token: AnyObject) {
        if let idx = observers.firstIndex(where: { $0 === token }) {
            observers.remove(at: idx)
        }
        if observers.isEmpty {
            stopListening()
        }
    }

    // MARK: - Listening

    private func ensureListening() {
        guard runLoopSource == nil else { return }
        let callback: @convention(c) (UnsafeMutableRawPointer?) -> Void = { context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.powerSourcesChanged()
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource(callback, context) else { return }
        let cfSource = source.takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), cfSource, .defaultMode)
        runLoopSource = cfSource
    }

    private func stopListening() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
    }

    private func powerSourcesChanged() {
        let state = readState()
        let current = observers
        for observer in current {
            let q = observer.queue, handler = observer.onChange
            q.async { handler(state) }
        }
    }

    // MARK: - Reading

    /// Current battery state read natively (the same value `pmset -g batt` shows).
    func readState() -> BatteryState {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return .unknown
        }
        guard let sourcesList = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return .unknown
        }
        guard let first = sourcesList.first,
              let desc = IOPSGetPowerSourceDescription(blob, first)?.takeUnretainedValue() as? [String: Any] else {
            return .unknown
        }

        func int(_ key: CFString) -> Int? {
            desc[key as String] as? Int
        }
        func str(_ key: CFString) -> String? {
            desc[key as String] as? String
        }

        let percent = int(kIOPSCurrentCapacityKey as CFString) ?? -1
        let maxCapacity = int(kIOPSMaxCapacityKey as CFString) ?? 100
        let pct = maxCapacity > 0 ? Int((Double(percent) / Double(maxCapacity) * 100).rounded()) : percent

        let state = str(kIOPSPowerSourceStateKey as CFString)
        let isCharging = desc[kIOPSIsChargingKey as String] as? Bool ?? false
        let onAC = state == (kIOPSACPowerValue as String)
        let finished = desc[kIOPSIsChargingKey as String] as? Bool == false && onAC && pct >= 100

        return BatteryState(
            percent: max(0, min(100, pct)),
            charging: isCharging,
            onAC: onAC || finished
        )
    }
}
