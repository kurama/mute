import CoreAudio
import Foundation

protocol AudioHardwareObservation: AnyObject {
    func invalidate()
}

protocol InputDeviceActivitySource: AnyObject {
    func inputDeviceIDs() -> Set<AudioDeviceID>
    func isInputActive(on deviceIDs: Set<AudioDeviceID>) -> Bool
    func observeDeviceList(_ handler: @escaping () -> Void) -> AudioHardwareObservation?
    func observeRunningState(of deviceID: AudioDeviceID, handler: @escaping () -> Void) -> AudioHardwareObservation?
}

enum InputActivityResolver {
    static func isActive(
        monitoredDeviceIDs: Set<AudioDeviceID>,
        activeProcessInputDeviceIDs: Set<AudioDeviceID>?,
        runningDeviceIDs: Set<AudioDeviceID>
    ) -> Bool {
        let activeDeviceIDs = activeProcessInputDeviceIDs ?? runningDeviceIDs
        return !monitoredDeviceIDs.isDisjoint(with: activeDeviceIDs)
    }
}

final class MicrophoneActivityMonitor {

    var onActivityChanged: ((Bool) -> Void)?

    private let source: InputDeviceActivitySource
    private var deviceListObservation: AudioHardwareObservation?
    private var runningObservations: [AudioDeviceID: AudioHardwareObservation] = [:]
    private var monitoredDeviceIDs: Set<AudioDeviceID> = []
    private var isStarted = false
    private(set) var isActive = false

    init(source: InputDeviceActivitySource = CoreAudioInputDeviceSource()) {
        self.source = source
    }

    deinit {
        stop()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        deviceListObservation = source.observeDeviceList { [weak self] in
            self?.reconcileDevices()
        }
        reconcileDevices()
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        deviceListObservation?.invalidate()
        deviceListObservation = nil
        runningObservations.values.forEach { $0.invalidate() }
        runningObservations.removeAll()
        monitoredDeviceIDs.removeAll()
        setActive(false)
    }

    func refreshActivity() {
        guard isStarted else { return }
        reconcileDevices()
    }

    private func reconcileDevices() {
        guard isStarted else { return }

        let deviceIDs = source.inputDeviceIDs()
        let removedDeviceIDs = monitoredDeviceIDs.subtracting(deviceIDs)
        let addedDeviceIDs = deviceIDs.subtracting(monitoredDeviceIDs)

        removedDeviceIDs.forEach { deviceID in
            runningObservations.removeValue(forKey: deviceID)?.invalidate()
        }
        monitoredDeviceIDs = deviceIDs

        addedDeviceIDs.forEach { deviceID in
            guard let observation = source.observeRunningState(of: deviceID, handler: { [weak self] in
                self?.refreshRunningState()
            }) else { return }
            runningObservations[deviceID] = observation
        }

        refreshRunningState()
    }

    private func refreshRunningState() {
        guard isStarted else { return }
        setActive(source.isInputActive(on: monitoredDeviceIDs))
    }

    private func setActive(_ active: Bool) {
        guard isActive != active else { return }
        isActive = active
        onActivityChanged?(active)
    }
}

final class CoreAudioInputDeviceSource: InputDeviceActivitySource {

    private let systemObjectID = AudioObjectID(kAudioObjectSystemObject)

    func inputDeviceIDs() -> Set<AudioDeviceID> {
        guard let deviceIDs = objectIDs(for: systemObjectID, address: Self.deviceListAddress) else {
            return []
        }
        return Set(deviceIDs.filter { $0 != kAudioObjectUnknown && isInputCapable($0) })
    }

    func isInputActive(on deviceIDs: Set<AudioDeviceID>) -> Bool {
        let activeProcessInputDeviceIDs: Set<AudioDeviceID>?
        if #available(macOS 14.2, *) {
            activeProcessInputDeviceIDs = activeInputDeviceIDsFromProcesses()
        } else {
            activeProcessInputDeviceIDs = nil
        }

