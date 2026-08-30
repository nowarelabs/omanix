// Modules/SysEvents/WifiMonitor.swift
// Native, event-driven Wi-Fi monitor via CoreWLAN (no networksetup polling).
//
// Reads power + SSID from CWWiFiClient's default interface and subscribes to
// CoreWLAN's SSID/power notifications so the bar updates exactly when the network
// or radio changes — idle the rest of the time.

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

final class WifiMonitor {

    private final class Observer {
        let queue: DispatchQueue
        let onChange: (WifiState) -> Void
        init(queue: DispatchQueue, onChange: @escaping (WifiState) -> Void) {
            self.queue = queue
            self.onChange = onChange
        }
    }

    private var observers: [Observer] = []
    private var handles: [NSObjectProtocol] = []

    static let shared = WifiMonitor()

    private init() {}

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

    /// Provide a fresh read via shared client (technically a no-arg call returns
    /// the same client; re-querying the interface each read is cheap and current).
    func readState() -> WifiState {
        guard let iface = interface else { return .unknown }
        let powerOn = iface.powerOn()
        guard powerOn else { return .off() }
        let ssid = iface.ssid() ?? ""
        let rssi = Int(iface.rssiValue())
        return WifiState(powerOn: true, ssid: ssid, rssi: rssi)
    }

    /// Sets the Wi-Fi power state natively via CoreWLAN. The power-change
    /// notification re-fires so all wifi subscribers redraw without polling.
    func setPowerOn(_ powerOn: Bool) {
        guard let iface = interface else { return }
        do {
            try iface.setPower(powerOn)
        } catch {
            print("WifiMonitor: setPower(\(powerOn)) failed: \(error)")
        }
    }

    // MARK: - Notifications

    private func ensureListening() {
        guard handles.isEmpty else { return }
        let nc = NotificationCenter.default
        var newHandles: [NSObjectProtocol] = []
        // CoreWLAN posts CW*DidChange notifications when the link/power changes.
        newHandles.append(nc.addObserver(forName: NSNotification.Name.CWSSIDDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.wifiChanged()
        })
        newHandles.append(nc.addObserver(forName: NSNotification.Name.CWPowerDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.wifiChanged()
        })
        newHandles.append(nc.addObserver(forName: NSNotification.Name.CWBSSIDDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.wifiChanged()
        })
        handles = newHandles
    }

    private func stopListening() {
        for handle in handles {
            NotificationCenter.default.removeObserver(handle)
        }
        handles.removeAll()
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
