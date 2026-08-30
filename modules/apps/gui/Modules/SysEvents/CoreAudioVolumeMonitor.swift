// Modules/SysEvents/CoreAudioVolumeMonitor.swift
// Native, event-driven volume/mute monitor (no polling, no osascript/shell).
//
// SketchyBar's volume event is backed by exactly this: CoreAudio property
// listeners on the default output device. We register listeners for:
//   - the default output device changing (kAudioHardwarePropertyDefaultOutputDevice)
//   - that device's volume (kAudioDevicePropertyVolumeScalar) and mute
//     (kAudioDevicePropertyMute)
// and push the latest state to subscribers only when the system reports a change.
// The bar therefore sits idle until macOS mutates the audio graph — the purely
// event-driven model from the architecture brief.
//
// CoreAudio invokes its listener blocks on an internal background serial queue;
// we read the (fast, synchronous) property values there and then hop to a caller
// queue to deliver, so the UI thread never does audio reads.

import CoreAudio
import Foundation

/// Structural model of the current output-volume state.
struct SystemVolumeState: Equatable {
    var volume: Int   // 0...100, mirroring `output volume of get volume settings`
    var muted: Bool

    /// Interpret a scalar float 0...1 as 0...100.
    static func percent(fromScalar value: Float) -> Int {
        let clamped = min(max(value, 0), 1)
        return Int((clamped * 100).rounded())
    }
}

final class CoreAudioVolumeMonitor {

    static let shared = CoreAudioVolumeMonitor()

    /// One active subscriber.
    private final class Observer {
        let queue: DispatchQueue
        let onChange: (SystemVolumeState) -> Void
        init(queue: DispatchQueue, onChange: @escaping (SystemVolumeState) -> Void) {
            self.queue = queue
            self.onChange = onChange
        }
    }

    private var observers: [Observer] = []

    /// CoreAudio notifies us on this background queue; we never block the UI.
    private let audioQueue = DispatchQueue(label: "dev.omanix.coreaudio-volume")

    private var gotSystemListener = false
    private var gotDeviceListeners = false
    private var deviceID: AudioDeviceID = 0

    // MARK: - Subscribing

    /// Begins listening if needed and returns a token. `onChange` fires on `queue`
    /// once immediately (correct initial value) and then on every system change.
    /// Call `cancel(token)` when done.
    func subscribe(queue: DispatchQueue = .main,
                   onChange: @escaping (SystemVolumeState) -> Void) -> AnyObject {
        let observer = Observer(queue: queue, onChange: onChange)
        observers.append(observer)
        start()
        deliverTo(observer)
        return observer
    }

    func cancel(_ token: AnyObject) {
        if let idx = observers.firstIndex(where: { $0 === token }) {
            observers.remove(at: idx)
        }
        if observers.isEmpty {
            stop()
        }
    }

    // MARK: - Listening

    private func start() {
        guard !gotSystemListener else { return }
        // The system object broadcasts default-device changes; a listener here
        // lets us re-attach device-level listeners when the user switches output.
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &addr, audioQueue
        ) { [weak self] _, _ in
            self?.handleSystemDeviceChanged()
        }
        if status != noErr {
            print("CoreAudioVolumeMonitor: could not register system listener (status \(status))")
            return
        }
        gotSystemListener = true
        attachDeviceListeners()
    }

    private func stop() {
        if gotSystemListener {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &addr, audioQueue
            ) { _, _ in }
            gotSystemListener = false
        }
        detachDeviceListeners()
    }

    deinit {
        stop()
    }

    // MARK: - Default device

    private var defaultOutputDevice: AudioDeviceID {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var result = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &result
        )
        return status == noErr ? result : 0
    }

    // MARK: - Device listeners

    /// Attach volume + mute blocks to the current default output device.
    private func attachDeviceListeners() {
        detachDeviceListeners()
        let device = defaultOutputDevice
        guard device != 0 else { return }
        deviceID = device

        var volumeAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let volStatus = AudioObjectAddPropertyListenerBlock(device, &volumeAddr, audioQueue) { [weak self] _, _ in
            self?.handleDeviceChanged()
        }

        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let muteStatus = AudioObjectAddPropertyListenerBlock(device, &muteAddr, audioQueue) { [weak self] _, _ in
            self?.handleDeviceChanged()
        }

        gotDeviceListeners = (volStatus == noErr || muteStatus == noErr)
        if !gotDeviceListeners {
            deviceID = 0
        }
    }

    private func detachDeviceListeners() {
        let device = deviceID
        if gotDeviceListeners, device != 0 {
            var volumeAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(device, &volumeAddr, audioQueue) { _, _ in }

            var muteAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(device, &muteAddr, audioQueue) { _, _ in }
        }
        deviceID = 0
        gotDeviceListeners = false
    }

    // MARK: - Writes (used by the bar's own controls)

    /// Sets the output mute state on the default device natively (no shell). The
    /// resulting CoreAudio property change re-fires the mute listener, so the bar
    /// updates itself without an explicit refresh.
    func setMuted(_ muted: Bool) {
        let device = defaultOutputDevice
        guard device != 0 else { return }
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = muted ? 1 : 0
        _ = AudioObjectSetPropertyData(device, &muteAddr, 0, nil,
                                       UInt32(MemoryLayout<UInt32>.size), &value)
    }

    // MARK: - State read

    /// Current volume + mute model, read synchronously (call on a background queue).
    func readState() -> SystemVolumeState {
        let device = defaultOutputDevice
        guard device != 0 else {
            return SystemVolumeState(volume: 0, muted: false)
        }

        var volume: Float = 0
        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var volSize = UInt32(MemoryLayout<Float>.size)
        let volStatus = AudioObjectGetPropertyData(device, &volAddr, 0, nil, &volSize, &volume)

        var muted: UInt32 = 0
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        let muteStatus = AudioObjectGetPropertyData(device, &muteAddr, 0, nil, &muteSize, &muted)

        return SystemVolumeState(
            volume: SystemVolumeState.percent(fromScalar: volStatus == noErr ? volume : 0),
            muted: muteStatus == noErr ? muted != 0 : false
        )
    }

    // MARK: - Delivery

    private func deliverTo(_ observer: Observer) {
        let state = readState()
        let queue = observer.queue
        let onChange = observer.onChange
        queue.async {
            onChange(state)
        }
    }

    private func deliverToAll() {
        let state = readState()
        // Fan out to the typed bus (BarStateStore + any bus subscribers) first,
        // then to legacy direct observers. Both hops are async on their queues.
        EventBus.shared.publish(volume: state)
        let current = observers
        for observer in current {
            let q = observer.queue, h = observer.onChange
            q.async { h(state) }
        }
    }

    /// Called on `audioQueue` when the volume/mute changes.
    private func handleDeviceChanged() {
        deliverToAll()
    }

    /// Called on `audioQueue` when the default output device changes.
    private func handleSystemDeviceChanged() {
        attachDeviceListeners()
        deliverToAll()
    }
}
