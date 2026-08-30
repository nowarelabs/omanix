// Modules/SysEvents/SystemEvents.swift
// Shared coordinator for native, event-driven system-metric sources.
//
// This is the seed of the reactive/event-driven bar described in the architecture
// brief: instead of pollers that spin osascript/shell every few seconds, we expose
// native API listeners (CoreAudio here; CoreWLAN/IOKit to follow) and let the
// renderers subscribe to change notifications. The bar sits idle until the OS
// actually changes a metric.
//
// Phase 0 delivers the volume source. Later phases grow an explicit publish/
// subscribe event bus here and migrate battery/wifi/clock onto it.

import Foundation

/// Shared access to every native system-metric event source.
enum SystemEvents {

    private static let volumeMonitor = CoreAudioVolumeMonitor()

    /// Subscribe to volume/mute changes. `onChange` fires on the main queue once
    /// immediately (correct initial value, no separate read needed) and then on
    /// every system change. Retain the returned token; call `unobserveVolume` to
    /// release it.
    @discardableResult
    static func observeVolume(_ onChange: @escaping (SystemVolumeState) -> Void) -> AnyObject {
        volumeMonitor.subscribe(queue: .main, onChange: onChange)
    }

    static func unobserveVolume(_ token: AnyObject) {
        volumeMonitor.cancel(token)
    }

    /// Set the output mute state natively (no shell). The native listener fires and
    /// all volume subscribers redraw.
    static func setVolumeMuted(_ muted: Bool) {
        volumeMonitor.setMuted(muted)
    }

    // MARK: - Battery

    @discardableResult
    static func observeBattery(_ onChange: @escaping (BatteryState) -> Void) -> AnyObject {
        BatteryMonitor.shared.subscribe(queue: .main, onChange: onChange)
    }

    static func unobserveBattery(_ token: AnyObject) {
        BatteryMonitor.shared.cancel(token)
    }

    // MARK: - Wi-Fi

    @discardableResult
    static func observeWifi(_ onChange: @escaping (WifiState) -> Void) -> AnyObject {
        WifiMonitor.shared.subscribe(queue: .main, onChange: onChange)
    }

    static func unobserveWifi(_ token: AnyObject) {
        WifiMonitor.shared.cancel(token)
    }

    static func setWifiPowerOn(_ powerOn: Bool) {
        WifiMonitor.shared.setPowerOn(powerOn)
    }

    // MARK: - Clock

    @discardableResult
    static func observeClock(_ onChange: @escaping (Date) -> Void) -> AnyObject {
        ClockTicker.shared.subscribe(queue: .main, onChange: onChange)
    }

    static func unobserveClock(_ token: AnyObject) {
        ClockTicker.shared.cancel(token)
    }
}
