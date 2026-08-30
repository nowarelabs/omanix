// Modules/SysEvents/EventBus.swift
// Typed, purely reactive event bus — the subscription backbone of the bar.
//
// The brief calls for a "State-Monad Streams or Virtual DOM-like rendering model"
// where the bar is a pure function of an internal state machine, and SketchyBar's
// shell-trigger loop is replaced by native listeners feeding a single event stream.
// This bus is that stream: every native source (CoreAudio, IOKit, CoreWLAN, Clock)
// publishes a typed event here, and every renderer subscribes to exactly the events
// it cares about. The bar sits idle until the bus delivers; no polling, no shell.
//
// Thread model: publishers may call `publish` from any queue (CoreAudio's audioQueue,
// IOKit's run-loop source, etc.). Delivery always hops to the subscriber's queue
// (normally .main for NSStatusItem updates). Subscription and publishing are
// synchronized on a private serial queue so observers can be added/removed from any
// thread safely.

import Foundation

struct WindowCreatedInfo: Equatable {
    var pid: pid_t
    var bundleID: String
    var workspace: String?
}

struct WindowFocusedInfo: Equatable {
    var pid: pid_t
    var bundleID: String
}

struct PluginUpdateInfo: Equatable {
    var id: String
    var title: String
    var image: String?
    var payload: [String: String]?

    static func from(json: [String: Any]) -> PluginUpdateInfo? {
        let params: [String: Any]
        if let p = json["params"] as? [String: Any] {
            params = p
        } else if json["id"] != nil {
            params = json
        } else {
            return nil
        }
        guard let id = params["id"] as? String, let title = params["title"] as? String else { return nil }
        let image = params["image"] as? String
        var payload: [String: String]?
        if let raw = params["payload"] as? [String: Any] {
            payload = raw.mapValues { "\($0)" }
        }
        return PluginUpdateInfo(id: id, title: title, image: image, payload: payload)
    }
}

/// The single, strongly-typed event vocabulary the whole desktop speaks.
/// Add new cases here as the desktop grows (window events, plugin IPC, etc.).
enum OmanixEvent: Equatable {
    case volume(SystemVolumeState)
    case battery(BatteryState)
    case wifi(WifiState)
    case clock(Date)
    case windowCreated(WindowCreatedInfo)
    case windowFocused(WindowFocusedInfo)
    case pluginUpdate(PluginUpdateInfo)
}

final class EventBus {

    static let shared = EventBus()

    private let sync = DispatchQueue(label: "dev.omanix.eventbus")

    // MARK: - Observer boxes (per-type so dispatch is O(subscribers) not O(all))

    private final class Box<T> {
        let queue: DispatchQueue
        let handler: (T) -> Void
        init(queue: DispatchQueue, handler: @escaping (T) -> Void) {
            self.queue = queue
            self.handler = handler
        }
    }

    private var volumeBoxes: [Box<SystemVolumeState>] = []
    private var batteryBoxes: [Box<BatteryState>] = []
    private var wifiBoxes: [Box<WifiState>] = []
    private var clockBoxes: [Box<Date>] = []
    private var windowCreatedBoxes: [Box<WindowCreatedInfo>] = []
    private var windowFocusedBoxes: [Box<WindowFocusedInfo>] = []
    private var pluginUpdateBoxes: [Box<PluginUpdateInfo>] = []
    private var anyBoxes: [Box<OmanixEvent>] = []

    private init() {}

    // MARK: - Typed subscribe (what renderers use)

    @discardableResult
    func subscribeVolume(queue: DispatchQueue = .main,
                         handler: @escaping (SystemVolumeState) -> Void) -> AnyObject {
        let box = Box(queue: queue, handler: handler)
        sync.sync { volumeBoxes.append(box) }
        return box
    }

    @discardableResult
    func subscribeBattery(queue: DispatchQueue = .main,
                          handler: @escaping (BatteryState) -> Void) -> AnyObject {
        let box = Box(queue: queue, handler: handler)
        sync.sync { batteryBoxes.append(box) }
        return box
    }

    @discardableResult
    func subscribeWifi(queue: DispatchQueue = .main,
                       handler: @escaping (WifiState) -> Void) -> AnyObject {
        let box = Box(queue: queue, handler: handler)
        sync.sync { wifiBoxes.append(box) }
        return box
    }