        let runningDeviceIDs = activeProcessInputDeviceIDs == nil
            ? Set(deviceIDs.filter(isDeviceRunningSomewhere))
            : []
        return InputActivityResolver.isActive(
            monitoredDeviceIDs: deviceIDs,
            activeProcessInputDeviceIDs: activeProcessInputDeviceIDs,
            runningDeviceIDs: runningDeviceIDs
        )
    }

    private func isDeviceRunningSomewhere(_ deviceID: AudioDeviceID) -> Bool {
        var address = Self.runningAddress
        guard AudioObjectHasProperty(deviceID, &address) else { return false }

        var isRunning: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &dataSize, &isRunning
        ) == noErr && isRunning != 0
    }

    func observeDeviceList(_ handler: @escaping () -> Void) -> AudioHardwareObservation? {
        observe(systemObjectID, address: Self.deviceListAddress, handler: handler)
    }

    func observeRunningState(
        of deviceID: AudioDeviceID,
        handler: @escaping () -> Void
    ) -> AudioHardwareObservation? {
        var address = Self.runningAddress
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }
        return observe(deviceID, address: address, handler: handler)
    }

    private func isInputCapable(_ deviceID: AudioDeviceID) -> Bool {
        guard let streamIDs = objectIDs(for: deviceID, address: Self.inputStreamAddress) else {
            return false
        }
        return !streamIDs.isEmpty
    }

    @available(macOS 14.2, *)
    private func activeInputDeviceIDsFromProcesses() -> Set<AudioDeviceID>? {
        guard let processIDs = objectIDs(for: systemObjectID, address: Self.processListAddress) else {
            return nil
        }

        var inputDeviceIDs: Set<AudioDeviceID> = []
        for processID in processIDs {
            guard let isRunningInput = uint32Value(
                for: processID,
                address: Self.processRunningInputAddress
            ) else { return nil }
            guard isRunningInput != 0 else { continue }

            guard let processDeviceIDs = objectIDs(
                for: processID,
                address: Self.processInputDevicesAddress
            ) else { return nil }
            inputDeviceIDs.formUnion(processDeviceIDs)
        }
        return inputDeviceIDs
    }

    private func objectIDs(
        for objectID: AudioObjectID,
        address propertyAddress: AudioObjectPropertyAddress
    ) -> [AudioObjectID]? {
        var address = propertyAddress
        guard AudioObjectHasProperty(objectID, &address) else { return nil }
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &dataSize) == noErr,
              dataSize % UInt32(MemoryLayout<AudioObjectID>.size) == 0 else {
            return nil
        }
        guard dataSize > 0 else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var objectIDs = [AudioObjectID](repeating: kAudioObjectUnknown, count: count)
        var outputDataSize = dataSize
        guard AudioObjectGetPropertyData(
            objectID, &address, 0, nil, &outputDataSize, &objectIDs
        ) == noErr,
        outputDataSize % UInt32(MemoryLayout<AudioObjectID>.size) == 0 else {
            return nil
        }
        return Array(objectIDs.prefix(Int(outputDataSize) / MemoryLayout<AudioObjectID>.size))
    }

    private func uint32Value(
        for objectID: AudioObjectID,
        address propertyAddress: AudioObjectPropertyAddress
    ) -> UInt32? {
        var address = propertyAddress
        guard AudioObjectHasProperty(objectID, &address) else { return nil }

        var value: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(
            objectID, &address, 0, nil, &dataSize, &value
        ) == noErr else { return nil }
        return value
    }

    private func observe(
        _ objectID: AudioObjectID,
        address propertyAddress: AudioObjectPropertyAddress,
        handler: @escaping () -> Void
    ) -> AudioHardwareObservation? {
        var address = propertyAddress
        let listener: AudioObjectPropertyListenerBlock = { _, _ in handler() }
        guard AudioObjectAddPropertyListenerBlock(objectID, &address, DispatchQueue.main, listener) == noErr else {
            return nil
        }

        return CoreAudioObservation {
            var address = propertyAddress
            AudioObjectRemovePropertyListenerBlock(objectID, &address, DispatchQueue.main, listener)
        }
    }

    private static let deviceListAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private static let inputStreamAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreams,
        mScope: kAudioObjectPropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain
    )

    private static let runningAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    @available(macOS 14.2, *)
    private static let processListAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyProcessObjectList,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    @available(macOS 14.2, *)
    private static let processRunningInputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioProcessPropertyIsRunningInput,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    @available(macOS 14.2, *)
    private static let processInputDevicesAddress = AudioObjectPropertyAddress(
        mSelector: kAudioProcessPropertyDevices,
        mScope: kAudioObjectPropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain
    )
}

private final class CoreAudioObservation: AudioHardwareObservation {

    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func invalidate() {
        cancellation?()
        cancellation = nil
    }

    deinit {
        invalidate()
    }
}
