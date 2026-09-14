// Modules/SysEvents/EventBus.swift
// Typed, purely reactive event bus for window events.
//
// The brief calls for a "State-Monad Streams or Virtual DOM-like rendering model"
// where the desktop is a pure function of an internal state machine, fed by native
// listeners over a single event stream. This bus is that stream: WorkspaceManager
// (Owin/Omatiles) publishes window events here, and every consumer subscribes to
// exactly the events it cares about.
//
// The old Omabar status-item sources (CoreAudio, IOKit, CoreWLAN, clock ticker)
// are gone — the native macOS menu bar handles status items now, so this bus
// carries only window lifecycle events.
//
// Thread model: publishers may call `publish` from any queue. Delivery always hops
// to the subscriber's queue (normally .main). Subscription and publishing are
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

/// The strongly-typed window event vocabulary for WorkspaceManager / Omatiles.
enum OmanixEvent: Equatable {
    case windowCreated(WindowCreatedInfo)
    case windowFocused(WindowFocusedInfo)
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

    private var windowCreatedBoxes: [Box<WindowCreatedInfo>] = []
    private var windowFocusedBoxes: [Box<WindowFocusedInfo>] = []
    private var anyBoxes: [Box<OmanixEvent>] = []

    private init() {}

    // MARK: - Typed subscribe (what consumers use)

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
            windowCreatedBoxes.removeAll { $0 === token }
            windowFocusedBoxes.removeAll { $0 === token }
            anyBoxes.removeAll { $0 === token }
        }
    }

    // MARK: - Publish (what sources call)

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

    private func publishAny(_ event: OmanixEvent) {
        let boxes = sync.sync { anyBoxes }
        for box in boxes {
            let q = box.queue, h = box.handler
            q.async { h(event) }
        }
    }
}