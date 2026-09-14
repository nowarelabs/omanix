// Modules/SysEvents/ClockTicker.swift
// Minute-aligned clock tick source.
//
// SketchyBar drives a clock with its `interval` event: a single repeating timer
// fired on a schedule. We replicate that with one recurring Timer aligned to the
// top of each minute, so the bar redraws the clock exactly when its displayed
// minute changes — and sits completely idle between ticks (no second-level churn).
//
// A single process-wide ticker fans out to every subscriber so N clock renderers
// never each create their own timer.

import Foundation

final class ClockTicker {

    private final class Observer {
        let queue: DispatchQueue
        let onChange: (Date) -> Void
        init(queue: DispatchQueue, onChange: @escaping (Date) -> Void) {
            self.queue = queue
            self.onChange = onChange
        }
    }

    private var observers: [Observer] = []
    private var timer: Timer?

    static let shared = ClockTicker()

    private init() {}

    /// Subscribe to minute ticks. `onChange` fires immediately with `Date()` (so
    /// the renderer draws without waiting for the first aligned tick) and then at
    /// the top of every minute. Retain the returned token; call `cancel` to stop.
    @discardableResult
    func subscribe(queue: DispatchQueue = .main,
                   onChange: @escaping (Date) -> Void) -> AnyObject {
        let observer = Observer(queue: queue, onChange: onChange)
        observers.append(observer)
        ensureStarted()
        let queue = observer.queue, handler = observer.onChange
        queue.async { handler(Date()) }
        return observer
    }

    func cancel(_ token: AnyObject) {
        if let idx = observers.firstIndex(where: { $0 === token }) {
            observers.remove(at: idx)
        }
        if observers.isEmpty {
            timer?.invalidate()
            timer = nil
        }
    }

    /// Start one process-wide timer, aligned to the next minute boundary.
    private func ensureStarted() {
        guard timer == nil else { return }
        let secondsToNextMinute = 60 - Double(Calendar.current.component(.second, from: Date()))
            - Double(Calendar.current.component(.nanosecond, from: Date())) / 1_000_000_000
        let fireDate = Date().addingTimeInterval(secondsToNextMinute)
        let t = Timer(fire: fireDate, interval: 60, repeats: true) { [weak self] _ in
            self?.fire()
        }
        // Schedule on the current runloop (main). Use a common mode so the tick
        // still fires while a menu is tracking the mouse.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func fire() {
        let now = Date()
        EventBus.shared.publish(clock: now)
        let current = observers
        for observer in current {
            let queue = observer.queue, handler = observer.onChange
            queue.async { handler(now) }
        }
    }
}
