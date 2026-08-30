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
///
/// Phase 2: this facade now routes through the typed EventBus so every event
/// flows via a single reactive stream (the bus) and the pure BarStateStore
/// reducer. The underlying monitors still own their native listeners (CoreAudio,
/// IOKit, CoreWLAN) and publish to the bus; this layer subscribes to the bus
/// and fans out to callers. Direct monitor subscriptions remain for internal
/// wiring; external renderers should prefer SystemEvents or BarStateStore.
enum SystemEvents {

    private static let volumeMonitor = CoreAudioVolumeMonitor.shared
    // Keep-alive tokens so the native monitors stay started while the bus has
    // subscribers. The monitors publish to the bus only when they have at least
    // one direct observer; these dummy observers keep them alive.
    private static var volumeKeepAlive: AnyObject?
    private static var batteryKeepAlive: AnyObject?
    private static var wifiKeepAlive: AnyObject?
    private static var clockKeepAlive: AnyObject?

    private static func ensureVolumeMonitor() {
        if volumeKeepAlive == nil {
            volumeKeepAlive = volumeMonitor.subscribe(queue: .main) { _ in }
        }
    }
    private static func ensureBatteryMonitor() {
        if batteryKeepAlive == nil {
            batteryKeepAlive = BatteryMonitor.shared.subscribe(queue: .main) { _ in }
        }
    }
    private static func ensureWifiMonitor() {
        if wifiKeepAlive == nil {
            wifiKeepAlive = WifiMonitor.shared.subscribe(queue: .main) { _ in }
        }
    }
    private static func ensureClockTicker() {
        if clockKeepAlive == nil {
            clockKeepAlive = ClockTicker.shared.subscribe(queue: .main) { _ in }
        }
    }

    /// Subscribe to volume/mute changes. `onChange` fires on the main queue once
    /// immediately (correct initial value) and then on every bus event.
    @discardableResult
    static func observeVolume(_ onChange: @escaping (SystemVolumeState) -> Void) -> AnyObject {
        ensureVolumeMonitor()
        // Seed with the current state so a newly installed renderer draws
        // without waiting for the next hardware event, then follow the bus.
        let initial = volumeMonitor.readState()
        DispatchQueue.main.async { onChange(initial) }
        return EventBus.shared.subscribeVolume(handler: onChange)
    }

    static func unobserveVolume(_ token: AnyObject) {
        EventBus.shared.unsubscribe(token)
    }

    /// Set the output mute state natively (no shell). The native listener fires and
    /// all volume subscribers redraw.
    static func setVolumeMuted(_ muted: Bool) {
        volumeMonitor.setMuted(muted)
    }

    // MARK: - Battery

    @discardableResult
    static func observeBattery(_ onChange: @escaping (BatteryState) -> Void) -> AnyObject {
        ensureBatteryMonitor()
        let initial = BatteryMonitor.shared.readState()
        DispatchQueue.main.async { onChange(initial) }
        return EventBus.shared.subscribeBattery(handler: onChange)
    }

    static func unobserveBattery(_ token: AnyObject) {
        EventBus.shared.unsubscribe(token)
    }

    // MARK: - Wi-Fi

    @discardableResult
    static func observeWifi(_ onChange: @escaping (WifiState) -> Void) -> AnyObject {
        ensureWifiMonitor()
        let initial = WifiMonitor.shared.readState()
        DispatchQueue.main.async { onChange(initial) }
        return EventBus.shared.subscribeWifi(handler: onChange)
    }

    static func unobserveWifi(_ token: AnyObject) {
        EventBus.shared.unsubscribe(token)
    }

    static func setWifiPowerOn(_ powerOn: Bool) {
        WifiMonitor.shared.setPowerOn(powerOn)
    }

    // MARK: - Clock

    @discardableResult
    static func observeClock(_ onChange: @escaping (Date) -> Void) -> AnyObject {
        ensureClockTicker()
        DispatchQueue.main.async { onChange(Date()) }
        return EventBus.shared.subscribeClock(handler: onChange)
    }

    static func unobserveClock(_ token: AnyObject) {
        EventBus.shared.unsubscribe(token)
    }

    // MARK: - Unified bus access

    /// Direct bus subscription for consumers that want to filter OmanixEvent
    /// themselves (IPC plugins, BarStateStore, logging).
    @discardableResult
    static func observeAny(_ handler: @escaping (OmanixEvent) -> Void) -> AnyObject {
        EventBus.shared.subscribe(handler: handler)
    }

    static func unobserveAny(_ token: AnyObject) {
        EventBus.shared.unsubscribe(token)
    }
}
