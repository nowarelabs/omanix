// Modules/SysEvents/BarState.swift
// Pure, state-monad view of the desktop for the bar.
//
// The brief asks for a "Virtual DOM-like rendering model" where the bar is a
// pure function of an internal state machine. BarState is that machine's snapshot;
// BarStateStore is the single reducer that folds every OmanixEvent from the
// EventBus into a new BarState and fans it out to subscribers. Renderers subscribe
// to the store (or to filtered projections of it) and render purely from the
// delivered state — no shell, no polling, no imperative `sketchybar --set`.
//
// This is the seed of the reactive lifecycle: later phases add window-manager
// events, plugin IPC, and declarative component state into the same reducer.

import Foundation

/// Complete, Equatable snapshot of everything the bar renders.
/// Renderers are pure: `(BarState) -> NSStatusItem` in spirit.
struct BarState: Equatable {
    var volume: SystemVolumeState
    var battery: BatteryState
    var wifi: WifiState
    var clock: Date

    static func initial() -> BarState {
        BarState(
            volume: CoreAudioVolumeMonitor.shared.readState(),
            battery: BatteryMonitor.shared.readState(),
            wifi: WifiMonitor.shared.readState(),
            clock: Date()
        )
    }
}

/// Single owner of BarState. Subscribes to the EventBus, folds events with a
/// pure reducer, and publishes the new state only when it actually changes
/// (so renderers never draw spuriously).
final class BarStateStore {

    static let shared = BarStateStore()

    private let sync = DispatchQueue(label: "dev.omanix.barstate")

    private final class Observer {
        let queue: DispatchQueue
        let handler: (BarState) -> Void
        init(queue: DispatchQueue, handler: @escaping (BarState) -> Void) {
            self.queue = queue
            self.handler = handler
        }
    }

    private var observers: [Observer] = []
    private var busTokens: [AnyObject] = []
    private var monitorKeepAlives: [AnyObject] = []

    private(set) var state: BarState

    private init() {
        state = BarState.initial()
        let bus = EventBus.shared

        // Keep the native sources alive even if no SystemEvents subscriber exists;
        // they publish to the bus on every system change.
        monitorKeepAlives.append(CoreAudioVolumeMonitor.shared.subscribe(queue: .main) { _ in })
        monitorKeepAlives.append(BatteryMonitor.shared.subscribe(queue: .main) { _ in })
        monitorKeepAlives.append(WifiMonitor.shared.subscribe(queue: .main) { _ in })
        monitorKeepAlives.append(ClockTicker.shared.subscribe(queue: .main) { _ in })

        // Each bus subscription updates the store on the store's serial queue,
        // then fans out to observers on their queues. The reducer is pure.
        busTokens.append(bus.subscribeVolume { [weak self] v in self?.reduce(volume: v) })
        busTokens.append(bus.subscribeBattery { [weak self] b in self?.reduce(battery: b) })
        busTokens.append(bus.subscribeWifi { [weak self] w in self?.reduce(wifi: w) })
        busTokens.append(bus.subscribeClock { [weak self] d in self?.reduce(clock: d) })
    }

    // MARK: - Subscribe

    /// Subscribe to every state change. Handler fires on `queue` once immediately
    /// with the current state (so a newly installed renderer draws without waiting).
    @discardableResult
    func subscribe(queue: DispatchQueue = .main, handler: @escaping (BarState) -> Void) -> AnyObject {
        let obs = Observer(queue: queue, handler: handler)
        let current: BarState = sync.sync { state }
        sync.sync { observers.append(obs) }
        queue.async { handler(current) }
        return obs
    }

    /// Convenience: subscribe to a filtered projection (avoids redraws when
    /// unrelated fields change). `areEqual` defaults to `==` on the projection.
    @discardableResult
    func subscribe<P: Equatable>(queue: DispatchQueue = .main,
                                 select: @escaping (BarState) -> P,
                                 handler: @escaping (P) -> Void) -> AnyObject {
        var last: P = sync.sync { select(state) }
        queue.async { handler(last) }
        return subscribe(queue: queue) { newState in
            let proj = select(newState)
            guard proj != last else { return }
            last = proj
            handler(proj)
        }
    }

    func unsubscribe(_ token: AnyObject) {
        sync.sync { observers.removeAll { $0 === token } }
    }

    // MARK: - Pure reducers (one per event type)

    private func reduce(volume: SystemVolumeState) {
        update { $0.volume = volume }
    }

    private func reduce(battery: BatteryState) {
        update { $0.battery = battery }
    }

    private func reduce(wifi: WifiState) {
        update { $0.wifi = wifi }
    }

    private func reduce(clock: Date) {
        update { $0.clock = clock }
    }

    private func update(_ mutate: (inout BarState) -> Void) {
        var newState: BarState?
        var toNotify: [Observer] = []
        sync.sync {
            var next = state
            mutate(&next)
            guard next != state else { return }
            state = next
            newState = next
            toNotify = observers
        }
        guard let state = newState else { return }
        for obs in toNotify {
            let q = obs.queue, h = obs.handler
            q.async { h(state) }
        }
    }
}
