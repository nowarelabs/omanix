// Modules/SysEvents/WifiMonitor.swift
// Native, event-driven Wi-Fi monitor via CoreWLAN (no networksetup polling).
//
// Reads power + SSID from CWWiFiClient's default interface and subscribes via
// CWWiFiClient's modern event API (startMonitoringEventWithType + CWEventDelegate)
// so the bar updates exactly when the radio or association changes — idle otherwise.

import CoreWLAN
import Foundation

/// Structural model of the current Wi-Fi state.
struct WifiState: Equatable {
    var powerOn: Bool
    var ssid: String
    var rssi: Int

    static let unknown = WifiState(powerOn: false, ssid: "", rssi: 0)
    static func off() -> WifiState { WifiState(powerOn: false, ssid: "", rssi: 0) }
}

final class WifiMonitor: NSObject, CWEventDelegate {

    private final class Observer {
        let queue: DispatchQueue
        let onChange: (WifiState) -> Void
        init(queue: DispatchQueue, onChange: @escaping (WifiState) -> Void) {
            self.queue = queue
            self.onChange = onChange
        }
    }

    private var observers: [Observer] = []
    private var isMonitoring = false

    static let shared = WifiMonitor()

    private override init() {
        super.init()
    }

    /// The interface to report on (the first available airport interface).
    private var interface: CWInterface? {
        CWWiFiClient.shared().interfaces()?.first
    }

    /// Subscribe to Wi-Fi changes. `onChange` fires once immediately on `queue`.
    @discardableResult
    func subscribe(queue: DispatchQueue = .main,
                   onChange: @escaping (WifiState) -> Void) -> AnyObject {
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

    /// Provide a fresh read via shared client (re-querying the interface each read).
    func readState() -> WifiState {
        guard let iface = interface else { return .unknown }
        let powerOn = iface.powerOn()
        guard powerOn else { return .off() }
        let ssid = iface.ssid() ?? ""
        let rssi = Int(iface.rssiValue())
        return WifiState(powerOn: true, ssid: ssid, rssi: rssi)
    }

    /// Sets the Wi-Fi power state natively via CoreWLAN. The power-change delegate
    /// fires so all wifi subscribers redraw without polling.
    func setPowerOn(_ powerOn: Bool) {
        guard let iface = interface else { return }
        do {
            try iface.setPower(powerOn)
        } catch {
            print("WifiMonitor: setPower(\(powerOn)) failed: \(error)")
        }
    }

    // MARK: - CWEventDelegate

    func powerStateDidChangeForWiFiInterface(withName interfaceName: String) {
        wifiChanged()
    }

    func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        wifiChanged()
    }

    func bssidDidChangeForWiFiInterface(withName interfaceName: String) {
        wifiChanged()
    }

    // MARK: - Monitoring

    private func ensureListening() {
        guard !isMonitoring else { return }
        let client = CWWiFiClient.shared()
        client.delegate = self
        try? client.startMonitoringEvent(with: .powerDidChange)
        try? client.startMonitoringEvent(with: .ssidDidChange)
        try? client.startMonitoringEvent(with: .bssidDidChange)
        isMonitoring = true
    }

    private func stopListening() {
        guard isMonitoring else { return }
        let client = CWWiFiClient.shared()
        try? client.stopMonitoringEvent(with: .powerDidChange)
        try? client.stopMonitoringEvent(with: .ssidDidChange)
        try? client.stopMonitoringEvent(with: .bssidDidChange)
        if client.delegate === self {
            client.delegate = nil
        }
        isMonitoring = false
    }

    private func wifiChanged() {
        let state = readState()
        let current = observers
        for observer in current {
            let q = observer.queue, handler = observer.onChange
            q.async { handler(state) }
        }
    }
}