    @discardableResult
    func subscribeClock(queue: DispatchQueue = .main,
                       handler: @escaping (Date) -> Void) -> AnyObject {
        let box = Box(queue: queue, handler: handler)
        sync.sync { clockBoxes.append(box) }
        return box
    }

    @discardableResult
    func subscribeWindowCreated(queue: DispatchQueue = .main,
                                handler: @escaping (WindowCreatedInfo) -> Void) -> AnyObject {
        let box = Box(queue: queue, handler: handler)
        sync.sync { windowCreatedBoxes.append(box) }
        return box
    }

    @discardableResult
    func subscribeWindowFocused(queue: DispatchQueue = .main,
                                handler: @escaping (WindowFocusedInfo) -> Void) -> AnyObject {
        let box = Box(queue: queue, handler: handler)
        sync.sync { windowFocusedBoxes.append(box) }
        return box
    }

    @discardableResult
    func subscribePluginUpdate(queue: DispatchQueue = .main,
                               handler: @escaping (PluginUpdateInfo) -> Void) -> AnyObject {
        let box = Box(queue: queue, handler: handler)
        sync.sync { pluginUpdateBoxes.append(box) }
        return box
    }

    /// Subscribe to every event (useful for the state store, logging, IPC).
    @discardableResult
    func subscribe(queue: DispatchQueue = .main,
                   handler: @escaping (OmanixEvent) -> Void) -> AnyObject {
        let box = Box(queue: queue, handler: handler)
        sync.sync { anyBoxes.append(box) }
        return box
    }

    func unsubscribe(_ token: AnyObject) {
        sync.sync {
            volumeBoxes.removeAll { $0 === token }
            batteryBoxes.removeAll { $0 === token }
            wifiBoxes.removeAll { $0 === token }
            clockBoxes.removeAll { $0 === token }
            windowCreatedBoxes.removeAll { $0 === token }
            windowFocusedBoxes.removeAll { $0 === token }
            pluginUpdateBoxes.removeAll { $0 === token }
            anyBoxes.removeAll { $0 === token }
        }
    }

    // MARK: - Publish (what sources call)

    func publish(volume: SystemVolumeState) {
        let boxes = sync.sync { volumeBoxes }
        let event = OmanixEvent.volume(volume)
        for box in boxes {
            let q = box.queue, h = box.handler
            q.async { h(volume) }
        }
        publishAny(event)
    }

    func publish(battery: BatteryState) {
        let boxes = sync.sync { batteryBoxes }
        let event = OmanixEvent.battery(battery)
        for box in boxes {
            let q = box.queue, h = box.handler
            q.async { h(battery) }
        }
        publishAny(event)
    }

    func publish(wifi: WifiState) {
        let boxes = sync.sync { wifiBoxes }
        let event = OmanixEvent.wifi(wifi)
        for box in boxes {
            let q = box.queue, h = box.handler
            q.async { h(wifi) }
        }
        publishAny(event)
    }

    func publish(clock date: Date) {
        let boxes = sync.sync { clockBoxes }
        let event = OmanixEvent.clock(date)
        for box in boxes {
            let q = box.queue, h = box.handler
            q.async { h(date) }
        }
        publishAny(event)
    }

    func publish(windowCreated info: WindowCreatedInfo) {
        let boxes = sync.sync { windowCreatedBoxes }
        let event = OmanixEvent.windowCreated(info)
        for box in boxes {
            let q = box.queue, h = box.handler
            q.async { h(info) }
        }
        publishAny(event)
    }

    func publish(windowFocused info: WindowFocusedInfo) {
        let boxes = sync.sync { windowFocusedBoxes }
        let event = OmanixEvent.windowFocused(info)
        for box in boxes {
            let q = box.queue, h = box.handler
            q.async { h(info) }
        }
        publishAny(event)
    }

    func publish(pluginUpdate info: PluginUpdateInfo) {
        let boxes = sync.sync { pluginUpdateBoxes }
        let event = OmanixEvent.pluginUpdate(info)
        for box in boxes {
            let q = box.queue, h = box.handler
            q.async { h(info) }
        }
        publishAny(event)
    }

    private func publishAny(_ event: OmanixEvent) {
        let boxes = sync.sync { anyBoxes }
        for box in boxes {
            let q = box.queue, h = box.handler
            q.async { h(event) }
        }
    }
}
